package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle

class TransparentTrampolineActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val serviceIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra("SERVICE_INTENT", Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra("SERVICE_INTENT") as? Intent
        }

        if (serviceIntent != null) {
            val result = ForegroundServiceLauncher.safeStartForegroundService(this, serviceIntent)
            if (result != ForegroundServiceLauncher.LaunchResult.SUCCESS) {
                NativeBridgeEventSink.sendMonitoringState("START_FAILED:backgroundStartDenied")
            }
        }

        finish()
    }
}

