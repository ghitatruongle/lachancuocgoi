package com.lachancuocgoi.lachancuocgoi_flutter.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.lachancuocgoi.lachancuocgoi_flutter.diagnostics.MonitoringPerfProbe
import com.lachancuocgoi.lachancuocgoi_flutter.services.CallSessionCoordinator

class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val token = MonitoringPerfProbe.begin(
            "call_action_receiver",
            "action=${intent.action.orEmpty()}",
        )
        try {
            when (intent.action) {
                CallSessionCoordinator.ACTION_ACCEPT ->
                    CallSessionCoordinator.acceptMonitoring(
                        context.applicationContext,
                        intent.getStringExtra(CallSessionCoordinator.EXTRA_SESSION_ID),
                    )

                CallSessionCoordinator.ACTION_DECLINE ->
                    CallSessionCoordinator.declineMonitoring(
                        context.applicationContext,
                        intent.getStringExtra(CallSessionCoordinator.EXTRA_SESSION_ID),
                    )

                CallSessionCoordinator.ACTION_END ->
                    CallSessionCoordinator.endFromUser(context.applicationContext)
            }
        } finally {
            MonitoringPerfProbe.end(token)
        }
    }
}

