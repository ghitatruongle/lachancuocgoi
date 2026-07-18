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

    /**
     * Bug #7 fix: registered against [projection] so we know when the system
     * revokes it (user disabled it via Settings, OS killed the projection,
     * etc.). Without this callback the capture loop would keep reading 0
     * bytes silently and the user would see an empty transcript with no
     * indication of what went wrong.
     */
    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            Log.w(TAG, "MediaProjection stopped by system — tearing down capture loop")
            NativeBridgeEventSink.sendLog(
                TAG,
                "Quyền MediaProjection đã bị thu hồi. Dừng Creator Mode.",
                "WARN",
            )
            // Unregister to avoid re-entry if onStop fires multiple times.
            try {
                projection?.unregisterCallback(this)
            } catch (_: Exception) { /* ignore */ }
            stopCapture()
            stopForegroundCompat()
            stopSelf()
        }
    }

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
        if (intent?.action != ACTION_START) {
            Log.w(TAG, "Stopping Creator service after an empty or unsupported intent")
            isRunning = false
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val promoted = try {
            createNotificationChannel()
            startForegroundInternal()
        } catch (e: Exception) {
            Log.e(TAG, "Unable to create Creator foreground notification", e)
            false
        }
        if (!promoted) {
            failCreatorStart("foreground_promotion_failed")
            return START_NOT_STICKY
        }
        isRunning = true

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
                    // Bug #7 fix: register a callback so we are notified when
                    // the system revokes the projection (user went into
                    // Settings and turned it off, app killed by OS, etc.).
                    // Without this, the service would keep running with a
                    // dead projection — capture loop reads 0 bytes silently.
                    readyProjection.registerCallback(
                        projectionCallback,
                        android.os.Handler(android.os.Looper.getMainLooper()),
                    )
                    onMediaProjectionReady?.invoke(readyProjection)
                    startAudioLoop(readyProjection, devModeExpiresAtMs)
                } else {
                    failCreatorStart("media_projection_unavailable")
                    return START_NOT_STICKY
                }
                Log.d(TAG, "MediaProjection obtained successfully")
                NativeBridgeEventSink.sendLog(TAG, "Quyền ghi âm màn hình/hệ thống đã được cấp thành công.", "INFO")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get MediaProjection", e)
                NativeBridgeEventSink.sendLog(TAG, "Không thể lấy quyền MediaProjection: ${e.message}", "ERROR")
                failCreatorStart("media_projection_failure")
                return START_NOT_STICKY
            }
        } else {
            failCreatorStart("media_projection_data_missing")
            return START_NOT_STICKY
        }

        return START_NOT_STICKY
    }

    private fun startForegroundInternal(): Boolean {
        return try {
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

            val foregroundType =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                } else {
                    0
                }
            ForegroundServiceLauncher.safeStartForeground(
                this,
                NOTIFICATION_ID,
                notification,
                foregroundType,
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to build or post Creator foreground notification", e)
            false
        }
    }

    private fun failCreatorStart(reason: String) {
        Log.e(TAG, "Creator service start failed: $reason")
        isRunning = false
        NativeBridgeEventSink.sendLog(
            TAG,
            "Không thể khởi động Creator Mode.",
            "ERROR",
        )
        NativeBridgeEventSink.sendMonitoringState("START_FAILED:nativeFailure:$reason")
        stopEventSent = true
        stopCapture()
        stopForegroundCompat()
        stopSelf()
    }

    private fun startAudioLoop(mediaProjection: MediaProjection, devModeExpiresAtMs: Long) {
        startedAtMs = System.currentTimeMillis()
        stopEventSent = false
        val record = CreatorAudioCaptureManager.startCapture(this, mediaProjection)
        if (record == null) {
            NativeBridgeEventSink.sendLog(TAG, "Không thể bắt đầu capture audio hệ thống (AudioRecord null)", "ERROR")
            failCreatorStart("audio_capture_unavailable")
            return
        }

        voskSttManager.resetTranscript()
        NativeBridgeEventSink.sendLog(TAG, "Đang khởi động giám sát ngầm ở chế độ Creator...", "INFO")
        NativeBridgeEventSink.sendMonitoringState("STARTED")

        devModeWatchdogJob?.cancel()
        devModeWatchdogJob = serviceScope.launch {
            while (isActive) {
                val remainingMs = devModeExpiresAtMs - System.currentTimeMillis()
                if (remainingMs <= 0L) {
                    Log.w(TAG, "Developer Mode expired. Stopping Creator service.")
                    NativeBridgeEventSink.sendLog(TAG, "Hết hạn chế độ Developer Mode. Tiến hành dừng Creator Service.", "WARN")
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
                        // Zero-allocation RMS calculation to avoid GC pressure in high-frequency audio loop
                        var sum = 0.0
                        var count = 0
                        var i = 0
                        while (i + 1 < read) {
                            val sample = (buffer[i + 1].toInt() shl 8 or (buffer[i].toInt() and 0xFF)).toShort().toInt()
                            sum += if (sample >= 0) sample.toDouble() else -sample.toDouble()
                            count++
                            i += 2
                        }
                        val amplitude = if (count > 0) (sum / count).toFloat() else 0f
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
        // Bug #7 fix: unregister our callback BEFORE stopping the projection
        // to break the potential re-entry loop if onStop() fires during the
        // teardown.
        try {
            projection?.unregisterCallback(projectionCallback)
        } catch (_: Exception) { /* ignore */ }
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
        isRunning = false
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
