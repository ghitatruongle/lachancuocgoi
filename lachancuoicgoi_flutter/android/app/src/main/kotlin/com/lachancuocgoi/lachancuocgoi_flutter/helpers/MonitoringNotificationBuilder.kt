package com.lachancuocgoi.lachancuocgoi_flutter.helpers

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import com.lachancuocgoi.lachancuocgoi_flutter.R

class MonitoringNotificationBuilder(
    private val context: Context,
    private val serviceClass: Class<*>,
) {
    companion object {
        private const val TAG = "MonitoringNotificationBuilder"
    }

    fun ensureChannel(channelId: String, channelName: String) {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        manager.createNotificationChannel(
            NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_LOW,
            )
        )
    }

    fun build(channelId: String, actionStop: String, text: String): android.app.Notification {
        val stopIntent = Intent(context, serviceClass).apply { action = actionStop }
        val stopPendingIntent =
            PendingIntent.getService(context, 0, stopIntent, PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(context, channelId)
            .setContentTitle("Lá chắn cuộc gọi")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .addAction(0, "Dừng", stopPendingIntent)
            .build()
    }

    fun update(channelId: String, actionStop: String, notificationId: Int, text: String) {
        try {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(notificationId, build(channelId, actionStop, text))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update monitoring notification", e)
        }
    }
}

