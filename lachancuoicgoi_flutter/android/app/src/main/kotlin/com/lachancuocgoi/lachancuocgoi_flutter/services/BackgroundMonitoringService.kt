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
import android.util.Log
import androidx.core.app.NotificationCompat
import com.lachancuocgoi.lachancuocgoi_flutter.R
import com.lachancuocgoi.lachancuocgoi_flutter.receiver.ServiceWatchdogReceiver
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

/**
 * Foreground service cho giám sát cuộc gọi.
 * Trong Flutter architecture, service này chịu trách nhiệm:
 * - Foreground notification
 * - Audio focus / speakerphone management
 * - STT management (Google + Vosk fallback)
 * - Stream transcript/RMS qua NativeBridgeEventSink
 * - Nhận lệnh show alert từ Flutter (qua MethodChannel)
 *
 * Analysis logic được xử lý ở Dart side (Phase 9 MonitoringController).
 */
class BackgroundMonitoringService : Service() {

    private val serviceJob = Job()
    private val serviceScope = CoroutineScope(Dispatchers.IO + serviceJob)
    private val finalizationScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private lateinit var speechToTextManager: SpeechToTextManager
    private lateinit var audioManager: AudioManager
    private lateinit var connectivityMonitor: ConnectivityMonitor

    private var currentTranscript = ""
    private var startTime: Long = 0
    private var monitoringJob: Job? = null
    private var connectivityJob: Job? = null
    private var transcriptCollectorJob: Job? = null
    private var phoneNumber: String? = null

    @Volatile private var isMonitoringActive = false
    @Volatile private var isStopping = false

    // Audio focus management
    private var audioFocusRequest: AudioFocusRequest? = null
    private var hadAudioFocus = false

    // Speakerphone state
    private var wasSpeakerphoneOn = false
    private var shouldEnableSpeakerphone = false
    private var speakerphoneChangedByService = false

    // Sprint 2 (B3): set by the focus listener on TRANSIENT loss so we
    // know to re-start STT on AUDIOFOCUS_GAIN. Avoids focus flapping
    // (focus granted → lost → granted → lost) which would otherwise
    // thrash SpeechToTextManager.
    private var transientFocusLoss = false
    // Cached value of [SpeechToTextManager.shouldBeListening] at the moment
    // we got the transient loss. We only re-start STT on gain if the
    // service was actually listening before the loss.
    private var wasListeningBeforeTransientLoss = false

    // Debounce: handler + runnable for delayed resume after focus gain
    private val focusHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var focusResumeRunnable: Runnable? = null
    private var lastFocusResumeTimeMs = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        speechToTextManager = SpeechToTextManager(application)
        connectivityMonitor = ConnectivityMonitor(application)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
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

