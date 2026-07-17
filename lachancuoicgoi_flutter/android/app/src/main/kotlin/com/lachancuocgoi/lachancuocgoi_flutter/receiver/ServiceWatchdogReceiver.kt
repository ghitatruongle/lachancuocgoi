package com.lachancuocgoi.lachancuocgoi_flutter.receiver

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.lachancuocgoi.lachancuocgoi_flutter.services.BackgroundMonitoringService
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeBridgeEventSink

/**
 * Watchdog receiver that periodically checks if [BackgroundMonitoringService]
 * is still running. If the service was killed by the system (e.g., memory pressure,
 * Android 12+ foreground service restrictions), this receiver will auto-restart it.
 *
 * Scheduled via AlarmManager from [BackgroundMonitoringService.scheduleWatchdogAlarm].
 */
class ServiceWatchdogReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_CHECK_SERVICE) return

        Log.d(TAG, "Watchdog check triggered.")

        // Check persisted state: was monitoring active before potential kill?
        if (!BackgroundMonitoringService.wasMonitoringActive(context)) {
            Log.d(TAG, "Monitoring was not active — no restart needed.")
            return
        }

        // Is the service already running? Use @Volatile static flag instead of
        // deprecated getRunningServices() which is unreliable on Android 13+.
        if (BackgroundMonitoringService.isRunning) {
            Log.d(TAG, "Service is alive, nothing to do.")
            return
        }

        // Sprint 2 (B1): throttle restart attempts. Without this, a
        // foreground-service-restriction kill → restart → kill loop will
        // hammer AlarmManager and the system within a second.
        val prefs = context.getSharedPreferences(
            BackgroundMonitoringService.WATCHDOG_PREFS,
            Context.MODE_PRIVATE,
        )
        val now = System.currentTimeMillis()
        val lastRestartAtMs = prefs.getLong(KEY_LAST_RESTART_AT_MS, 0L)
        if (now - lastRestartAtMs < RESTART_COOLDOWN_MS) {
            Log.w(TAG, "Watchdog restart throttled (last=${now - lastRestartAtMs}ms ago).")
            return
        }
        prefs.edit().putLong(KEY_LAST_RESTART_AT_MS, now).apply()

        // Service was active but is now dead → auto-restart
        Log.w(TAG, "Service was killed! Auto-restarting...")
        restartMonitoringService(context)

        // Notify Flutter that monitoring was restored.
        // Only send STARTED — do NOT send STOPPED which would trigger
        // endSession() in MonitoringController and kill the service again.
        NativeBridgeEventSink.sendMonitoringState("STARTED")
    }

    private fun restartMonitoringService(context: Context) {
        // Sprint 2 (B6): re-attach the last-known phone number and
        // speakerphone flag so the restarted service resumes the
        // original session instead of starting with no context.
        val (phoneNumber, enableSpeakerphone) =
            BackgroundMonitoringService.lastStartParams(context)
        val intent = Intent(context, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
            if (phoneNumber != null) {
                putExtra("PHONE_NUMBER", phoneNumber)
            }
            putExtra("ENABLE_SPEAKERPHONE", enableSpeakerphone)
        }
        val launched = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                @Suppress("DEPRECATION")
                context.startService(intent)
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart monitoring service", e)
            NativeBridgeEventSink.sendMonitoringState("WATCHDOG_RESTART_FAILED")
            NativeBridgeEventSink.sendLog(
                TAG,
                "Watchdog restart failed: ${e.message}",
                "ERROR",
            )
            false
        }
        if (launched) {
            Log.i(TAG, "Auto-restart intent sent (phone=${phoneNumber != null}, spk=$enableSpeakerphone).")
        }
    }

    companion object {
        private const val TAG = "ServiceWatchdogRcvr"
        const val ACTION_CHECK_SERVICE =
            "com.lachancuocgoi.ACTION_CHECK_MONITORING_SERVICE"
        // Bug #25 fix: bumped from 60s → 4 minutes. The 60s cooldown was
        // shorter than the 5min alarm interval, so if the system fired
        // multiple watchdog alarms in quick succession (AlarmManager can
        // batch inexact alarms), the second/third were incorrectly
        // throttled and the service didn't restart when it should have.
        // 4 minutes (still under the 5min interval) preserves the
        // "throttle, don't kill" intent without losing real restarts.
        private const val RESTART_COOLDOWN_MS = 4 * 60_000L
        private const val KEY_LAST_RESTART_AT_MS = "watchdog_last_restart_at_ms"
    }
}
