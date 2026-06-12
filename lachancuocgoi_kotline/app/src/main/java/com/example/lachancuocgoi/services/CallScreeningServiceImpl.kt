package com.example.lachancuocgoi.services

import android.content.Intent
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.widget.Toast
import androidx.annotation.RequiresApi
import com.example.lachancuocgoi.MainActivity

@RequiresApi(Build.VERSION_CODES.Q)
class CallScreeningServiceImpl : CallScreeningService() {

    override fun onScreenCall(callDetails: Call.Details) {
        val phoneNumber = callDetails.handle?.schemeSpecificPart ?: return
        
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
            // Fallback for when permission is missing (might fail on Android 14 if in background)
            // But we try anyway or rely on user to open app.
            // Note: Cannot show Toast from background easily here without Looper.
            try {
                startForegroundService(serviceIntent)
            } catch (e: Exception) {
                // Log failure - likely due to background start restrictions
            }
        }

        val response = CallResponse.Builder().build()
        respondToCall(callDetails, response)
    }
}
