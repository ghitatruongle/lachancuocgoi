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

    fun showMonitoringOverlay(
        context: Context,
        startedAtMs: Long = System.currentTimeMillis(),
    ): Boolean = MonitoringOverlayManager.showMonitoringOverlay(context, startedAtMs)

    fun updateMonitoringRms(rms: Float) = MonitoringOverlayManager.updateRms(rms)

    fun hideMonitoringOverlay(context: Context) {
        MonitoringOverlayManager.hideMonitoringOverlay()
    }

    fun removeAll(context: Context) {
        removeAlertOverlay(context)
        hideMonitoringOverlay(context)
    }
}
