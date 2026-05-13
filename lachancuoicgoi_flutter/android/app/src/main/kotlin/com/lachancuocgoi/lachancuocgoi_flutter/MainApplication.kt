package com.lachancuocgoi.lachancuocgoi_flutter

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            // Monitoring channel (low priority - persistent)
            val monitoringChannel = NotificationChannel(
                "BackgroundMonitoringChannel",
                "Giám sát cuộc gọi",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Thông báo khi đang giám sát cuộc gọi"
            }
            manager.createNotificationChannel(monitoringChannel)

            // Incoming call channel (high priority - alert)
            val incomingCallChannel = NotificationChannel(
                "IncomingCallChannel",
                "Phát hiện cuộc gọi",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Yêu cầu giám sát cuộc gọi"
                enableVibration(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(incomingCallChannel)

            // Media projection channel
            val mediaProjectionChannel = NotificationChannel(
                "media_projection_channel",
                "Media Projection Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Creator Mode ghi âm"
            }
            manager.createNotificationChannel(mediaProjectionChannel)
        }
    }
}
