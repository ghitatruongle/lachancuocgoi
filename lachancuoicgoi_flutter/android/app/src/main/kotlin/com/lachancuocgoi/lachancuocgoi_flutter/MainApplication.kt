package com.lachancuocgoi.lachancuocgoi_flutter

import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Looper
import com.lachancuocgoi.lachancuocgoi_flutter.diagnostics.MonitoringPerfProbe
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeBridgeChannels
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

class MainApplication : Application() {

    @Volatile
    private var monitoringFlutterEngine: FlutterEngine? = null

    companion object {
        const val BACKGROUND_MONITORING_CHANNEL_ID = "BackgroundMonitoringChannel"
        const val INCOMING_CALL_CHANNEL_ID = "IncomingCallChannel"
        const val MEDIA_PROJECTION_CHANNEL_ID = "media_projection_channel"

        const val LOCKSCREEN_VISIBILITY_NO_OVERRIDE = -1000
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    @Synchronized
    fun ensureFlutterEngine(): FlutterEngine {
        val totalToken = MonitoringPerfProbe.begin("flutter_engine_total")
        var totalOutcome = "success=false"
        try {
            monitoringFlutterEngine?.let { existing ->
                totalOutcome = "success=true,warm=true"
                MonitoringPerfProbe.mark("flutter_engine_reused")
                return existing
            }
            check(Looper.myLooper() == Looper.getMainLooper()) {
                "FlutterEngine must be created on the Android main thread"
            }

            val constructorToken = MonitoringPerfProbe.begin("flutter_engine_constructor")
            val engine = try {
                FlutterEngine(this).also {
                    MonitoringPerfProbe.end(constructorToken, "success=true")
                }
            } catch (error: Throwable) {
                MonitoringPerfProbe.end(
                    constructorToken,
                    "success=false,error=${error.javaClass.simpleName}",
                )
                throw error
            }

            val channelsToken = MonitoringPerfProbe.begin("flutter_engine_channels")
            try {
                NativeBridgeChannels.registerEventChannels(this, engine)
                NativeBridgeChannels.installBackgroundMethodHandler(this, engine)
            } finally {
                MonitoringPerfProbe.end(channelsToken)
            }

            val dartToken = MonitoringPerfProbe.begin("flutter_dart_entrypoint_request")
            try {
                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault(),
                )
            } finally {
                MonitoringPerfProbe.end(dartToken)
            }
            monitoringFlutterEngine = engine
            totalOutcome = "success=true,warm=false"
            return engine
        } catch (error: Throwable) {
            totalOutcome = "success=false,error=${error.javaClass.simpleName}"
            throw error
        } finally {
            MonitoringPerfProbe.end(totalToken, totalOutcome)
        }
    }

    fun existingFlutterEngine(): FlutterEngine? = monitoringFlutterEngine

    private fun createNotificationChannels() {
        val manager = getSystemService(NotificationManager::class.java)

        val monitoringChannel = NotificationChannel(
            BACKGROUND_MONITORING_CHANNEL_ID,
            "Giám sát cuộc gọi",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Thông báo khi đang giám sát cuộc gọi"

            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        createOrRepairChannel(
            manager,
            monitoringChannel,
            expectedImportance = NotificationManager.IMPORTANCE_LOW,
            expectedLockscreenVisibility = Notification.VISIBILITY_PUBLIC,
        )

        val incomingCallChannel = NotificationChannel(
            INCOMING_CALL_CHANNEL_ID,
            "Phát hiện cuộc gọi",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Yêu cầu giám sát cuộc gọi"
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        createOrRepairChannel(
            manager,
            incomingCallChannel,
            expectedImportance = NotificationManager.IMPORTANCE_HIGH,
            expectedVibration = true,
            expectedLockscreenVisibility = Notification.VISIBILITY_PUBLIC,
        )

        val mediaProjectionChannel = NotificationChannel(
            MEDIA_PROJECTION_CHANNEL_ID,
            "Media Projection Service",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Creator Mode ghi âm"
        }
        createOrRepairChannel(
            manager,
            mediaProjectionChannel,
            expectedImportance = NotificationManager.IMPORTANCE_HIGH,
        )
    }

    private fun createOrRepairChannel(
        manager: NotificationManager,
        channel: NotificationChannel,
        expectedImportance: Int,
        expectedVibration: Boolean? = null,
        expectedLockscreenVisibility: Int? = null,
    ) {
        val existing = manager.getNotificationChannel(channel.id)
        if (existing != null &&
            shouldRepairChannel(
                existing,
                expectedImportance,
                expectedVibration,
                expectedLockscreenVisibility,
            )
        ) {
            manager.deleteNotificationChannel(channel.id)
        }
        manager.createNotificationChannel(channel)
    }

    private fun shouldRepairChannel(
        existing: NotificationChannel,
        expectedImportance: Int,
        expectedVibration: Boolean?,
        expectedLockscreenVisibility: Int?,
    ): Boolean {
        if (existing.importance == NotificationManager.IMPORTANCE_UNSPECIFIED) {
            return true
        }
        if (existing.importance != expectedImportance) {
            return true
        }
        if (expectedVibration != null && existing.shouldVibrate() != expectedVibration) {
            return true
        }
        if (expectedLockscreenVisibility != null &&
            existing.lockscreenVisibility != expectedLockscreenVisibility &&
            !(expectedLockscreenVisibility == Notification.VISIBILITY_PUBLIC &&
                existing.lockscreenVisibility == LOCKSCREEN_VISIBILITY_NO_OVERRIDE)
        ) {
            return true
        }
        return false
    }
}

