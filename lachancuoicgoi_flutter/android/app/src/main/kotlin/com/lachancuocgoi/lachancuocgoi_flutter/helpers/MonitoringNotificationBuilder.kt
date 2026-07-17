package com.lachancuocgoi.lachancuocgoi_flutter.helpers

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.lachancuocgoi.lachancuocgoi_flutter.R

/**
 * Notification builder extracted from `BackgroundMonitoringService.kt` (Wave 3 refactor).
 *
 * Owns the foreground notification shown while call monitoring is active:
 * channel creation, the ongoing notification (with a Stop action), and re-posting
 * an updated body text. Stateless beyond the [Context] — all per-session state
 * (the running notification id, channel id, ...) lives in the companion object
 * of [BackgroundMonitoringService], which is the single source of truth for these
 * constants so the watchdog receiver reads them from one place.
 *
 * @param context a [Context] used to reach [NotificationManager]; typically the
 *                owning [android.app.Service].
 * @param serviceClass the concrete service class used to build the self-targeted
 *                     Stop [PendingIntent].
 */
class MonitoringNotificationBuilder(
    private val context: Context,
    private val serviceClass: Class<*>,
) {
    companion object {
        private const val TAG = "MonitoringNotificationBuilder"
    }

    /**
     * Create the low-importance notification channel exactly once. Safe to call
     * on every notification update — channel creation is idempotent.
     */
    fun ensureChannel(channelId: String, channelName: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            // NotificationManager handles duplicate channel creation internally.
            manager.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    channelName,
                    NotificationManager.IMPORTANCE_LOW,
                )
            )
        }
    }

    /**
     * Build the ongoing monitoring notification with a Stop action.
     */
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

    /**
     * Re-post the notification with an updated body text. Silently logs failures
     * so a transient notification-manager issue can never crash the service loop.
     */
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
