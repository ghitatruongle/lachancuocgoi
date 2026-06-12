package com.example.lachancuocgoi.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import androidx.core.app.NotificationCompat
import com.example.lachancuocgoi.MainActivity
import com.example.lachancuocgoi.R
import com.example.lachancuocgoi.services.BackgroundMonitoringService
import com.example.lachancuocgoi.services.UnifiedAccessibilityService

class CallReceiver : BroadcastReceiver() {
    private val TAG = "CallReceiver"
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "ACTION_DISMISS_NOTIFICATION") {
            Log.d(TAG, "Dismissing incoming call notification")
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(1001)
            return
        }

        if (intent.action == TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            @Suppress("DEPRECATION")
            val phoneNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
            
            Log.d(TAG, "Phone state changed: $state, number: $phoneNumber")
            
            if (state == TelephonyManager.EXTRA_STATE_RINGING) {
                Log.d(TAG, "Incoming call detected! Showing Notification")
                try {
                    showIncomingCallNotification(context, phoneNumber ?: "Số lạ")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to show notification", e)
                }
            }
        }
    }

    private fun showIncomingCallNotification(context: Context, callerInfo: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "IncomingCallChannel",
                "Phát hiện cuộc gọi",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Yêu cầu giám sát cuộc gọi"
                enableVibration(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }

        val monitorIntent = Intent(context, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
            putExtra("PHONE_NUMBER", callerInfo)
        }
        val monitorPendingIntent = PendingIntent.getService(context, 1, monitorIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val dismissIntent = Intent(context, CallReceiver::class.java).apply {
            action = "ACTION_DISMISS_NOTIFICATION"
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(context, 2, dismissIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("NAVIGATE_TO_MONITORING", true)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context, 0, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, "IncomingCallChannel")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Lá chắn cuộc gọi")
            .setContentText("Phát hiện $callerInfo. Bạn có muốn giám sát không?")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .addAction(R.drawable.ic_launcher_foreground, "Có, giám sát", monitorPendingIntent)
            .addAction(R.drawable.ic_launcher_foreground, "Không", dismissPendingIntent)
            .setOngoing(true)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(1001, notification)
    }
}
