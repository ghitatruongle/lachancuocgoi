package com.lachancuocgoi.lachancuocgoi_flutter.services

enum class MonitoringLifecyclePhase {
    CREATED,
    FOREGROUND_READY,
    MONITORING_ACTIVE,
    STOPPING,
    DESTROYED,
}

class MonitoringLifecycleState {
    var phase: MonitoringLifecyclePhase = MonitoringLifecyclePhase.CREATED
        private set

    var isMonitoringActive: Boolean = false
        private set

    fun onServiceCreated() {
        phase = MonitoringLifecyclePhase.CREATED
        isMonitoringActive = false
    }

    fun onForegroundPromoted() {
        if (phase == MonitoringLifecyclePhase.DESTROYED) return
        phase = MonitoringLifecyclePhase.FOREGROUND_READY
    }

    fun onMonitoringStarted(): Boolean {
        if (phase == MonitoringLifecyclePhase.DESTROYED) return false
        phase = MonitoringLifecyclePhase.MONITORING_ACTIVE
        isMonitoringActive = true
        return true
    }

    fun onMonitoringStopped() {
        if (phase == MonitoringLifecyclePhase.DESTROYED) return
        isMonitoringActive = false
        phase = MonitoringLifecyclePhase.FOREGROUND_READY
    }

    fun onStopping() {
        phase = MonitoringLifecyclePhase.STOPPING
        isMonitoringActive = false
    }

    fun onDestroyed() {
        phase = MonitoringLifecyclePhase.DESTROYED
        isMonitoringActive = false
    }

    fun canStartMonitoring(): Boolean =
        phase == MonitoringLifecyclePhase.FOREGROUND_READY ||
            phase == MonitoringLifecyclePhase.CREATED ||
            phase == MonitoringLifecyclePhase.MONITORING_ACTIVE
}

