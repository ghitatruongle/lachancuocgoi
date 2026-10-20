package com.lachancuocgoi.lachancuocgoi_flutter.receiver

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.SystemClock
import android.util.Log
import com.lachancuocgoi.lachancuocgoi_flutter.services.BackgroundMonitoringService
import com.lachancuocgoi.lachancuocgoi_flutter.services.ForegroundServiceLauncher
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeBridgeEventSink

class ServiceWatchdogReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_CHECK_SERVICE) return

        Log.d(TAG, "Watchdog check triggered.")

        if (!BackgroundMonitoringService.wasMonitoringActive(context)) {
            Log.d(TAG, "Monitoring was not active — no restart needed.")
            return
        }

        if (BackgroundMonitoringService.isRunning) {
            Log.d(TAG, "Service is alive, nothing to do.")
            return
        }

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

        Log.w(TAG, "Service was killed! Auto-restarting...")
        val restarted = restartMonitoringService(context)

        if (restarted) {
            NativeBridgeEventSink.sendMonitoringState("STARTED")
        }
    }

    private fun restartMonitoringService(context: Context): Boolean {

        val (_, enableSpeakerphone) = BackgroundMonitoringService.lastStartParams(context)
        val intent = Intent(context, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
            putExtra("ENABLE_SPEAKERPHONE", enableSpeakerphone)
        }
        val result = ForegroundServiceLauncher.safeStartForegroundService(context, intent)
        val launched = result == ForegroundServiceLauncher.LaunchResult.SUCCESS
        if (!launched) {
            Log.e(TAG, "Failed to restart monitoring service: $result")
            NativeBridgeEventSink.sendMonitoringState("WATCHDOG_RESTART_FAILED")
            NativeBridgeEventSink.sendLog(
                TAG,
                "Watchdog restart failed: $result",
                "ERROR",
            )
        }
        if (launched) {
            Log.i(TAG, "Auto-restart intent sent (spk=$enableSpeakerphone).")
        }
        return launched
    }

    companion object {
        private const val TAG = "ServiceWatchdogRcvr"
        const val ACTION_CHECK_SERVICE =
            "com.lachancuocgoi.ACTION_CHECK_MONITORING_SERVICE"

        private const val RESTART_COOLDOWN_MS = 4 * 60_000L
        private const val KEY_LAST_RESTART_AT_MS = "watchdog_last_restart_at_ms"
    }
}

