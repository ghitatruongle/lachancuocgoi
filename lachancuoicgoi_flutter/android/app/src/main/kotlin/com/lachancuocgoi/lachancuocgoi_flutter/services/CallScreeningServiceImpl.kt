package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.content.Intent
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * CallScreeningService that runs in the background every time the system
 * delivers an incoming call.
 *
 * Bug #2 fix: the previous implementation called `startForegroundService()`
 * directly from `onScreenCall`. On Android 12+, when the call screening
 * service runs while the app is not in the foreground, the system throws
 * `ForegroundServiceStartNotAllowedException` and the process crashes.
 *
 * The fix routes through `ForegroundServiceLauncher.safeStartForegroundService`
 * which catches the exception and falls back to `startService`. The
 * trampoline-activity path is also wrapped so an `ActivityNotFoundException`
 * (extremely unlikely but possible on weird OEMs) doesn't crash either.
 *
 * Note: this service itself IS a foreground-allowed context (call screening
 * is one of the exempted FGS-start contexts per Android 12+), so the
 * exception shouldn't normally fire here. However, OEMs occasionally
 * enforce stricter background restrictions than stock Android, hence the
 * defensive try/catch.
 */
@RequiresApi(Build.VERSION_CODES.Q)
class CallScreeningServiceImpl : CallScreeningService() {

    companion object {
        private const val TAG = "CallScreeningSvc"
        const val PREFS_NAME = "call_screening_prefs"
        const val KEY_BLOCK_ENABLED = "CALL_SCREENING_BLOCK_ENABLED"
        const val KEY_BLOCKED_NUMBERS = "blocked_numbers"

        /**
         * BUG 4 fix: Normalize a phone number to digits-only so that
         * "+84 912 345 678", "0912345678", and "84912345678" all match.
         */
        fun normalizePhoneNumber(raw: String): String {
            return raw.filter { it.isDigit() }
        }

        /**
         * BUG 3 fix: Redact to last 4 digits for logging, avoiding PII leak.
         */
        fun takeLast4(raw: String): String {
            val digits = normalizePhoneNumber(raw)
            return if (digits.length <= 4) digits else digits.takeLast(4)
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun onScreenCall(callDetails: Call.Details) {
        val rawPhoneNumber = callDetails.handle?.schemeSpecificPart ?: return
        // BUG 4 fix: normalize to digits-only so +84 912... matches 0912...
        val phoneNumber = normalizePhoneNumber(rawPhoneNumber)
        // BUG 3 fix: only log last 4 digits to avoid PII leak via logcat.
        Log.d(TAG, "onScreenCall: ...${takeLast4(rawPhoneNumber)}")

        // Phase 2 (P2-4): opt-in call screening — reject calls from blocklist.
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val blockEnabled = prefs.getBoolean(KEY_BLOCK_ENABLED, false)
        if (blockEnabled) {
            val blockedNumbersRaw = prefs.getStringSet(KEY_BLOCKED_NUMBERS, emptySet()) ?: emptySet()
            // Normalize the stored numbers too, so comparison is consistent.
            val blockedNumbers = blockedNumbersRaw.map { normalizePhoneNumber(it) }.toSet()
            if (phoneNumber in blockedNumbers) {
                Log.w(TAG, "Blocking call from ...${takeLast4(rawPhoneNumber)} (in blocklist)")
                try {
                    val response = CallResponse.Builder()
                        .setDisallowCall(true)
                        .setRejectCall(true)
                        .build()
                    respondToCall(callDetails, response)
                } catch (e: Exception) {
                    Log.w(TAG, "respondToCall (block) failed", e)
                }
                NativeBridgeEventSink.sendCallEvent(
                    mapOf("type" to "SCREENING_BLOCKED", "phoneNumber" to phoneNumber)
                )
                return
            }
        }

        val serviceIntent = Intent(this, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
            putExtra("PHONE_NUMBER", phoneNumber)
        }

        // Bug #2 fix: always go through safe launcher so we never crash on
        // Android 12+ even if the OEM blocks background FGS in this context.
        val launched = if (android.provider.Settings.canDrawOverlays(this)) {
            // Android 14 compliance: Start a visible activity first, then the
            // trampoline launches the foreground service.
            launchTrampoline(serviceIntent)
            true
        } else {
            // No overlay permission: try foreground service directly.
            // On Android 12+, if the app is not in a foreground-allowed
            // context, this will return NOT_ALLOWED. We do NOT fall back
            // to startService() — that would create a zombie service killed
            // within 5s. Instead, we surface the failure to Flutter.
            val result = ForegroundServiceLauncher.safeStartForegroundService(
                this,
                serviceIntent,
            )
            when (result) {
                ForegroundServiceLauncher.LaunchResult.SUCCESS -> true
                else -> {
                    Log.w(TAG, "Failed to start monitoring service from call screening: $result")
                    false
                }
            }
        }

        if (!launched) {
            // Notify Flutter so the UI can surface a "monitoring didn't start"
            // state instead of silently failing.
            NativeBridgeEventSink.sendCallEvent(
                mapOf(
                    "type" to "SCREENING_FAILED",
                    "phoneNumber" to phoneNumber,
                    "reason" to "service_start_failed",
                )
            )
        } else {
            // Notify Flutter about incoming call.
            NativeBridgeEventSink.sendCallEvent(
                mapOf(
                    "type" to "SCREENING",
                    "phoneNumber" to phoneNumber,
                )
            )
        }

        // Bug #46 fix: respondToCall is API 29+ — already guarded by
        // @RequiresApi(Q) but be defensive in case reflection loads us at
        // lower API.
        try {
            val response = CallResponse.Builder().build()
            respondToCall(callDetails, response)
        } catch (e: Exception) {
            Log.w(TAG, "respondToCall failed", e)
        }
    }

    /**
     * Start the [TransparentTrampolineActivity] which in turn launches the
     * foreground service. Wrapped to never throw — if the activity can't be
     * started (e.g. ActivityNotFoundException on a weird OEM), fall back to
     * starting the service directly.
     */
    private fun launchTrampoline(serviceIntent: Intent) {
        val activityIntent = Intent(this, TransparentTrampolineActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("SERVICE_INTENT", serviceIntent)
        }
        try {
            startActivity(activityIntent)
        } catch (e: Exception) {
            Log.w(TAG, "startActivity(trampoline) failed — falling back to direct service start", e)
            ForegroundServiceLauncher.safeStartForegroundService(this, serviceIntent)
        }
    }
}