        // Warm up the offline model in a background thread to avoid blocking
        // the main thread during startup. Vosk preload involves StorageService.unpack
        // which reads model files from assets — heavy I/O that causes frame drops.
        serviceScope.launch {
            try {
                speechToTextManager.preloadVoskFallback()
            } catch (e: Exception) {
                Log.w(TAG, "Vosk preload failed (non-fatal)", e)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        phoneNumber = intent?.getStringExtra("PHONE_NUMBER")
        shouldEnableSpeakerphone = intent?.getBooleanExtra("ENABLE_SPEAKERPHONE", false) ?: false

        if (!shouldEnableSpeakerphone) {
            val sharedPreferences = getSharedPreferences("settings", Context.MODE_PRIVATE)
            shouldEnableSpeakerphone = sharedPreferences.getBoolean("AUTO_ENABLE_SPEAKERPHONE", false)
        }

        when (intent?.action) {
            ACTION_START -> {
                // ALWAYS call startForeground immediately to satisfy Android requirements when launched via startForegroundService
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID,
                        createMonitoringNotification("Đang sẵn sàng bảo vệ..."),
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                    )
                } else {
                    startForeground(NOTIFICATION_ID, createMonitoringNotification("Đang sẵn sàng bảo vệ..."))
                }

                if (isMonitoringActive || isStopping) {
                    Log.i(TAG, "Ignoring duplicate start request while monitoring is active.")
                    return START_STICKY
                }
                // Sprint 2 (B6): persist the parameters BEFORE starting so
                // the watchdog can re-attach them when it restarts the
                // service after a kill.
                persistLastStartParams(phoneNumber, shouldEnableSpeakerphone)
                persistMonitoringActive(true)
                scheduleWatchdogAlarm()
                startMonitoring()
            }
            ACTION_STOP -> {
                if (isMonitoringActive || isStopping) {
                    stopMonitoring()
                } else {
                    stopSelf()
                }
            }
        }
        return START_STICKY
    }

    @Suppress("DEPRECATION")
    private fun startMonitoring() {
        Log.d(TAG, "Starting dual-source monitoring.")
        isMonitoringActive = true
        isRunning = true
        isStopping = false
        startTime = System.currentTimeMillis()
        monitoringJob?.cancel()
        connectivityJob?.cancel()
        transcriptCollectorJob?.cancel()
        synchronized(this) {
            currentTranscript = ""
        }
        TranscriptionHub.reset()

        // Notify Flutter that monitoring started
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

        val googleAvailable =
            android.speech.SpeechRecognizer.isRecognitionAvailable(application)

        // Request audio focus only if starting with Vosk directly
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

        wasSpeakerphoneOn = audioManager.isSpeakerphoneOn
        speakerphoneChangedByService = false
        if (shouldEnableSpeakerphone) {
            enableSpeakerphone()
            Log.d(TAG, "Speakerphone enabled for monitoring")
        }

        monitoringJob = serviceScope.launch {
            // Reduced from 1000ms to 100ms — just enough for service to stabilize
            // without losing the first second of the call.
            delay(100)

            if (shouldEnableSpeakerphone) {
                enableSpeakerphone()
            }

            // Speakerphone enforcement loop
            launch {
                while (isActive) {
                    if (shouldEnableSpeakerphone && !audioManager.isSpeakerphoneOn) {
                        Log.w(TAG, "Speakerphone was disabled! Re-enabling...")
                        enableSpeakerphone()
                    }
                    delay(2000)
                }
            }

            // Start listening — pick engine based on device availability.
            // If Google STT isn't available (e.g. on a de-Googled device, or
            // on a build without the Google SpeechService package), go straight
            // to Vosk. Otherwise the existing consecutive-network-error fallback
            // (see SpeechToTextManager.switchToVoskFallback) will kick in later
            // if Google dies mid-call.
            if (!googleAvailable) {
                Log.w(TAG, "Google STT not available on this device — starting Vosk directly")
                val voskStarted = speechToTextManager.startVoskPrimaryIfReady()
                if (!voskStarted) {
                    Log.e(
                        TAG,
                        "Neither Google nor Vosk STT is ready — transcript will be empty"
                    )
                }
            } else {
                try {
                    speechToTextManager.startListening()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start listening", e)
                }
            }

            updateNotification("Đang giám sát cuộc gọi (Mic + Phụ đề)...")

            // Observe RMS for waveform → stream to Flutter
            speechToTextManager.rmsDbFlow
                .onEach { rms ->
                    NativeBridgeEventSink.sendRms(rms)
                }
                .launchIn(this)

            // Collect transcript from STT + TranscriptionHub.
            // Bug fix: deduplicate overlapping content from the two sources.
            // Use the longer/newer transcript instead of concatenating both.
            //
            // Sprint 1 change: we now also fold in `textResults` (the latest
            // partial / current-utterance result) so Flutter sees a transcript
            // update on every onPartialResults, not only on onResults. The
            // displayed text is "<cumulative>\n<partial>" when a partial is
            // present, otherwise just the cumulative. The isPartial flag tells
            // the UI that the result may still change.
            transcriptCollectorJob = launch {
                combine(
                    speechToTextManager.fullTranscriptFlow,
                    speechToTextManager.textResults,
                    TranscriptionHub.transcriptFlow
                ) { stt, partial, acc ->
                    // Build the cumulative string from STT (Google) or
                    // TranscriptionHub (accessibility) — whichever is longer.
                    val cumulative = when {
                        stt.isNotBlank() && acc.isNotBlank() -> {
                            if (stt.length >= acc.length) stt else acc
                        }
                        stt.isNotBlank() -> stt
                        acc.isNotBlank() -> acc
                        else -> ""
                    }
                    // Compose final display: cumulative + (partial on a new line).
                    // If both are blank we return null and skip the emit.
                    val composed = if (partial.isNotBlank() && cumulative.isNotBlank()) {
                        "$cumulative\n$partial"
                    } else {
                        cumulative
                    }
                    if (composed.isBlank()) {
                        null
                    } else {
                        TranscriptUpdate(text = composed, isPartial = partial.isNotBlank())
                    }
                }.collect { update ->
                    val u = update ?: return@collect
                    synchronized(this@BackgroundMonitoringService) {
                        currentTranscript = u.text
                    }
                    // Stream transcript to Flutter with partial flag
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
        // Clear the persisted flag FIRST so watchdog doesn't auto-restart
        persistMonitoringActive(false)
        connectivityJob?.cancel()
        transcriptCollectorJob?.cancel()
        monitoringJob?.cancel()

        speechToTextManager.stopListening()
        connectivityMonitor.stop()

        // Restore speakerphone state
        if (speakerphoneChangedByService) {
            disableSpeakerphone()
            Log.d(TAG, "Speakerphone restored to previous state")
        }

        // Release audio focus
        if (hadAudioFocus) {
            releaseAudioFocus()
            Log.d(TAG, "Audio focus released")
        }

        val endTime = System.currentTimeMillis()
        val duration = (endTime - startTime) / 1000

        val finalTranscript = synchronized(this) { currentTranscript.trim() }

        // Notify Flutter that monitoring stopped with final data
        NativeBridgeEventSink.sendMonitoringState("STOPPED:$duration:$finalTranscript")

        finalizationScope.launch {
            try {
                // Cleanup handled by Flutter side (save history via Dart)
                Log.d(TAG, "Monitoring stopped. Duration: ${duration}s, transcript length: ${finalTranscript.length}")
            } finally {
                stopSelf()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Giám sát cuộc gọi",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createMonitoringNotification(text: String): android.app.Notification {
        createNotificationChannel()
        val stopIntent = Intent(this, BackgroundMonitoringService::class.java).apply { action = ACTION_STOP }
        val stopPendingIntent = PendingIntent.getService(this, 0, stopIntent, PendingIntent.FLAG_IMMUTABLE)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Lá chắn cuộc gọi")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .addAction(0, "Dừng", stopPendingIntent)
            .build()
    }

    private fun updateNotification(text: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, createMonitoringNotification(text))
    }

    override fun onDestroy() {
        super.onDestroy()
        isMonitoringActive = false
        isRunning = false
        // Cancel any pending focus-resume callback
        focusResumeRunnable?.let { focusHandler.removeCallbacks(it) }
        focusResumeRunnable = null
        connectivityMonitor.stop()
        serviceJob.cancel()
        finalizationScope.cancel() // Fix: cancel finalizationScope to prevent leak
        speechToTextManager.destroy()
        if (hadAudioFocus) {
            releaseAudioFocus()
        }
        if (speakerphoneChangedByService) {
            disableSpeakerphone()
        }
        // If we're being destroyed but not intentionally stopped, the watchdog
        // will detect the stale persisted flag and restart us.
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level >= TRIM_MEMORY_RUNNING_CRITICAL) {
            // Sprint 2 (B4): only drop the connectivity stream when
            // memory is critical. Connectivity state can be re-fetched
            // when the user comes back; the transcript stream must stay
            // alive so the user doesn't lose the in-call transcript.
            Log.w(TAG, "Memory critical — dropping connectivity stream to free memory.")
            connectivityJob?.cancel()
            connectivityJob = null
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "Task removed by user (swiped away).")
        // Keep service alive: reschedule watchdog alarm and restore foreground notification.
        // On Android 12+, the service may be killed shortly after onTaskRemoved,
        // so persist state and use exact alarm for reliable restart.
        if (isMonitoringActive && !isStopping) {
            updateNotification("Lá chắn vẫn đang hoạt động...")
            persistMonitoringActive(true)
            scheduleWatchdogAlarm()
            // Also use setAlarmClock which has higher priority than setInexactRepeating
            // and is not subject to background restrictions.
            scheduleExactWatchdogAlarm()
        }
    }

    private fun scheduleExactWatchdogAlarm() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, ServiceWatchdogReceiver::class.java).apply {
            action = ServiceWatchdogReceiver.ACTION_CHECK_SERVICE
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this, 1, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val triggerAt = System.currentTimeMillis() + WATCHDOG_INTERVAL_MINUTES * 60 * 1000L
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                // Fall back to inexact if exact alarms not permitted
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent
                )
            } else {
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(triggerAt, pendingIntent),
                    pendingIntent
                )
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot schedule exact alarm, falling back", e)
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent
            )
        }
        Log.d(TAG, "Exact watchdog alarm scheduled at +${WATCHDOG_INTERVAL_MINUTES}m.")
    }

    private fun requestAudioFocus(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Use AUDIOFOCUS_GAIN (not TRANSIENT_MAY_DUCK) to get full
                // microphone priority — prevents system from ducking our STT.
                val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ASSISTANT)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    // Sprint 2 (B3): true so we still pause on duck (call
                    // screen share / nav prompt) and don't keep STT running
                    // through duck → unduck flapping.
                    .setWillPauseWhenDucked(true)
                    .setAcceptsDelayedFocusGain(true)
                    .setOnAudioFocusChangeListener { focusChange ->
                        Log.d(TAG, "Audio focus changed: $focusChange")
                        when (focusChange) {
                            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
                            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                                // Cancel any pending resume — a new loss arrived
                                // before we could resume, so don't bother.
                                focusResumeRunnable?.let { focusHandler.removeCallbacks(it) }
                                focusResumeRunnable = null

                                // Only pause if Vosk is active. Google STT handles its own focus and triggers this event itself,
                                // which causes an infinite pausing/resuming loop.
                                if (!transientFocusLoss && !speechToTextManager.isReady) {
                                    // Only pause once; ignore repeated loss events.
                                    Log.w(TAG, "Transient focus loss — pausing STT")
                                    transientFocusLoss = true
                                    wasListeningBeforeTransientLoss =
                                        speechToTextManager.shouldBeListeningSnapshot
                                    speechToTextManager.pauseListening()
                                }
                            }
                            AudioManager.AUDIOFOCUS_GAIN -> {
                                if (transientFocusLoss) {
                                    // Debounce: wait FOCUS_RESUME_DELAY_MS before
                                    // resuming so we don't immediately trigger
                                    // another focus loss from the new recognizer.
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
                                // Cancel any pending resume
                                focusResumeRunnable?.let { focusHandler.removeCallbacks(it) }
                                focusResumeRunnable = null

                                Log.w(TAG, "Permanent focus loss — stopping STT gracefully")
                                hadAudioFocus = false
                                transientFocusLoss = false
                                wasListeningBeforeTransientLoss = false
                                speechToTextManager.stopListening()
                            }
                        }
                    }
                    .build()
                audioFocusRequest = focusRequest
                audioManager.requestAudioFocus(focusRequest) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            } else {
                @Suppress("DEPRECATION")
                audioManager.requestAudioFocus(
                    { focusChange -> Log.d(TAG, "Audio focus changed: $focusChange") },
                    AudioManager.STREAM_VOICE_CALL,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
                ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting audio focus", e)
            false
        }
    }

    private fun releaseAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let {
                    audioManager.abandonAudioFocusRequest(it)
                }
            } else {
                @Suppress("DEPRECATION")
                audioManager.abandonAudioFocus(null)
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

    // ─── SharedPreferences persistence ───────────────────────────────────

    private fun getWatchdogPrefs(): SharedPreferences =
        getSharedPreferences(WATCHDOG_PREFS, Context.MODE_PRIVATE)

    private fun persistMonitoringActive(active: Boolean) {
        getWatchdogPrefs().edit().putBoolean(KEY_MONITORING_WAS_ACTIVE, active).apply()
        if (!active) {
            // Sprint 2 (B6): also clear the last-known start params so
            // the watchdog does not resurrect a stale session.
            getWatchdogPrefs().edit()
                .remove(KEY_WATCHDOG_PHONE_NUMBER)
                .remove(KEY_WATCHDOG_SPEAKERPHONE)
                .apply()
            cancelWatchdogAlarm()
        }
    }

    /**
     * Sprint 2 (B6): stash the latest ACTION_START intent extras so the
     * watchdog receiver can re-attach the same phone number / speakerphone
     * flag when it auto-restarts the service after a system kill.
     */
    private fun persistLastStartParams(phoneNumber: String?, enableSpeakerphone: Boolean) {
        val editor = getWatchdogPrefs().edit()
        if (phoneNumber != null) {
            editor.putString(KEY_WATCHDOG_PHONE_NUMBER, phoneNumber)
        } else {
            editor.remove(KEY_WATCHDOG_PHONE_NUMBER)
        }
        editor.putBoolean(KEY_WATCHDOG_SPEAKERPHONE, enableSpeakerphone)
        editor.apply()
    }

    private fun scheduleWatchdogAlarm() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, ServiceWatchdogReceiver::class.java).apply {
            action = ServiceWatchdogReceiver.ACTION_CHECK_SERVICE
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        // Check every 5 minutes; use inexact to be battery-friendly
        val intervalMs = WATCHDOG_INTERVAL_MINUTES * 60 * 1000L
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + intervalMs,
                intervalMs,
                pendingIntent
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + intervalMs,
                intervalMs,
                pendingIntent
            )
        } else {
            @Suppress("DEPRECATION")
            alarmManager.setRepeating(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + intervalMs,
                intervalMs,
                pendingIntent
            )
        }
        Log.d(TAG, "Watchdog alarm scheduled every ${WATCHDOG_INTERVAL_MINUTES}m.")
    }

    private fun cancelWatchdogAlarm() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, ServiceWatchdogReceiver::class.java).apply {
            action = ServiceWatchdogReceiver.ACTION_CHECK_SERVICE
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_NO_CREATE
        )
        pendingIntent?.let {
            alarmManager.cancel(it)
            it.cancel()
        }
        Log.d(TAG, "Watchdog alarm cancelled.")
    }

    companion object {
        private const val TAG = "BackgroundMonitoringSvc"
        private const val NOTIFICATION_ID = 2
        private const val CHANNEL_ID = "BackgroundMonitoringChannel"

        /** Minimum gap between resume attempts to break the focus flapping cycle. */
        private const val FOCUS_RESUME_COOLDOWN_MS = 500L
        /** Delay before actually resuming STT after focus gain. */
        private const val FOCUS_RESUME_DELAY_MS = 600L

        /**
         * Tuple produced by the transcript-collector combine block. Emitted to
         * Flutter via [NativeBridgeEventSink.sendTranscript] (with isPartial).
         */
        private data class TranscriptUpdate(val text: String, val isPartial: Boolean)

        const val ACTION_START = "com.lachancuocgoi.ACTION_START_BACKGROUND_MONITORING"
        const val ACTION_STOP = "com.lachancuocgoi.ACTION_STOP_BACKGROUND_MONITORING"

        // Watchdog constants
        const val WATCHDOG_PREFS = "monitoring_watchdog"
        private const val KEY_MONITORING_WAS_ACTIVE = "monitoring_was_active"
        private const val KEY_WATCHDOG_PHONE_NUMBER = "watchdog_phone_number"
        private const val KEY_WATCHDOG_SPEAKERPHONE = "watchdog_speakerphone"
        const val WATCHDOG_INTERVAL_MINUTES = 5

        @Volatile
        var isRunning = false

        /**
         * Check if monitoring should be running according to persisted state.
         * Used by [ServiceWatchdogReceiver] to decide if it should auto-restart.
         */
        fun wasMonitoringActive(context: Context): Boolean {
            val prefs = context.getSharedPreferences(WATCHDOG_PREFS, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_MONITORING_WAS_ACTIVE, false)
        }

        /**
         * Sprint 2 (B6): read the last-known ACTION_START extras so the
         * watchdog can re-attach the same params when it auto-restarts
         * the service after a kill.
         */
        fun lastStartParams(context: Context): Pair<String?, Boolean> {
            val prefs = context.getSharedPreferences(WATCHDOG_PREFS, Context.MODE_PRIVATE)
            val phone = prefs.getString(KEY_WATCHDOG_PHONE_NUMBER, null)
            val speaker = prefs.getBoolean(KEY_WATCHDOG_SPEAKERPHONE, false)
            return phone to speaker
        }

        /**
         * Clear the persisted monitoring-active flag.
         * Called when monitoring is intentionally stopped.
         */
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
