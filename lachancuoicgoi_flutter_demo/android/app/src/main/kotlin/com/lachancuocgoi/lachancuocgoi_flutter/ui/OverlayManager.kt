package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.content.Context

/**
 * Facade OverlayManager for backward compatibility.
 * Delegates calls to specific overlay managers.
 */
object OverlayManager {

    fun showRedAlert(context: Context, reason: String) {
        AlertOverlayManager.showRedAlert(context, reason)
    }

    fun showOrangeAlert(context: Context, reason: String) {
        AlertOverlayManager.showOrangeAlert(context, reason)
    }

    fun removeAlertOverlay(context: Context) {
        AlertOverlayManager.removeAlertOverlay(context)
    }

    fun showIncomingCallOverlay(context: Context, callerInfo: String) {
        IncomingCallOverlayManager.showIncomingCallOverlay(context, callerInfo)
    }

    fun removeIncomingCallOverlay(context: Context) {
        IncomingCallOverlayManager.removeIncomingCallOverlay(context)
    }

    fun showMonitoringOverlay(context: Context) {
        MonitoringOverlayManager.showMonitoringOverlay(context)
    }

    fun hideMonitoringOverlay(context: Context) {
        MonitoringOverlayManager.hideMonitoringOverlay(context)
    }

    fun removeAll(context: Context) {
        removeAlertOverlay(context)
        hideMonitoringOverlay(context)
        removeIncomingCallOverlay(context)
    }
}
