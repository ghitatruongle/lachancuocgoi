package com.lachancuocgoi.lachancuocgoi_flutter.services.stt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for [SttState] sealed class (Wave 4).
 *
 * Wave 2 refactor extracted SttState from SpeechToTextManager.
 */
class SttStateTest {

    @Test
    fun `Idle is singleton`() {
        val state1 = SttState.Idle
        val state2 = SttState.Idle
        assertEquals(state1, state2)
    }

    @Test
    fun `Listening is singleton`() {
        assertEquals(SttState.Listening, SttState.Listening)
    }

    @Test
    fun `Stopped is singleton`() {
        assertEquals(SttState.Stopped, SttState.Stopped)
    }

    @Test
    fun `Error carries message and recoverable flag`() {
        val error1 = SttState.Error("network failure", true)
        val error2 = SttState.Error("network failure", true)
        val error3 = SttState.Error("network failure", false)

        assertEquals(error1, error2)
        assertEquals("network failure", error1.message)
        assertTrue(error1.recoverable)
        assertNotEquals(error1, error3)
        assertEquals(error1.hashCode(), error2.hashCode())
    }

    @Test
    fun `Error equality based on both fields`() {
        val err1 = SttState.Error("msg1", true)
        val err2 = SttState.Error("msg2", true)
        assertTrue(err1 != err2)

        val err3 = SttState.Error("msg1", false)
        assertTrue(err1 != err3)
    }

}
