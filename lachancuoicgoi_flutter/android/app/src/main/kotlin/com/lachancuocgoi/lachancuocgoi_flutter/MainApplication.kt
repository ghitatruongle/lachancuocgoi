package com.lachancuocgoi.lachancuocgoi_flutter

import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class MainApplication : Application() {

    companion object {
        const val BACKGROUND_MONITORING_CHANNEL_ID = "BackgroundMonitoringChannel"
        const val INCOMING_CALL_CHANNEL_ID = "IncomingCallChannel"
        const val MEDIA_PROJECTION_CHANNEL_ID = "media_projection_channel"
        private const val LOCKSCREEN_VISIBILITY_NO_OVERRIDE = -1000
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java)

        val monitoringChannel = NotificationChannel(
            BACKGROUND_MONITORING_CHANNEL_ID,
            "Giám sát cuộc gọi",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Thông báo khi đang giám sát cuộc gọi"
        }
        createOrRepairChannel(
            manager,
            monitoringChannel,
            expectedImportance = NotificationManager.IMPORTANCE_LOW,
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
