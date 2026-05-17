package com.lachancuocgoi.lachancuocgoi_flutter.services

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
import com.lachancuocgoi.lachancuocgoi_flutter.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
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

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        speechToTextManager = SpeechToTextManager(application)
        connectivityMonitor = ConnectivityMonitor(application)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
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
                    return START_NOT_STICKY
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
            }
        }

        // Request audio focus
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
        }

        monitoringJob = serviceScope.launch {
            delay(1000)

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

            // Start listening
            try {
                speechToTextManager.startListening()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start listening", e)
            }

            updateNotification("Đang giám sát cuộc gọi (Mic + Phụ đề)...")

            // Observe RMS for waveform → stream to Flutter
            speechToTextManager.rmsDbFlow
                .onEach { rms ->
                    NativeBridgeEventSink.sendRms(rms)
                }
                .launchIn(this)

            // Collect transcript from STT + TranscriptionHub
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
                        // Stream transcript to Flutter
                        NativeBridgeEventSink.sendTranscript(text)
                    }
                }
            }
        }
    }

    private fun stopMonitoring() {
        if (isStopping) return

        isStopping = true
        isMonitoringActive = false
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
        connectivityMonitor.stop()
        serviceJob.cancel()
        speechToTextManager.destroy()
        if (hadAudioFocus) {
            releaseAudioFocus()
        }
        if (speakerphoneChangedByService) {
            disableSpeakerphone()
        }
    }

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

    companion object {
        private const val TAG = "BackgroundMonitoringSvc"
        private const val NOTIFICATION_ID = 2
        private const val CHANNEL_ID = "BackgroundMonitoringChannel"
        const val ACTION_START = "com.lachancuocgoi.ACTION_START_BACKGROUND_MONITORING"
        const val ACTION_STOP = "com.lachancuocgoi.ACTION_STOP_BACKGROUND_MONITORING"

        @Volatile
        var isRunning = false
            private set
    }
}
