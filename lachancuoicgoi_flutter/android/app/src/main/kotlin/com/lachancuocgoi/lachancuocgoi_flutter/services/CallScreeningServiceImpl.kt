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
    }

    override fun onScreenCall(callDetails: Call.Details) {
        val phoneNumber = callDetails.handle?.schemeSpecificPart ?: return
        Log.d(TAG, "onScreenCall: $phoneNumber")

        val serviceIntent = Intent(this, BackgroundMonitoringService::class.java).apply {
            action = BackgroundMonitoringService.ACTION_START
            putExtra("PHONE_NUMBER", phoneNumber)
        }

        if (android.provider.Settings.canDrawOverlays(this)) {
            // Android 14 compliance: Start a visible activity first
            val activityIntent = Intent(this, TransparentTrampolineActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra("SERVICE_INTENT", serviceIntent)
            }
            startActivity(activityIntent)
        } else {
            // Fallback when overlay permission is missing
            try {
                startForegroundService(serviceIntent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start monitoring from call screening", e)
            }
        }

        // Notify Flutter about incoming call
        NativeBridgeEventSink.sendCallEvent(mapOf(
            "type" to "SCREENING",
            "phoneNumber" to phoneNumber
        ))

        val response = CallResponse.Builder().build()
        respondToCall(callDetails, response)
    }
}
