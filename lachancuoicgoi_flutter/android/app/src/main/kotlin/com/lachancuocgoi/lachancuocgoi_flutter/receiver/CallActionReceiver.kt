package com.lachancuocgoi.lachancuocgoi_flutter.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.lachancuocgoi.lachancuocgoi_flutter.services.CallSessionCoordinator

/** Handles the explicit actions from the incoming-call prompt and overlay. */
class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
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
    }
}
