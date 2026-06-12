package com.example.lachancuocgoi.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.lachancuocgoi.Analysis.AnalysisCoordinator
import com.example.lachancuocgoi.Analysis.AnalysisModePolicy
import com.example.lachancuocgoi.Analysis.AnalysisResult
import com.example.lachancuocgoi.R
import com.example.lachancuocgoi.RiskLevel
import com.example.lachancuocgoi.data.AppDatabase
import com.example.lachancuocgoi.data.CallHistory
import com.example.lachancuocgoi.data.TranscriptSaver
import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.AnalysisMode
import com.example.lachancuocgoi.ui.OverlayManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class BackgroundMonitoringService : Service() {

    // (SỬA BUG 5) Tách riêng Job để cancel trong onDestroy().
    // Trước đây Job() nằm inline → không thể cancel → memory leak.
    private val serviceJob = Job()
    private val serviceScope = CoroutineScope(Dispatchers.IO + serviceJob)
    private val finalizationScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private lateinit var speechToTextManager: SpeechToTextManager
    private lateinit var analysisCoordinator: AnalysisCoordinator
    private lateinit var callHistoryDao: AppDatabase
    private lateinit var audioManager: AudioManager

    private var currentTranscript = ""
    private var startTime: Long = 0
    private var monitoringJob: Job? = null
    private var analysisLoopJob: Job? = null
    private var alertLoopJob: Job? = null
    private var connectivityJob: Job? = null
    private var transcriptCollectorJob: Job? = null
    private var phoneNumber: String? = null

    private var pendingRiskResult: AnalysisResult? = null
    @Volatile private var isMonitoringActive = false
    @Volatile private var isStopping = false
    
    // Audio focus management
    private var audioFocusRequest: AudioFocusRequest? = null
    private var hadAudioFocus = false
    
    // Speakerphone state
    private var wasSpeakerphoneOn = false
    private var shouldEnableSpeakerphone = false
    private var speakerphoneChangedByService = false

    private lateinit var connectivityMonitor: ConnectivityMonitor
    private var selectedMode: AnalysisMode = AnalysisMode.GDetection
    private var effectiveMode: AnalysisMode = AnalysisMode.GDetection
    private var networkAvailable = false
    private var isL3FallbackActive = false
    private var hasShownFallbackAlertForCurrentOutage = false
    private var lastL3RecoveryAttemptAt = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        speechToTextManager = SpeechToTextManager(application)
        analysisCoordinator = AnalysisCoordinator(application)
        connectivityMonitor = ConnectivityMonitor(application)
        callHistoryDao = AppDatabase.getDatabase(applicationContext)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        phoneNumber = intent?.getStringExtra("PHONE_NUMBER")
        shouldEnableSpeakerphone = intent?.getBooleanExtra("ENABLE_SPEAKERPHONE", false) ?: false
        
        // Also check from settings if not provided in intent
        if (!shouldEnableSpeakerphone) {
            val sharedPreferences = getSharedPreferences("settings", Context.MODE_PRIVATE)
            shouldEnableSpeakerphone = sharedPreferences.getBoolean("AUTO_ENABLE_SPEAKERPHONE", false)
        }
        
        when (intent?.action) {
            ACTION_START -> {
                if (isMonitoringActive || isStopping) {
                    Log.i(TAG, "Ignoring duplicate start request while monitoring is active.")
                    return START_NOT_STICKY
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(NOTIFICATION_ID, createMonitoringNotification("Đang sẵn sàng bảo vệ..."), android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
                } else {
                    startForeground(NOTIFICATION_ID, createMonitoringNotification("Đang sẵn sàng bảo vệ..."))
                }
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
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun startMonitoring() {
        Log.d(TAG, "Starting dual-source monitoring.")
        isMonitoringActive = true
        isStopping = false
        startTime = System.currentTimeMillis()
        monitoringJob?.cancel()
        analysisLoopJob?.cancel()
        alertLoopJob?.cancel()
        connectivityJob?.cancel()
        transcriptCollectorJob?.cancel()
        synchronized(this) {
            currentTranscript = ""
            pendingRiskResult = null
        }
        analysisCoordinator.reset()
        TranscriptionHub.reset()

        val sharedPreferences = getSharedPreferences("settings", Context.MODE_PRIVATE)
        val analysisModeName = sharedPreferences.getString("ANALYSIS_MODE", AnalysisMode.GDetection.name)
        selectedMode = parseAnalysisMode(analysisModeName)
        val analysisMode = selectedMode
        networkAvailable = connectivityMonitor.checkCurrentConnectivity()
        effectiveMode = AnalysisModePolicy.resolveEffectiveMode(selectedMode, networkAvailable)
        isL3FallbackActive = selectedMode == AnalysisMode.GEMINI_API && effectiveMode != AnalysisMode.GEMINI_API
        hasShownFallbackAlertForCurrentOutage = false
        lastL3RecoveryAttemptAt = 0L

        connectivityMonitor.start()
        connectivityJob = serviceScope.launch {
            connectivityMonitor.isNetworkAvailable.collectLatest { isAvailable ->
                handleConnectivityChanged(isAvailable)
            }
        }
        
        // Request audio focus before starting speech recognition
        hadAudioFocus = requestAudioFocus()
        if (hadAudioFocus) {
            Log.d(TAG, "Audio focus granted")
        } else {
            Log.w(TAG, "Could not obtain audio focus, speech recognition may be unreliable")
        }
        
        wasSpeakerphoneOn = audioManager.isSpeakerphoneOn
        speakerphoneChangedByService = false
        if (shouldEnableSpeakerphone) {
            enableSpeakerphone()
            Log.d(TAG, "Speakerphone enabled for monitoring")
        } else {
            Log.d(TAG, "Speakerphone auto-enable disabled by settings")
        }

        monitoringJob = serviceScope.launch {
            // Delay to allow phone app to settle audio routing
            delay(1000)
            
            // Show the floating monitoring overlay
            launch(Dispatchers.Main) {
                OverlayManager.showMonitoringOverlay(applicationContext)
            }

            if (shouldEnableSpeakerphone) {
                enableSpeakerphone()
                Log.d(TAG, "Speakerphone initial enable")
            }

            // Start Speakerphone Enforcement Loop
            launch {
                while (isActive) {
                    if (shouldEnableSpeakerphone && !audioManager.isSpeakerphoneOn) {
                        Log.w(TAG, "Speakerphone was disabled! Re-enabling...")
                        enableSpeakerphone()
                    }
                    delay(2000) // Check every 2 seconds
                }
            }

            // Bắt đầu lắng nghe từ Mic
            try {
                speechToTextManager.startListening()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start listening", e)
            }
            
            updateNotification("Đang giám sát cuộc gọi (Mic + Phụ đề)...")
            startAlertLoop()

            // Observe RMS for waveform
            speechToTextManager.rmsDbFlow
                .onEach { rms ->
                    launch(Dispatchers.Main) {
                        OverlayManager.updateWaveform(rms)
                    }
                }
                .launchIn(this)

            // Tách biệt việc thu thập transcript
            transcriptCollectorJob = launch {
                combine(
                    speechToTextManager.fullTranscriptFlow,
                    TranscriptionHub.transcriptFlow
                ) { stt, acc ->
                    "$stt\n$acc".trim()
                }.collect { text ->
                    if (text.isNotBlank()) {
                        synchronized(this@BackgroundMonitoringService) {
                            currentTranscript = text
                        }
                    }
                }
            }
        }

        analysisLoopJob = serviceScope.launch {
            if (effectiveMode == AnalysisMode.GEMINI_API) {
                analysisCoordinator.createL3Session()
            }

            while (isActive) {
                val snapshotTranscript = synchronized(this@BackgroundMonitoringService) { currentTranscript.trim() }
                if (snapshotTranscript.isBlank()) {
                    delay(500)
                    continue
                }

                if (selectedMode == AnalysisMode.GEMINI_API && isL3FallbackActive && networkAvailable) {
                    tryRecoverL3Session(snapshotTranscript, force = false)
                }

                when (effectiveMode) {
                    AnalysisMode.GEMINI_API -> {
                        val result = analysisCoordinator.analyzeIncrementalL3(snapshotTranscript)
                        when {
                            result == null -> delay(500)
                            result.isError -> {
                                enterL3FallbackMode(showAlert = true)
                                val fallbackResult = analysisCoordinator.analyzeIncremental(
                                    snapshotTranscript,
                                    AnalysisMode.GDetection
                                )
                                handleAnalysisResult(fallbackResult)
                            }
                            else -> handleAnalysisResult(result)
                        }
                    }

                    AnalysisMode.NORMAL,
                    AnalysisMode.GDetection -> {
                        if (snapshotTranscript.length > analysisCoordinator.getProcessedTextLength(effectiveMode)) {
                            val result = analysisCoordinator.analyzeIncremental(snapshotTranscript, effectiveMode)
                            handleAnalysisResult(result)
                        }
                        delay(1500)
                    }
                }
            }
        }
    }

    private suspend fun handleConnectivityChanged(isAvailable: Boolean) {
        val previousState = networkAvailable
        networkAvailable = isAvailable

        if (selectedMode != AnalysisMode.GEMINI_API) {
            effectiveMode = selectedMode
            isL3FallbackActive = false
            return
        }

        if (!isAvailable) {
            enterL3FallbackMode(showAlert = previousState)
            return
        }

        if (!previousState && isAvailable) {
            delay(NETWORK_RECOVERY_DEBOUNCE_MS)
            if (networkAvailable && selectedMode == AnalysisMode.GEMINI_API) {
                tryRecoverL3Session(
                    synchronized(this@BackgroundMonitoringService) { currentTranscript.trim() },
                    force = true
                )
            }
        }
    }

    private suspend fun tryRecoverL3Session(
        currentFullText: String,
        force: Boolean
    ) {
        if (selectedMode != AnalysisMode.GEMINI_API || !networkAvailable) return

        val now = System.currentTimeMillis()
        if (!force && now - lastL3RecoveryAttemptAt < L3_RECOVERY_RETRY_MS) {
            return
        }
        lastL3RecoveryAttemptAt = now

        val replayStart = (currentFullText.length - L3_REPLAY_WINDOW_CHARS).coerceAtLeast(0)
        analysisCoordinator.createL3Session(initialProcessedTextLength = replayStart)
        effectiveMode = AnalysisMode.GEMINI_API
        isL3FallbackActive = false
        updateNotification("Mạng ổn định. Đang quay lại phân tích L3...")

        val warmupResult = if (currentFullText.isBlank()) {
            null
        } else {
            analysisCoordinator.analyzeIncrementalL3(currentFullText)
        }

        if (warmupResult?.isError == true) {
            enterL3FallbackMode(showAlert = !hasShownFallbackAlertForCurrentOutage)
            return
        }

        hasShownFallbackAlertForCurrentOutage = false
        updateNotification("Đang giám sát cuộc gọi bằng L3...")
        warmupResult?.let { handleAnalysisResult(it) }
    }

    private fun enterL3FallbackMode(showAlert: Boolean) {
        val enteringFallback = !isL3FallbackActive || effectiveMode != AnalysisMode.GDetection
        analysisCoordinator.closeL3Session()
        if (enteringFallback) {
            analysisCoordinator.resetMode(AnalysisMode.GDetection)
        }

        effectiveMode = AnalysisMode.GDetection
        isL3FallbackActive = true
        lastL3RecoveryAttemptAt = 0L
        updateNotification("Mất mạng. Đang dùng L2 dự phòng để tiếp tục bảo vệ...")

        if (showAlert && !hasShownFallbackAlertForCurrentOutage) {
            hasShownFallbackAlertForCurrentOutage = true
            Log.w(TAG, "L3 unavailable. Falling back to L2.")
        }
    }

    private fun handleAnalysisResult(result: AnalysisResult) {
        if (result.matches.isNotEmpty() || result.overallRiskLevel != RiskLevel.GREEN) {
            synchronized(this@BackgroundMonitoringService) {
                val currentPending = pendingRiskResult
                if (currentPending == null || result.overallRiskLevel.ordinal > currentPending.overallRiskLevel.ordinal) {
                    pendingRiskResult = result
                }
            }
        }
    }

    private fun startAlertLoop() {
        alertLoopJob?.cancel()
        alertLoopJob = serviceScope.launch(Dispatchers.Main) {
            while (isActive) {
                delay(ALERT_LOOP_INTERVAL_MS)
                val resultToDisplay = synchronized(this@BackgroundMonitoringService) {
                    val res = pendingRiskResult
                    pendingRiskResult = null
                    res
                }

                // NEW: Chỉ show alert nếu alertEnabled = true
                if (resultToDisplay != null && resultToDisplay.alertEnabled) {
                    when (resultToDisplay.overallRiskLevel) {
                        RiskLevel.RED -> {
                            OverlayManager.showRedAlert(this@BackgroundMonitoringService, resultToDisplay.reason ?: "Rủi ro cao!")
                        }
                        RiskLevel.ORANGE -> {
                            OverlayManager.showOrangeAlert(this@BackgroundMonitoringService, resultToDisplay.reason ?: "Rủi ro trung bình!")
                        }
                        // Removed YELLOW case - only show ORANGE and RED warnings
                        else -> {}
                    }
                }
                // Nếu alertEnabled = false → CHỈ HIGHLIGHT từ khóa, KHÔNG show alert
            }
        }
    }

    private fun stopMonitoring() {
        if (isStopping) {
            return
        }

        isStopping = true
        isMonitoringActive = false
        connectivityJob?.cancel()
        transcriptCollectorJob?.cancel()
        monitoringJob?.cancel()
        analysisLoopJob?.cancel()
        alertLoopJob?.cancel()
        // (SỬA BUG 9) Xóa pending result ngay khi stop.
        // Trước đây nếu loop đang giữa chu kỳ delay 5s khi bị cancel,
        // pendingRiskResult vẫn còn → có thể trigger phantom alert.
        synchronized(this) {
            pendingRiskResult = null
        }
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
        
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            OverlayManager.removeAll(this@BackgroundMonitoringService)
        }
        
        val endTime = System.currentTimeMillis()
        val duration = (endTime - startTime) / 1000

        val finalTranscriptForPersistence = synchronized(this) { currentTranscript.trim() }
        finalizationScope.launch {
            try {
                persistFinalCallHistory(finalTranscriptForPersistence, duration)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to persist final call history", e)
            } finally {
                analysisCoordinator.closeL3Session(resetProgress = true)
                stopSelf()
            }
        }
    }

    private suspend fun persistFinalCallHistory(finalTranscript: String, duration: Long) {
        if (finalTranscript.isBlank()) {
            return
        }

        val sharedPreferences = getSharedPreferences("settings", Context.MODE_PRIVATE)
        val analysisModeName = sharedPreferences.getString("ANALYSIS_MODE", AnalysisMode.GDetection.name)
        val analysisMode = parseAnalysisMode(analysisModeName)
        val finalMode = if (analysisMode == AnalysisMode.GEMINI_API && !networkAvailable) {
            AnalysisMode.GDetection
        } else {
            effectiveMode
        }

        val result = analysisCoordinator.analyze(finalTranscript, finalMode)
        val storedTranscript = TranscriptSaver.prepareTranscriptForLocalStorage(finalTranscript)
        val analysisType = "GiÃ¡m sÃ¡t Ä‘a kÃªnh"

        val newCallHistory = CallHistory(
            dateTime = SimpleDateFormat("HH:mm:ss dd/MM/yyyy", Locale.getDefault()).format(Date(startTime)),
            riskLevel = result.overallRiskLevel.name,
            summary = result.reason ?: "An toÃ n",
            duration = "${duration}s",
            flagCount = result.matches.size,
            transcript = storedTranscript,
            audioPath = TranscriptSaver.saveTranscript(applicationContext, storedTranscript),
            analysisType = analysisType
        )
        callHistoryDao.callHistoryDao().insert(newCallHistory)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Giám sát cuộc gọi", NotificationManager.IMPORTANCE_LOW)
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
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setOngoing(true)
            .addAction(0, "Dừng", stopPendingIntent)
            .build()
    }

    private fun updateNotification(text: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, createMonitoringNotification(text))
    }

    private fun parseAnalysisMode(rawValue: String?): AnalysisMode {
        if (rawValue.isNullOrBlank()) return AnalysisMode.GDetection
        return runCatching { AnalysisMode.valueOf(rawValue) }
            .getOrElse {
                Log.w(TAG, "Invalid ANALYSIS_MODE='$rawValue', fallback to GDetection.")
                AnalysisMode.GDetection
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        isMonitoringActive = false
        connectivityMonitor.stop()
        
        // (SỬA BUG 5) Cancel toàn bộ coroutine scope thay vì chỉ cancel từng job riêng lẻ.
        // Trước đây chỉ cancel monitoringJob và alertLoopJob → các coroutine khác
        // (speakerphone loop, debounce, L3 analyze) vẫn tiếp tục chạy sau destroy.
        serviceJob.cancel()
        
        speechToTextManager.destroy()
        
        // Cleanup audio resources
        if (hadAudioFocus) {
            releaseAudioFocus()
        }
        if (speakerphoneChangedByService) {
            disableSpeakerphone()
        }
    }
    
    /**
     * Request audio focus to allow SpeechRecognizer to work during calls
     * @return true if audio focus was granted
     */
    /**
     * Request audio focus to allow SpeechRecognizer to work during calls
     * @return true if audio focus was granted
     */
    private fun requestAudioFocus(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ASSISTANT)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    .setWillPauseWhenDucked(false)
                    .setAcceptsDelayedFocusGain(true)
                    .setOnAudioFocusChangeListener { focusChange ->
                        // Handle focus change if needed
                        Log.d(TAG, "Audio focus changed: $focusChange")
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
    
    /**
     * Release audio focus
     */
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
    
    /**
     * Enable speakerphone mode
     * Note: We do NOT set MODE_IN_COMMUNICATION here because for GSM calls, 
     * the system already manages the mode (MODE_IN_CALL).
     * Forcing MODE_IN_COMMUNICATION can break call audio.
     */
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
    
    /**
     * Disable speakerphone and restore previous state
     */
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

    companion object {
        private const val TAG = "BackgroundMonitoringSvc"
        private const val NOTIFICATION_ID = 2
        private const val CHANNEL_ID = "BackgroundMonitoringChannel"
        const val ACTION_START = "com.example.lachancuocgoi.ACTION_START_BACKGROUND_MONITORING"
        const val ACTION_STOP = "com.example.lachancuocgoi.ACTION_STOP_BACKGROUND_MONITORING"
        private const val ALERT_LOOP_INTERVAL_MS = 5000L
        private const val L3_REPLAY_WINDOW_CHARS = 1000
        private const val L3_RECOVERY_RETRY_MS = 10_000L
        private const val NETWORK_RECOVERY_DEBOUNCE_MS = 1_500L
    }
}
