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
    // Wave 3: notification lifecycle extracted to a dedicated helper. Built once
    // in onCreate(); every later updateNotification() call delegates to it.
    private lateinit var notificationBuilder: MonitoringNotificationBuilder
    // Wave 3: AlarmManager scheduling extracted to a dedicated helper. Lazy so
    // it is created only when first needed (onCreate does not call any watchdog
    // method; the alarm path runs on onStartCommand / onTaskRemoved / onDestroy).
    private val watchdogScheduler by lazy { WatchdogScheduler(this) }

    private var currentTranscript = ""
    private var startTime: Long = 0
    private var monitoringJob: Job? = null
    private var connectivityJob: Job? = null
    private var transcriptCollectorJob: Job? = null

    // Dedicated lock object for `currentTranscript`. Previously `synchronized(this)`
    // was used from both the main thread and the IO collector coroutine, which
    // risks cross-thread deadlocks if any main-thread path ever holds the
    // service lock. A plain String field guarded by its own lock is enough.
    private val transcriptLock = Any()

    // PARTIAL_WAKE_LOCK held for the duration of active monitoring. A foreground
    // service keeps the process alive but does NOT by itself keep the CPU out
    // of suspend — on many OEMs the device enters Doze once the screen is off,
    // stalling the Vosk `record.read()` loop and the watchdog alarm. This is
    // the most likely root cause of "transcript stops mid-call" reports.
    private var wakeLock: PowerManager.WakeLock? = null

    @Volatile private var isMonitoringActive = false
    @Volatile private var isStopping = false

    // Bug #15 fix: per-source last-update timestamps. Used by the transcript
    // combine block to drop stale partials when switching engines mid-call.
    @Volatile private var lastSttUpdateMs: Long = 0L
    @Volatile private var lastPartialUpdateMs: Long = 0L
    @Volatile private var lastAccUpdateMs: Long = 0L

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
        // Wave 3: notification + watchdog scheduling extracted into helpers so
        // this service body focuses on lifecycle and STT orchestration.
        notificationBuilder = MonitoringNotificationBuilder(this, BackgroundMonitoringService::class.java)
        // watchdogScheduler is `by lazy` — initialized on first use.
        
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

        // POST_NOTIFICATIONS is not required to launch an FGS. Android still
        // requires startForeground() and shows the disclosure in Task Manager
        // when notification permission is denied.
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
        // Persist parameters before starting so the watchdog can re-attach
        // them when it restarts the service after a process kill.
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
        // A consented call must never retain a stale overlay/session when the
        // foreground-service promotion is rejected by Android.
        CallSessionCoordinator.onMonitoringServiceStopped(applicationContext)
        stopSelf(startId)
    }

    @Suppress("DEPRECATION")
    private fun startMonitoring() {
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

        // Notify Flutter that monitoring started
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
        MonitoringPerfProbe.end(
            startToken,
            "google_available=$googleAvailable,audio_focus=$hadAudioFocus",
        )

        // Bug #20 fix: snapshot the speakerphone state BEFORE any audio
        // mode change. The previous code captured it after the focus
        // request, which can flip the audio mode from MODE_NORMAL to
        // MODE_IN_COMMUNICATION and back, leaving isSpeakerphoneOn in an
        // unstable state. Capture early so the restore at stopMonitoring()
        // is deterministic.
        wasSpeakerphoneOn = audioManager.isSpeakerphoneOn
        speakerphoneChangedByService = false

        monitoringJob = serviceScope.launch {
            // Reduced from 1000ms to 100ms — just enough for service to stabilize
            // without losing the first second of the call.
            delay(100)

            // Bug #9 fix: removed the redundant enableSpeakerphone() call that
            // used to run before this launch block. Only enable once, here,
            // after the audio mode has had time to settle. The pre-launch
            // call was duplicating work AND sometimes racing with the audio
            // mode switch (would silently fail then succeed a moment later).
            if (shouldEnableSpeakerphone) {
                enableSpeakerphone()
                Log.d(TAG, "Speakerphone enabled for monitoring")
                NativeBridgeEventSink.sendLog(
                    TAG,
                    "Bật loa ngoài để giám sát cuộc gọi.",
                    "INFO",
                )
            }

            // Speakerphone enforcement loop — Bug #9 fix: increased from 2s
            // to 5s. The 2s cadence was wasteful CPU on long calls (a 1h call
            // = 1800 needless polls). 5s is responsive enough that the user
            // won't notice any gap.
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
                    // Surface a first-class fatal monitoring state so Flutter
                    // can show a retry banner instead of a silent empty transcript.
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

            // Observe RMS for waveform → stream to Flutter
            speechToTextManager.rmsDbFlow
                .onEach { rms ->
                    NativeBridgeEventSink.sendRms(rms)
                    OverlayManager.updateMonitoringRms(rms)
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
            //
            // Bug #15 fix: track per-source timestamps and ignore a partial
            // whose source has gone stale (e.g. user switched from Google STT
            // to Vosk — the old Google partial shouldn't suddenly appear in
            // the Vosk session). Each tick captures `now`; partials older than
            // [MAX_PARTIAL_AGE_MS] are dropped from the composed output.
            transcriptCollectorJob = launch {
                // Bug #15 fix (revised): removed separate timestamp observer
                // coroutines. They caused an infinite loop: combine emits →
                // Flutter updates TranscriptionHub → TranscriptionHub emits
                // → observer updates timestamp → combine fires again.
                // Instead, track timestamps inline: each time a new value
                // arrives from a source, update its timestamp. The combine
                // lambda receives the new value AND the timestamp in the
                // same invocation, so staleness is always evaluated on the
                // value that triggered the emission.
                combine(
                    speechToTextManager.fullTranscriptFlow,
                    speechToTextManager.textResults,
                    TranscriptionHub.transcriptFlow,
                ) { stt, partial, acc ->
                    val now = System.currentTimeMillis()
                    // Update per-source timestamp when a new value arrives.
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

        releaseWakeLock()

        val endTime = System.currentTimeMillis()
        val duration = (endTime - startTime) / 1000

        val finalTranscript = synchronized(transcriptLock) { currentTranscript.trim() }

        // Notify Flutter that monitoring stopped with final data
        NativeBridgeEventSink.sendMonitoringState("STOPPED:$duration:$finalTranscript")
        CallSessionCoordinator.onMonitoringServiceStopped(applicationContext)

        finalizationScope.launch {
            try {
                // Cleanup handled by Flutter side (save history via Dart)
                Log.d(TAG, "Monitoring stopped. Duration: ${duration}s, transcript length: ${finalTranscript.length}")
            } finally {
                stopSelf()
            }
        }
    }

    private fun createMonitoringNotification(text: String): android.app.Notification {
        // Channel creation is idempotent; ensure it exists before every build
        // to preserve the original contract (the old inlined version called
        // createNotificationChannel() unconditionally here).
        notificationBuilder.ensureChannel(CHANNEL_ID, "Giám sát cuộc gọi")
        return notificationBuilder.build(CHANNEL_ID, ACTION_STOP, text)
    }

    private fun updateNotification(text: String) {
        notificationBuilder.update(CHANNEL_ID, ACTION_STOP, NOTIFICATION_ID, text)
    }

    override fun onDestroy() {
        super.onDestroy()
        speechToTextManager.releaseVoskModel()
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
        releaseWakeLock()
        // Bug #10 fix: also cancel the watchdog alarm here. Previously,
        // onDestroy() left both PendingIntents scheduled (request codes 0
        // and 1) even though the service was going away. The alarm kept
        // firing every 5 min, waking the device from Doze, just to see
        // isRunning=false and no-op. Wasted battery.
        // Cancel only if we're NOT intentionally stopping — if the user
        // requested stop, stopMonitoring() already cancelled.
        if (!isStopping) {
            cancelWatchdogAlarm()
        }
        // If we're being destroyed but not intentionally stopped, the watchdog
        // will detect the stale persisted flag and restart us.
    }

    @Suppress("DEPRECATION")
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
            // Bug fix: only use setAlarmClock (higher priority, exempt from permission)
            // Previously both setInexactRepeating and setAlarmClock were scheduled,
            // causing duplicate alarms to fire every 5 minutes.
            scheduleExactWatchdogAlarm()
        }
    }

    private fun scheduleExactWatchdogAlarm() =
        watchdogScheduler.scheduleExact(WATCHDOG_INTERVAL_MINUTES)

    /**
     * Acquire a PARTIAL_WAKE_LOCK for the whole monitoring session. The mic
     * read loop (Vosk) and the watchdog alarm rely on the CPU staying awake;
     * without this the device enters Doze on screen-off and transcript capture
     * stalls mid-call on many OEMs.
     */
    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "lachancuocgoi::monitoring_wakelock"
            ).apply {
                // Reference-counted = false so multiple acquire() calls don't
                // stack; we manage lifetime explicitly via start/stop.
                setReferenceCounted(false)
                acquire(/* timeout */ 6 * 60 * 60 * 1000L) // 6h safety release
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
                                
                                // Bug fix: abandon focus request to prevent listener leak
                                // (previously only set hadAudioFocus=false, leaving request in AudioManager)
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

    // ─── SharedPreferences persistence ───────────────────────────────────

    private fun getWatchdogPrefs(): SharedPreferences =
        getSharedPreferences(WATCHDOG_PREFS, Context.MODE_PRIVATE)

    private fun persistMonitoringActive(active: Boolean) {
        val editor = getWatchdogPrefs().edit().putBoolean(KEY_MONITORING_WAS_ACTIVE, active)
        if (!active) {
            // Sprint 2 (B6): also clear the last-known start params so
            // the watchdog does not resurrect a stale session.
            editor.remove(KEY_WATCHDOG_PHONE_NUMBER)
                .remove(KEY_WATCHDOG_SPEAKERPHONE)
            cancelWatchdogAlarm()
        }
        editor.apply()
    }

    /**
     * Sprint 2 (B6): stash the latest ACTION_START intent extras so the
     * watchdog receiver can re-attach the speakerphone flag when it
     * auto-restarts the service after a system kill. Phone numbers are never
     * persisted because monitoring does not need them.
     */
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

        /** Minimum gap between resume attempts to break the focus flapping cycle. */
        private const val FOCUS_RESUME_COOLDOWN_MS = 500L
        /** Delay before actually resuming STT after focus gain. */
        private const val FOCUS_RESUME_DELAY_MS = 600L
        /** Bug #9 fix: speakerphone enforcement loop interval (was 2000ms). */
        private const val SPEAKERPHONE_ENFORCEMENT_INTERVAL_MS = 5000L
        /**
         * Bug #15 fix: maximum age of a partial transcript before it is
         * considered stale and dropped from the composed output. When the
         * user switches STT engine mid-call (Google → Vosk, or vice versa)
         * the previous engine's last partial can briefly leak through; this
         * window ensures we drop it within a reasonable time.
         *
         * Bug fix (review): 3s was too short — Google STT can take 5-10s
         * to emit a partial on slow networks. Increased to 10s to avoid
         * dropping legitimate partials while still catching stale ones from
         * engine switches.
         */
        private const val MAX_PARTIAL_AGE_MS = 10_000L

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
         * watchdog can re-attach the non-sensitive params when it auto-restarts
         * the service after a kill. A legacy phone-number value is removed.
         */
        fun lastStartParams(context: Context): Pair<String?, Boolean> {
            val prefs = context.getSharedPreferences(WATCHDOG_PREFS, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_WATCHDOG_PHONE_NUMBER).apply()
            val speaker = prefs.getBoolean(KEY_WATCHDOG_SPEAKERPHONE, false)
            return null to speaker
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
