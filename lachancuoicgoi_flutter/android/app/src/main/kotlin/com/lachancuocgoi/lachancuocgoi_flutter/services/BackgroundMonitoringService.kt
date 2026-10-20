package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.lachancuocgoi.lachancuocgoi_flutter.diagnostics.MonitoringPerfProbe
import com.lachancuocgoi.lachancuocgoi_flutter.helpers.MonitoringNotificationBuilder
import com.lachancuocgoi.lachancuocgoi_flutter.helpers.WatchdogScheduler
import com.lachancuocgoi.lachancuocgoi_flutter.R
import com.lachancuocgoi.lachancuocgoi_flutter.receiver.ServiceWatchdogReceiver
import com.lachancuocgoi.lachancuocgoi_flutter.ui.OverlayManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class BackgroundMonitoringService : Service() {

    private val serviceJob = Job()
    private val serviceScope = CoroutineScope(Dispatchers.IO + serviceJob)
    private val finalizationScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val lifecycleState = MonitoringLifecycleState()
    private lateinit var speechToTextManager: SpeechToTextManager
    private lateinit var audioManager: AudioManager
    private lateinit var connectivityMonitor: ConnectivityMonitor

    private lateinit var notificationBuilder: MonitoringNotificationBuilder

    private val watchdogScheduler by lazy { WatchdogScheduler(this) }

    private var currentTranscript = ""
    private var startTime: Long = 0
    private var monitoringJob: Job? = null
    private var connectivityJob: Job? = null
    private var transcriptCollectorJob: Job? = null

    private val transcriptLock = Any()

    private var wakeLock: PowerManager.WakeLock? = null

    @Volatile private var isMonitoringActive = false
    @Volatile private var isStopping = false

    @Volatile private var lastSttUpdateMs: Long = 0L
    @Volatile private var lastPartialUpdateMs: Long = 0L
    @Volatile private var lastAccUpdateMs: Long = 0L

    private var audioFocusRequest: AudioFocusRequest? = null
    private var hadAudioFocus = false

    private var wasSpeakerphoneOn = false
    private var shouldEnableSpeakerphone = false
    private var speakerphoneChangedByService = false

    private var transientFocusLoss = false

    private var wasListeningBeforeTransientLoss = false

    private val focusHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var focusResumeRunnable: Runnable? = null
    private var lastFocusResumeTimeMs = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        val onCreateToken = MonitoringPerfProbe.begin("monitoring_service_on_create")
        super.onCreate()
        val speechManagerToken = MonitoringPerfProbe.begin("speech_manager_constructor")
        speechToTextManager = try {
            SpeechToTextManager(application)
        } finally {
            MonitoringPerfProbe.end(speechManagerToken)
        }
        connectivityMonitor = ConnectivityMonitor(application)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        notificationBuilder = MonitoringNotificationBuilder(this, BackgroundMonitoringService::class.java)
        lifecycleState.onServiceCreated()

        speechToTextManager.onEngineSwitched = { isVosk ->
            if (isVosk) {
                if (!hadAudioFocus) {
                    hadAudioFocus = requestAudioFocus()
                    Log.d(TAG, "Audio focus requested for Vosk fallback: $hadAudioFocus")
                }
            } else {
                if (hadAudioFocus) {
                    releaseAudioFocus()
                    hadAudioFocus = false
                    transientFocusLoss = false
                    wasListeningBeforeTransientLoss = false
                    Log.d(TAG, "Audio focus released because Google STT is restored")
                }
            }
        }

        serviceScope.launch {
            MonitoringPerfProbe.mark("vosk_preload_dispatch_started")
            try {
                speechToTextManager.preloadVoskFallback()
            } catch (e: Exception) {
                Log.w(TAG, "Vosk preload failed (non-fatal)", e)
                MonitoringPerfProbe.mark(
                    "vosk_preload_dispatch_failed",
                    "error=${e.javaClass.simpleName}",
                )
            }
        }
        MonitoringPerfProbe.end(onCreateToken)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        MonitoringPerfProbe.mark(
            "monitoring_service_on_start",
            "action=${intent?.action.orEmpty()}",
        )
        if (intent?.action == ACTION_STOP) {
            if (isMonitoringActive || isStopping) {
                stopMonitoring()
            } else {
                stopSelf(startId)
            }
            return START_NOT_STICKY
        }
        if (intent?.action != ACTION_START) {
            Log.w(TAG, "Stopping service after an empty or unsupported start intent")
            isRunning = false
            stopSelf(startId)
            return START_NOT_STICKY
        }

        shouldEnableSpeakerphone = intent?.getBooleanExtra("ENABLE_SPEAKERPHONE", false) ?: false

        if (!shouldEnableSpeakerphone) {
            shouldEnableSpeakerphone =
                MonitoringPreferences.readAutoEnableSpeakerphone(applicationContext)
        }

        val foregroundType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        } else {
            0
        }
        val promotionToken = MonitoringPerfProbe.begin("monitoring_service_promote_foreground")
        val promoted = try {
            ForegroundServiceLauncher.safeStartForeground(
                this,
                NOTIFICATION_ID,
                createMonitoringNotification("Đang sẵn sàng bảo vệ..."),
                foregroundType,
            )
        } catch (e: Exception) {
            Log.e(TAG, "Unable to build or post the foreground notification", e)
            false
        } finally {
            MonitoringPerfProbe.end(promotionToken)
        }
        if (!promoted) {
            failForegroundPromotion(startId)
            return START_NOT_STICKY
        }
        lifecycleState.onForegroundPromoted()

        if (isMonitoringActive || isStopping) {
            Log.i(TAG, "Ignoring duplicate start request while monitoring is active.")
            MonitoringStartCoordinator.complete(
                MonitoringStartResponse(
                    MonitoringStartStatus.ALREADY_RUNNING,
                    "Dịch vụ giám sát đang hoạt động.",
                )
            )
            return START_STICKY
        }

        persistLastStartParams(shouldEnableSpeakerphone)
        persistMonitoringActive(true)
        scheduleWatchdogAlarm()
        startMonitoring()
        return START_STICKY
    }

    private fun failForegroundPromotion(startId: Int) {
        Log.e(TAG, "Foreground promotion failed; stopping monitoring service")
        isMonitoringActive = false
        isRunning = false
        persistMonitoringActive(false)
        NativeBridgeEventSink.sendLog(
            TAG,
            "Không thể chạy dịch vụ giám sát ở chế độ foreground.",
            "ERROR",
        )
        NativeBridgeEventSink.sendMonitoringState("START_FAILED:nativeFailure")
        MonitoringStartCoordinator.complete(
            MonitoringStartResponse(
                MonitoringStartStatus.NATIVE_FAILURE,
                "Không thể chạy dịch vụ giám sát ở chế độ foreground.",
            )
        )

        CallSessionCoordinator.onMonitoringServiceStopped(applicationContext)
        stopSelf(startId)
    }

    @Suppress("DEPRECATION")
    private fun startMonitoring() {
        lifecycleState.onMonitoringStarted()

        val startToken = MonitoringPerfProbe.begin("monitoring_service_start_monitoring")
        Log.d(TAG, "Starting dual-source monitoring.")
        NativeBridgeEventSink.sendLog(TAG, "Khởi chạy dịch vụ bảo vệ cuộc gọi ngầm (Google STT + Vosk)...", "INFO")
        isMonitoringActive = true
        isRunning = true
        MonitoringPerfProbe.mark("monitoring_service_running")
        isStopping = false
        startTime = System.currentTimeMillis()
        if (CallSessionCoordinator.isMonitoringAccepted(applicationContext)) {
            OverlayManager.showMonitoringOverlay(applicationContext, startTime)
        }
        monitoringJob?.cancel()
        connectivityJob?.cancel()
        transcriptCollectorJob?.cancel()
        acquireWakeLock()
        synchronized(transcriptLock) {
            currentTranscript = ""
        }
        TranscriptionHub.reset()
        speechToTextManager.clearTranscript()

        MonitoringStartCoordinator.complete(
            MonitoringStartResponse(
                MonitoringStartStatus.STARTED,
                "Dịch vụ giám sát đã khởi động.",
            )
        )
        NativeBridgeEventSink.sendMonitoringState("STARTED")

        connectivityMonitor.start()
        connectivityJob = serviceScope.launch {
            connectivityMonitor.isNetworkAvailable.collectLatest { isAvailable ->
                NativeBridgeEventSink.sendMonitoringState(
                    if (isAvailable) "NETWORK_AVAILABLE" else "NETWORK_LOST"
                )
                if (isAvailable) {
                    speechToTextManager.onNetworkRestored()
                }
            }
        }

        val recognitionAvailableToken =
            MonitoringPerfProbe.begin("speech_recognition_available_check")
        val googleAvailable = try {
            android.speech.SpeechRecognizer.isRecognitionAvailable(application)
        } finally {
            MonitoringPerfProbe.end(recognitionAvailableToken)
        }
        MonitoringPerfProbe.mark(
            "speech_recognition_availability",
            "google_available=$googleAvailable",
        )

        if (!googleAvailable) {
            hadAudioFocus = requestAudioFocus()
            if (hadAudioFocus) {
                Log.d(TAG, "Audio focus granted for Vosk primary")
            } else {
                Log.w(TAG, "Could not obtain audio focus for Vosk primary")
            }
        } else {
            hadAudioFocus = false
        }
        MonitoringPerfProbe.end(
            startToken,
            "google_available=$googleAvailable,audio_focus=$hadAudioFocus",
        )

        wasSpeakerphoneOn = audioManager.isSpeakerphoneOn
        speakerphoneChangedByService = false

        monitoringJob = serviceScope.launch {

            delay(100)

            if (shouldEnableSpeakerphone) {
                enableSpeakerphone()
                Log.d(TAG, "Speakerphone enabled for monitoring")
                NativeBridgeEventSink.sendLog(
                    TAG,
                    "Bật loa ngoài để giám sát cuộc gọi.",
                    "INFO",
                )
            }

            launch {
                while (isActive) {
                    if (shouldEnableSpeakerphone && !audioManager.isSpeakerphoneOn) {
                        Log.w(TAG, "Speakerphone was disabled! Re-enabling...")
                        NativeBridgeEventSink.sendLog(
                            TAG,
                            "Phát hiện loa ngoài bị tắt. Tiến hành tự động kích hoạt lại...",
                            "WARN",
                        )
                        enableSpeakerphone()
                    }
                    delay(SPEAKERPHONE_ENFORCEMENT_INTERVAL_MS)
                }
            }

            if (!googleAvailable) {
                Log.w(TAG, "Google STT not available on this device — starting Vosk directly")
                val voskStarted = speechToTextManager.startVoskPrimaryIfReady()
                if (!voskStarted) {
                    Log.e(
                        TAG,
                        "Neither Google nor Vosk STT is ready — transcript will be empty"
                    )

                    NativeBridgeEventSink.sendMonitoringState("STT_UNAVAILABLE:no_engine")
                    NativeBridgeEventSink.sendLog(
                        TAG,
                        "Mic/STT không sẵn sàng — transcript trống.",
                        "ERROR",
                    )
                }
            } else {
                try {
                    MonitoringPerfProbe.mark("speech_start_dispatch")
                    speechToTextManager.startListening()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start listening", e)
                }
            }

            updateNotification("Đang giám sát cuộc gọi (Mic + Phụ đề)...")

            speechToTextManager.rmsDbFlow
                .onEach { rms ->
                    NativeBridgeEventSink.sendRms(rms)
                    OverlayManager.updateMonitoringRms(rms)
                }
                .launchIn(this)

            transcriptCollectorJob = launch {

                combine(
                    speechToTextManager.fullTranscriptFlow,
                    speechToTextManager.textResults,
                    TranscriptionHub.transcriptFlow,
                ) { stt, partial, acc ->
                    val now = System.currentTimeMillis()

                    if (stt.isNotBlank()) lastSttUpdateMs = now
                    if (partial.isNotBlank()) lastPartialUpdateMs = now
                    if (acc.isNotBlank()) lastAccUpdateMs = now

                    val sttFresh = (now - lastSttUpdateMs) < MAX_PARTIAL_AGE_MS
                    val partialFresh = (now - lastPartialUpdateMs) < MAX_PARTIAL_AGE_MS
                    val accFresh = (now - lastAccUpdateMs) < MAX_PARTIAL_AGE_MS

                    val safeStt = if (sttFresh) stt else ""
                    val safeAcc = if (accFresh) acc else ""
                    val safePartial = if (partialFresh) partial else ""

                    val cumulative = when {
                        safeStt.isNotBlank() && safeAcc.isNotBlank() ->
                            if (safeStt.length >= safeAcc.length) safeStt else safeAcc
                        safeStt.isNotBlank() -> safeStt
                        safeAcc.isNotBlank() -> safeAcc
                        else -> ""
                    }
                    val composed = if (cumulative.isNotBlank()) {
                        if (safePartial.isNotBlank()) "$cumulative\n$safePartial" else cumulative
                    } else {
                        safePartial
                    }
                    if (composed.isBlank()) {
                        null
                    } else {
                        TranscriptUpdate(text = composed, isPartial = safePartial.isNotBlank())
                    }
                }.collect { update ->
                    val u = update ?: return@collect
                    synchronized(transcriptLock) {
                        currentTranscript = u.text
                    }
                    NativeBridgeEventSink.sendTranscript(u.text, u.isPartial)
                }
            }
        }
    }

    private fun stopMonitoring() {
        if (isStopping) return

        isStopping = true
        isMonitoringActive = false
        isRunning = false
        lifecycleState.onMonitoringStopped()

        persistMonitoringActive(false)
        connectivityJob?.cancel()
        transcriptCollectorJob?.cancel()
        monitoringJob?.cancel()

        speechToTextManager.stopListening()
        connectivityMonitor.stop()

        if (speakerphoneChangedByService) {
            disableSpeakerphone()
            Log.d(TAG, "Speakerphone restored to previous state")
        }

        if (hadAudioFocus) {
            releaseAudioFocus()
            Log.d(TAG, "Audio focus released")
        }

        releaseWakeLock()

        val endTime = System.currentTimeMillis()
        val duration = (endTime - startTime) / 1000

        val finalTranscript = synchronized(transcriptLock) { currentTranscript.trim() }

        NativeBridgeEventSink.sendMonitoringState("STOPPED:$duration:$finalTranscript")
        CallSessionCoordinator.onMonitoringServiceStopped(applicationContext)

        finalizationScope.launch {
            try {

                Log.d(TAG, "Monitoring stopped. Duration: ${duration}s, transcript length: ${finalTranscript.length}")
            } finally {
                stopSelf()
            }
        }
    }

    private fun createMonitoringNotification(text: String): android.app.Notification {

        notificationBuilder.ensureChannel(CHANNEL_ID, "Giám sát cuộc gọi")
        return notificationBuilder.build(CHANNEL_ID, ACTION_STOP, text)
    }

    private fun updateNotification(text: String) {
        notificationBuilder.update(CHANNEL_ID, ACTION_STOP, NOTIFICATION_ID, text)
    }

    override fun onDestroy() {
        super.onDestroy()
        lifecycleState.onDestroyed()
        speechToTextManager.releaseVoskModel()
        isMonitoringActive = false
        isRunning = false

        focusResumeRunnable?.let { focusHandler.removeCallbacks(it) }
        focusResumeRunnable = null
        connectivityMonitor.stop()
        serviceJob.cancel()
        finalizationScope.cancel()
        speechToTextManager.destroy()
        if (hadAudioFocus) {
            releaseAudioFocus()
        }
        if (speakerphoneChangedByService) {
            disableSpeakerphone()
        }
        releaseWakeLock()

        if (!isStopping) {
            cancelWatchdogAlarm()
        }

    }

    @Suppress("DEPRECATION")
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level >= TRIM_MEMORY_RUNNING_CRITICAL) {

            Log.w(TAG, "Memory critical — dropping connectivity stream to free memory.")
            connectivityJob?.cancel()
            connectivityJob = null
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "Task removed by user (swiped away).")

        if (isMonitoringActive && !isStopping) {
            updateNotification("Lá chắn vẫn đang hoạt động...")
            persistMonitoringActive(true)

            scheduleExactWatchdogAlarm()
        }
    }

    private fun scheduleExactWatchdogAlarm() =
        watchdogScheduler.scheduleExact(WATCHDOG_INTERVAL_MINUTES)

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "lachancuocgoi::monitoring_wakelock"
            ).apply {

                setReferenceCounted(false)
                acquire( 6 * 60 * 60 * 1000L)
            }
            Log.d(TAG, "PARTIAL_WAKE_LOCK acquired for monitoring session")
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot acquire wake lock", e)
        } catch (e: Exception) {
            Log.w(TAG, "Unexpected error acquiring wake lock", e)
        }
    }

    private fun releaseWakeLock() {
        val lock = wakeLock ?: return
        try {
            if (lock.isHeld) {
                lock.release()
                Log.d(TAG, "PARTIAL_WAKE_LOCK released")
            }
        } catch (e: RuntimeException) {
            Log.w(TAG, "Failed to release wake lock", e)
        }
        wakeLock = null
    }

    private fun requestAudioFocus(): Boolean {
        return try {

            val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ASSISTANT)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )

                    .setWillPauseWhenDucked(true)
                    .setAcceptsDelayedFocusGain(true)
                    .setOnAudioFocusChangeListener { focusChange ->
                        Log.d(TAG, "Audio focus changed: $focusChange")
                        when (focusChange) {
                            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
                            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {

                                focusResumeRunnable?.let { focusHandler.removeCallbacks(it) }
                                focusResumeRunnable = null

                                if (!transientFocusLoss && !speechToTextManager.isReady) {

                                    Log.w(TAG, "Transient focus loss — pausing STT")
                                    transientFocusLoss = true
                                    wasListeningBeforeTransientLoss =
                                        speechToTextManager.shouldBeListeningSnapshot
                                    speechToTextManager.pauseListening()
                                }
                            }
                            AudioManager.AUDIOFOCUS_GAIN -> {
                                if (transientFocusLoss) {

                                    focusResumeRunnable?.let { focusHandler.removeCallbacks(it) }
                                    val now = System.currentTimeMillis()
                                    if (now - lastFocusResumeTimeMs < FOCUS_RESUME_COOLDOWN_MS) {
                                        Log.d(TAG, "Focus gain too soon after last resume — skipping")
                                        return@setOnAudioFocusChangeListener
                                    }
                                    val runnable = Runnable {
                                        if (transientFocusLoss && wasListeningBeforeTransientLoss) {
                                            Log.i(TAG, "Audio focus regained — resuming STT (debounced)")
                                            transientFocusLoss = false
                                            lastFocusResumeTimeMs = System.currentTimeMillis()
                                            speechToTextManager.resumeListening()
                                        }
                                        wasListeningBeforeTransientLoss = false
                                    }
                                    focusResumeRunnable = runnable
                                    focusHandler.postDelayed(runnable, FOCUS_RESUME_DELAY_MS)
                                }
                            }
                            AudioManager.AUDIOFOCUS_LOSS -> {

                                focusResumeRunnable?.let { focusHandler.removeCallbacks(it) }
                                focusResumeRunnable = null

                                Log.w(TAG, "Permanent focus loss — stopping STT gracefully")
                                hadAudioFocus = false
                                transientFocusLoss = false
                                wasListeningBeforeTransientLoss = false
                                speechToTextManager.stopListening()

                                releaseAudioFocus()
                            }
                        }
                    }
                .build()
            audioFocusRequest = focusRequest
            val requestToken = MonitoringPerfProbe.begin("audio_focus_request_ipc")
            val granted = try {
                audioManager.requestAudioFocus(focusRequest) ==
                    AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            } finally {
                MonitoringPerfProbe.end(requestToken)
            }
            MonitoringPerfProbe.mark("audio_focus_result", "granted=$granted")
            granted
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting audio focus", e)
            MonitoringPerfProbe.mark(
                "audio_focus_failed",
                "error=${e.javaClass.simpleName}",
            )
            false
        }
    }

    private fun releaseAudioFocus() {
        try {
            audioFocusRequest?.let {
                audioManager.abandonAudioFocusRequest(it)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing audio focus", e)
        }
    }

    @Suppress("DEPRECATION")
    private fun enableSpeakerphone() {
        try {
            if (!audioManager.isSpeakerphoneOn) {
                audioManager.isSpeakerphoneOn = true
                speakerphoneChangedByService = true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling speakerphone", e)
        }
    }

    @Suppress("DEPRECATION")
    private fun disableSpeakerphone() {
        try {
            if (speakerphoneChangedByService) {
                audioManager.isSpeakerphoneOn = wasSpeakerphoneOn
                speakerphoneChangedByService = false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling speakerphone", e)
        }
    }

    private fun getWatchdogPrefs(): SharedPreferences =
        getSharedPreferences(WATCHDOG_PREFS, Context.MODE_PRIVATE)

    private fun persistMonitoringActive(active: Boolean) {
        val editor = getWatchdogPrefs().edit().putBoolean(KEY_MONITORING_WAS_ACTIVE, active)
        if (!active) {

            editor.remove(KEY_WATCHDOG_PHONE_NUMBER)
                .remove(KEY_WATCHDOG_SPEAKERPHONE)
            cancelWatchdogAlarm()
        }
        editor.apply()
    }

    private fun persistLastStartParams(enableSpeakerphone: Boolean) {
        val editor = getWatchdogPrefs().edit()
        editor.remove(KEY_WATCHDOG_PHONE_NUMBER)
        editor.putBoolean(KEY_WATCHDOG_SPEAKERPHONE, enableSpeakerphone)
        editor.apply()
    }

    private fun scheduleWatchdogAlarm() =
        watchdogScheduler.scheduleInexact(WATCHDOG_INTERVAL_MINUTES)

    private fun cancelWatchdogAlarm() = watchdogScheduler.cancel()

    companion object {
        private const val TAG = "BackgroundMonitoringSvc"
        private const val NOTIFICATION_ID = 2
        private const val CHANNEL_ID = "BackgroundMonitoringChannel"

        private const val FOCUS_RESUME_COOLDOWN_MS = 500L

        private const val FOCUS_RESUME_DELAY_MS = 600L

        private const val SPEAKERPHONE_ENFORCEMENT_INTERVAL_MS = 5000L

        private const val MAX_PARTIAL_AGE_MS = 10_000L

        private data class TranscriptUpdate(val text: String, val isPartial: Boolean)

        const val ACTION_START = "com.lachancuocgoi.ACTION_START_BACKGROUND_MONITORING"
        const val ACTION_STOP = "com.lachancuocgoi.ACTION_STOP_BACKGROUND_MONITORING"

        const val WATCHDOG_PREFS = "monitoring_watchdog"
        private const val KEY_MONITORING_WAS_ACTIVE = "monitoring_was_active"
        private const val KEY_WATCHDOG_PHONE_NUMBER = "watchdog_phone_number"
        private const val KEY_WATCHDOG_SPEAKERPHONE = "watchdog_speakerphone"
        const val WATCHDOG_INTERVAL_MINUTES = 5

        @Volatile
        var isRunning = false

        fun wasMonitoringActive(context: Context): Boolean {
            val prefs = context.getSharedPreferences(WATCHDOG_PREFS, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_MONITORING_WAS_ACTIVE, false)
        }

        fun lastStartParams(context: Context): Pair<String?, Boolean> {
            val prefs = context.getSharedPreferences(WATCHDOG_PREFS, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_WATCHDOG_PHONE_NUMBER).apply()
            val speaker = prefs.getBoolean(KEY_WATCHDOG_SPEAKERPHONE, false)
            return null to speaker
        }

        fun clearMonitoringActiveFlag(context: Context) {
            context.getSharedPreferences(WATCHDOG_PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_MONITORING_WAS_ACTIVE, false)
                .remove(KEY_WATCHDOG_PHONE_NUMBER)
                .remove(KEY_WATCHDOG_SPEAKERPHONE)
                .apply()
        }
    }
}

