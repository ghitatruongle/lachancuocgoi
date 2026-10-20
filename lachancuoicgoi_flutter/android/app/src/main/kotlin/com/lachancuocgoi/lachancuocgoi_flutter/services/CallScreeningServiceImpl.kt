package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.content.Intent
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.Q)
class CallScreeningServiceImpl : CallScreeningService() {

    companion object {
        private const val TAG = "CallScreeningSvc"
        const val PREFS_NAME = CallScreeningPreferences.PREFS_NAME
        const val KEY_BLOCK_ENABLED = CallScreeningPreferences.KEY_BLOCK_ENABLED
        const val KEY_BLOCKED_NUMBERS = CallScreeningPreferences.KEY_BLOCKED_NUMBERS

        fun normalizePhoneNumber(raw: String): String {
            return raw.filter { it.isDigit() }
        }

        fun takeLast4(raw: String): String {
            val digits = normalizePhoneNumber(raw)
            return if (digits.length <= 4) digits else digits.takeLast(4)
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun onScreenCall(callDetails: Call.Details) {
        val rawPhoneNumber = callDetails.handle?.schemeSpecificPart ?: return

        val phoneNumber = normalizePhoneNumber(rawPhoneNumber)

        Log.d(TAG, "onScreenCall: ...${takeLast4(rawPhoneNumber)}")

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val blockEnabled = prefs.getBoolean(KEY_BLOCK_ENABLED, false)
        if (blockEnabled) {
            val blockedNumbersRaw = prefs.getStringSet(KEY_BLOCKED_NUMBERS, emptySet()) ?: emptySet()

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
                    NativeCallEvent.create(
                        type = "SCREENING_BLOCKED",
                        reason = "native_blocklist_match",
                        rawNumber = phoneNumber,
                    ).toMap()
                )
                return
            }
        }

        val serviceIntent = Intent(this, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
        }

        val launched = if (android.provider.Settings.canDrawOverlays(this)) {

            launchTrampoline(serviceIntent)
        } else {

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

            NativeBridgeEventSink.sendCallEvent(
                NativeCallEvent.create(
                    type = "SCREENING_FAILED",
                    reason = "service_start_failed",
                    rawNumber = phoneNumber,
                ).toMap()
            )
        } else {

            NativeBridgeEventSink.sendCallEvent(
                NativeCallEvent.create(
                    type = "SCREENING",
                    reason = "incoming_call_screened",
                    rawNumber = phoneNumber,
                ).toMap()
            )
        }

        try {
            val response = CallResponse.Builder().build()
            respondToCall(callDetails, response)
        } catch (e: Exception) {
            Log.w(TAG, "respondToCall failed", e)
        }
    }

    private fun launchTrampoline(serviceIntent: Intent): Boolean {
        val activityIntent = Intent(this, TransparentTrampolineActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("SERVICE_INTENT", serviceIntent)
        }
        try {
            startActivity(activityIntent)
            return true
        } catch (e: Exception) {
            Log.w(TAG, "startActivity(trampoline) failed — falling back to direct service start", e)
            return ForegroundServiceLauncher.safeStartForegroundService(this, serviceIntent) ==
                ForegroundServiceLauncher.LaunchResult.SUCCESS
        }
    }
}

