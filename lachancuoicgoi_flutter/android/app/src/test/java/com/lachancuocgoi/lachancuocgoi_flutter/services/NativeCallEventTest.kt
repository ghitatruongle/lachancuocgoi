package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NativeCallEventTest {

    @Test
    fun `activity intent parser exposes only masked number`() {
        val intent = Intent().apply {
            putExtra("NAVIGATE_TO_MONITORING", true)
            putExtra("PHONE_NUMBER", "+84 912 345 678")
            putExtra("CALL_EVENT_REASON", "test_navigation")
            putExtra("CALL_EVENT_TIMESTAMP_MS", 1234L)
        }

        val payload = requireNotNull(NativeCallEvent.fromActivityIntent(intent)).toMap()

        assertEquals("NAVIGATE_TO_MONITORING", payload["type"])
        assertEquals(1234L, payload["timestampMs"])
        assertEquals("test_navigation", payload["reason"])
        assertEquals(true, payload["numberAvailable"])
        assertEquals("••••5678", payload["maskedNumber"])
        assertFalse(payload.containsKey("phoneNumber"))
    }

    @Test
    fun `activity intent without navigation extra is ignored`() {
        assertNull(NativeCallEvent.fromActivityIntent(Intent()))
    }

    @Test
    fun `maskPhoneNumber never exposes more than final four digits`() {
        assertEquals("••••5678", NativeCallEvent.maskPhoneNumber("+84912345678"))
        assertEquals("••••12", NativeCallEvent.maskPhoneNumber("12"))
        assertNull(NativeCallEvent.maskPhoneNumber("unknown"))
    }
}
