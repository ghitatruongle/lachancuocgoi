package com.lachancuocgoi.lachancuocgoi_flutter.receiver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.lachancuocgoi.lachancuocgoi_flutter.MainActivity
import com.lachancuocgoi.lachancuocgoi_flutter.R
import com.lachancuocgoi.lachancuocgoi_flutter.services.BackgroundMonitoringService
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeBridgeEventSink

/**
 * Listens for `PHONE_STATE` broadcasts and shows an "incoming call detected"
 * notification.
 *
 * Bug #6 fix: on Android 13+ (`Build.VERSION_CODES.TIRAMISU`) the
 * `EXTRA_INCOMING_NUMBER` extra is often `null` because the system strips it
 * for privacy unless the app is the default dialer or holds `READ_PHONE_NUMBERS`.
 * The previous code fell back to a hard-coded `"Số lạ"` (unknown number)
 * label, which was indistinguishable from a legitimate unknown caller.
 *
 * The fix:
 *  1. Explicitly distinguish `null` (system didn't deliver the number, often
 *     due to privacy) from a real unknown caller by tagging the event with
 *     `numberAvailable=false`.
 *  2. Still display "Số lạ" in the UI so the user gets a usable label, but
 *     Flutter side can now check the flag and prompt the user to manually
 *     enter the number if needed.
 *  3. Document that the real fix is for the user to grant the
 *     `READ_PHONE_NUMBERS` permission via Settings.
 */
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
            // Bug #6 fix: on Android 13+ (API 33) the EXTRA_INCOMING_NUMBER is
            // often null because the system hides the number from non-default
            // dialer apps. We now distinguish between:
            //   - phoneNumber == null  → system stripped it (numberAvailable = false)
            //   - phoneNumber == ""    → genuinely empty (shouldn't happen but defensive)
            //   - phoneNumber == "Số lạ" (literal) → never set; we always emit either the
            //                                          real number or the placeholder.
            @Suppress("DEPRECATION")
            val phoneNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
            val numberAvailable = !phoneNumber.isNullOrBlank()
            val displayNumber = phoneNumber?.takeIf { it.isNotBlank() } ?: "Số lạ"

            Log.d(TAG, "Phone state changed: $state, number: $phoneNumber, available: $numberAvailable")

            if (state == TelephonyManager.EXTRA_STATE_RINGING) {
                Log.d(TAG, "Incoming call detected! Showing Notification (numberAvailable=$numberAvailable)")
                try {
                    showIncomingCallNotification(context, displayNumber)
                    // Bug #6 fix: emit numberAvailable flag so Flutter can decide
                    // whether to ask the user for the number manually.
                    NativeBridgeEventSink.sendCallEvent(
                        mapOf(
                            "type" to "RINGING",
                            "phoneNumber" to displayNumber,
                            "numberAvailable" to numberAvailable,
                        )
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to show notification", e)
                }
            } else if (state == TelephonyManager.EXTRA_STATE_IDLE) {
                NativeBridgeEventSink.sendCallEvent(
                    mapOf(
                        "type" to "IDLE",
                        "numberAvailable" to numberAvailable,
                    )
                )
            } else if (state == TelephonyManager.EXTRA_STATE_OFFHOOK) {
                NativeBridgeEventSink.sendCallEvent(
                    mapOf(
                        "type" to "OFFHOOK",
                        "numberAvailable" to numberAvailable,
                    )
                )
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
            putExtra("NAVIGATE_TO_MONITORING", true) // Bug #5: forward to MainActivity.onNewIntent
            putExtra("PHONE_NUMBER", callerInfo)
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
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .addAction(R.mipmap.ic_launcher, "Có, giám sát", monitorPendingIntent)
            .addAction(R.mipmap.ic_launcher, "Không", dismissPendingIntent)
            .setOngoing(true)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(1001, notification)
    }
}
