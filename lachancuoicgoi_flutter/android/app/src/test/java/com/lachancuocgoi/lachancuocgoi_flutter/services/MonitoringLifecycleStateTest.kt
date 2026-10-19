package com.lachancuocgoi.lachancuocgoi_flutter.services

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MonitoringLifecycleStateTest {
    @Test
    fun happyPathStartStop() {
        val s = MonitoringLifecycleState()
        s.onServiceCreated()
        s.onForegroundPromoted()
        assertTrue(s.onMonitoringStarted())
        assertTrue(s.isMonitoringActive)
        assertEquals(MonitoringLifecyclePhase.MONITORING_ACTIVE, s.phase)
        s.onMonitoringStopped()
        assertFalse(s.isMonitoringActive)
        assertEquals(MonitoringLifecyclePhase.FOREGROUND_READY, s.phase)
    }

    @Test
    fun destroyedBlocksStart() {
        val s = MonitoringLifecycleState()
        s.onDestroyed()
        assertFalse(s.onMonitoringStarted())
        assertFalse(s.canStartMonitoring())
    }
}
