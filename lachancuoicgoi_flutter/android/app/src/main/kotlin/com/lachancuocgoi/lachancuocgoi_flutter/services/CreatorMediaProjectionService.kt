package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.lachancuocgoi.lachancuocgoi_flutter.R
import com.lachancuocgoi.lachancuocgoi_flutter.audio.CreatorAudioCaptureManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min

/**
 * Creator Mode service that captures system audio through MediaProjection and
 * forwards transcript/RMS events to Flutter.
 */
class CreatorMediaProjectionService : Service() {

    companion object {
        var onMediaProjectionReady: ((MediaProjection) -> Unit)? = null
        const val ACTION_START = "START"
        const val ACTION_STOP = "STOP"
        private const val TAG = "CreatorService"
        private const val NOTIFICATION_ID = 2001
        private const val CHANNEL_ID = "media_projection_channel"

        @Volatile
        var isRunning = false
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var captureJob: Job? = null
    private var transcriptJob: Job? = null
    private var devModeWatchdogJob: Job? = null
    private var projection: MediaProjection? = null
    private var startedAtMs: Long = 0L
    private var stopEventSent = false

    private lateinit var voskSttManager: VoskSttManager

    override fun onCreate() {
        super.onCreate()
        voskSttManager = VoskSttManager(application)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            isRunning = false
            stopCapture()
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        isRunning = true
        createNotificationChannel()
        startForegroundInternal()

        val devModeExpiresAtMs = intent?.getLongExtra("devModeExpiresAtMs", 0L) ?: 0L
        if (devModeExpiresAtMs <= System.currentTimeMillis()) {
            Log.w(TAG, "Developer Mode expired or missing. Stopping Creator service.")
            stopCapture()
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        val code = intent?.getIntExtra("code", 0) ?: 0
        val data = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra("data", Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra("data")
        }

        if (code != 0 && data != null) {
            try {
                val mediaProjectionManager =
                    getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                val readyProjection = mediaProjectionManager.getMediaProjection(code, data)
                if (readyProjection != null) {
                    projection = readyProjection
                    onMediaProjectionReady?.invoke(readyProjection)
                    startAudioLoop(readyProjection, devModeExpiresAtMs)
                }
                Log.d(TAG, "MediaProjection obtained successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get MediaProjection", e)
                NativeBridgeEventSink.sendMonitoringState("STOPPED:0:")
            }
        }

        return START_NOT_STICKY
    }

    private fun startForegroundInternal() {
        val stopIntent = Intent(this, CreatorMediaProjectionService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            0,
            stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.app_name))
            .setContentText("Creator Mode: Đang ghi âm ngầm (Live)")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "DỪNG", stopPendingIntent)
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val foregroundType =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                    } else {
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                    }
                startForeground(NOTIFICATION_ID, notification, foregroundType)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground", e)
        }
    }

    private fun startAudioLoop(mediaProjection: MediaProjection, devModeExpiresAtMs: Long) {
        startedAtMs = System.currentTimeMillis()
        stopEventSent = false
        val record = CreatorAudioCaptureManager.startCapture(mediaProjection)
        if (record == null) {
            sendStoppedState()
            return
        }

        voskSttManager.resetTranscript()
        NativeBridgeEventSink.sendMonitoringState("STARTED")

        devModeWatchdogJob?.cancel()
        devModeWatchdogJob = serviceScope.launch {
            while (isActive) {
                val remainingMs = devModeExpiresAtMs - System.currentTimeMillis()
                if (remainingMs <= 0L) {
                    Log.w(TAG, "Developer Mode expired. Stopping Creator service.")
                    stopCapture()
                    stopForegroundCompat()
                    stopSelf()
                    break
                }
                delay(max(1000L, min(5000L, remainingMs)))
            }
        }

        transcriptJob?.cancel()
        transcriptJob = serviceScope.launch {
            kotlinx.coroutines.flow.combine(
                voskSttManager.voskFullTranscript,
                voskSttManager.voskTextResults
            ) { cumulative, partial ->
                val composed = if (partial.isNotBlank() && cumulative.isNotBlank()) {
                    "$cumulative\n$partial"
                } else if (partial.isNotBlank()) {
                    partial
                } else {
                    cumulative
                }
                composed to partial.isNotBlank()
            }.collect { (text, isPartial) ->
                if (text.isNotBlank()) {
                    CreatorAudioCaptureManager.updateTranscript(text)
                    NativeBridgeEventSink.sendTranscript(text, isPartial)
                }
            }
        }

        captureJob?.cancel()
        captureJob = serviceScope.launch {
            val buffer = ByteArray(CreatorAudioCaptureManager.BUFFER_SIZE)
            try {
                while (isActive) {
                    val read = record.read(buffer, 0, buffer.size)
                    if (read > 0) {
                        val amplitude = buffer.take(read)
                            .chunked(2)
                            .mapNotNull { bytes ->
                                if (bytes.size < 2) {
                                    null
                                } else {
                                    (bytes[1].toInt() shl 8 or (bytes[0].toInt() and 0xFF))
                                        .toShort()
                                        .toInt()
                                }
                            }
                            .map { kotlin.math.abs(it).toFloat() }
                            .average()
                            .toFloat()
                        val normalizedRms = (amplitude / 2184f).coerceIn(0f, 15f)
                        CreatorAudioCaptureManager.emitAmplitude(normalizedRms)
                        NativeBridgeEventSink.sendRms(normalizedRms)
                        voskSttManager.processAudioBuffer(buffer, read)
                    } else if (read < 0) {
                        break
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Creator capture loop failed", e)
            }
        }
    }

    private fun stopCapture() {
        captureJob?.cancel()
        transcriptJob?.cancel()
        devModeWatchdogJob?.cancel()
        projection?.stop()
        projection = null
        CreatorAudioCaptureManager.stopCapture()
        voskSttManager.destroy()
        sendStoppedState()
    }

    private fun sendStoppedState() {
        if (stopEventSent) return
        stopEventSent = true
        val durationSeconds =
            if (startedAtMs > 0L) ((System.currentTimeMillis() - startedAtMs) / 1000L).toInt() else 0
        val finalTranscript = CreatorAudioCaptureManager.creatorTranscriptFlow.value
        NativeBridgeEventSink.sendMonitoringState("STOPPED:$durationSeconds:$finalTranscript")
    }

    override fun onDestroy() {
        super.onDestroy()
        stopCapture()
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Media Projection Service",
                NotificationManager.IMPORTANCE_HIGH,
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
