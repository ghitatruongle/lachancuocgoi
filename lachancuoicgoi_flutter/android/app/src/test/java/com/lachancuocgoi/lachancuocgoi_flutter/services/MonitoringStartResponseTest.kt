package com.lachancuocgoi.lachancuocgoi_flutter.services

import org.junit.Assert.assertEquals
import org.junit.Test

class MonitoringStartResponseTest {

    @Test
    fun `all start statuses use the Flutter wire values`() {
        assertEquals("started", MonitoringStartStatus.STARTED.wireValue)
        assertEquals("alreadyRunning", MonitoringStartStatus.ALREADY_RUNNING.wireValue)
        assertEquals("permissionDenied", MonitoringStartStatus.PERMISSION_DENIED.wireValue)
        assertEquals("backgroundStartDenied", MonitoringStartStatus.BACKGROUND_START_DENIED.wireValue)
        assertEquals("nativeFailure", MonitoringStartStatus.NATIVE_FAILURE.wireValue)
    }

    @Test
    fun `response map has status and message keys`() {
        val result = MonitoringStartResponse(
            MonitoringStartStatus.STARTED,
            "ok",
        ).toMap()

        assertEquals(mapOf("status" to "started", "message" to "ok"), result)
    }
}
