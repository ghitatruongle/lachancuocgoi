package com.lachancuocgoi.lachancuocgoi_flutter.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.util.Log
import com.lachancuocgoi.lachancuocgoi_flutter.services.CallSessionCoordinator
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeBridgeEventSink
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeCallEvent

/** PHONE_STATE adapter. Session de-duplication lives in [CallSessionCoordinator]. */
class CallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
        @Suppress("DEPRECATION")
        val phoneNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        val numberAvailable = !phoneNumber.isNullOrBlank()
        val maskedNumber = NativeCallEvent.maskPhoneNumber(phoneNumber)
        Log.d(TAG, "Phone state changed: $state, number available: $numberAvailable")

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING ->
                CallSessionCoordinator.onIncomingCall(
                    context = context,
                    source = CallSessionCoordinator.SYSTEM_CALL_SOURCE,
                    maskedNumber = maskedNumber,
                    numberAvailable = numberAvailable,
                    reason = "phone_state_ringing",
                )

            TelephonyManager.EXTRA_STATE_OFFHOOK ->
                NativeBridgeEventSink.sendCallEvent(
                    NativeCallEvent.create(
                        type = "OFFHOOK",
                        reason = "phone_state_offhook",
                        rawNumber = phoneNumber,
                        numberAvailable = numberAvailable,
                    ).toMap()
                )

            TelephonyManager.EXTRA_STATE_IDLE -> {
                NativeBridgeEventSink.sendCallEvent(
                    NativeCallEvent.create(
                        type = "IDLE",
                        reason = "phone_state_idle",
                        rawNumber = phoneNumber,
                        numberAvailable = numberAvailable,
                    ).toMap()
                )
                CallSessionCoordinator.onCallEnded(context, "phone_state_idle")
            }
        }
    }

    private companion object {
        const val TAG = "CallReceiver"
    }
}
