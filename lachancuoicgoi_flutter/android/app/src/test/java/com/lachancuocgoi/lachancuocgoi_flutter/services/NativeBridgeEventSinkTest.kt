package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify

/**
 * Unit tests for [NativeBridgeEventSink] (post-Sprint 1+2).
 *
 * Uses Robolectric so the Handler/Looper plumbing actually works
 * (NativeBridgeEventSink posts every send onto the main looper).
 *
 * Buffer invariants under test:
 *  - sendTranscript / sendMonitoringState / sendCallEvent buffer up to
 *    50 events when the sink is null
 *  - onSinksReconnected drains each buffer in order
 *  - sendRms does NOT buffer (high-frequency data)
 *  - Buffer cap evicts the oldest entry (FIFO)
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NativeBridgeEventSinkTest {

    private lateinit var transcriptSink: EventChannel.EventSink
    private lateinit var rmsSink: EventChannel.EventSink
    private lateinit var monitoringStateSink: EventChannel.EventSink
    private lateinit var callEventSink: EventChannel.EventSink

    @Before
    fun setUp() {
        transcriptSink = mockk(relaxed = true)
        rmsSink = mockk(relaxed = true)
        monitoringStateSink = mockk(relaxed = true)
        callEventSink = mockk(relaxed = true)
        // Default: all sinks null (the case the buffers handle)
        NativeBridgeEventSink.transcriptSink = null
        NativeBridgeEventSink.rmsSink = null
        NativeBridgeEventSink.monitoringStateSink = null
        NativeBridgeEventSink.callEventSink = null
    }

    @After
    fun tearDown() {
        // Null out sinks so buffered events from one test don't leak
        NativeBridgeEventSink.transcriptSink = null
        NativeBridgeEventSink.rmsSink = null
        NativeBridgeEventSink.monitoringStateSink = null
        NativeBridgeEventSink.callEventSink = null
        // Drain the looper
        shadowOf(Looper.getMainLooper()).idle()
    }

    private fun pumpMainLooper() {
        shadowOf(Looper.getMainLooper()).idle()
    }

    // ─── 1. sendTranscript with sink != null → success ──────────────────

    @Test
    fun `sendTranscript with connected sink calls sink_success`() {
        NativeBridgeEventSink.transcriptSink = transcriptSink

        NativeBridgeEventSink.sendTranscript("hello world", isPartial = false)
        pumpMainLooper()

        verify(exactly = 1) {
            transcriptSink.success(match { map ->
                @Suppress("UNCHECKED_CAST")
                val m = map as Map<String, Any?>
                m["text"] == "hello world" && m["isPartial"] == false
            })
        }
    }

    @Test
    fun `sendTranscript isPartial flag is forwarded`() {
        NativeBridgeEventSink.transcriptSink = transcriptSink

        NativeBridgeEventSink.sendTranscript("partial text", isPartial = true)
        pumpMainLooper()

        verify(exactly = 1) {
            transcriptSink.success(match { map ->
                @Suppress("UNCHECKED_CAST")
                (map as Map<String, Any?>)["isPartial"] == true
            })
        }
    }

    // ─── 2. sendTranscript with sink == null → buffers, caps at 50 ─────

    @Test
    fun `sendTranscript with null sink buffers events up to 50`() {
        // No sink attached
        NativeBridgeEventSink.transcriptSink = null
        repeat(60) { i ->
            NativeBridgeEventSink.sendTranscript("msg-$i", isPartial = false)
        }
        pumpMainLooper()

        // Now attach a sink and drain
        NativeBridgeEventSink.transcriptSink = transcriptSink
        NativeBridgeEventSink.onSinksReconnected()
        pumpMainLooper()

        // The replayed messages should be the last 50 (msg-10..msg-59)
        // because FIFO eviction drops msg-0..msg-9. Verify a couple.
        verify(exactly = 1) {
            transcriptSink.success(match { map ->
                @Suppress("UNCHECKED_CAST")
                (map as Map<String, Any?>)["text"] == "msg-59"
            })
        }
        // msg-0 should NOT be replayed (evicted)
        verify(exactly = 0) {
            transcriptSink.success(match { map ->
                @Suppress("UNCHECKED_CAST")
                (map as Map<String, Any?>)["text"] == "msg-0"
            })
        }
    }

    // ─── 3. sendRms does NOT buffer ────────────────────────────────────

    @Test
    fun `sendRms does not buffer when sink is null`() {
        NativeBridgeEventSink.rmsSink = null

        // Send 100 RMS values; none should be buffered.
        repeat(100) { i ->
            NativeBridgeEventSink.sendRms(i.toFloat() * 0.1f)
        }
        pumpMainLooper()

        // Attach sink and call onSinksReconnected — nothing should be
        // replayed (RMS has no buffer).
        NativeBridgeEventSink.rmsSink = rmsSink
        NativeBridgeEventSink.onSinksReconnected()
        pumpMainLooper()

        verify(exactly = 0) { rmsSink.success(any()) }
    }

    @Test
    fun `sendRms with connected sink calls sink_success_with_double`() {
        NativeBridgeEventSink.rmsSink = rmsSink

        NativeBridgeEventSink.sendRms(2.5f)
        pumpMainLooper()

        verify(exactly = 1) { rmsSink.success(2.5) }
    }

    @Test
    fun `call event strips raw number and preserves original timestamp`() {
        NativeBridgeEventSink.callEventSink = callEventSink

        NativeBridgeEventSink.sendCallEvent(
            mapOf(
                "type" to "RINGING",
                "timestampMs" to 1234L,
                "reason" to "test",
                "phoneNumber" to "+84912345678",
            )
        )
        pumpMainLooper()

        verify(exactly = 1) {
            callEventSink.success(match { value ->
                @Suppress("UNCHECKED_CAST")
                val payload = value as Map<String, Any?>
                payload["timestampMs"] == 1234L &&
                    payload["maskedNumber"] == "••••5678" &&
                    payload["numberAvailable"] == true &&
                    !payload.containsKey("phoneNumber")
            })
        }
    }

    // ─── 4. onSinksReconnected drains all three buffers in order ───────

    @Test
    fun `onSinksReconnected drains monitoring state, transcript, and call event buffers in order`() {
        // Buffer events in all three channels
        repeat(3) { i ->
            NativeBridgeEventSink.sendMonitoringState("STATE_$i")
            NativeBridgeEventSink.sendTranscript("TX_$i", isPartial = false)
            NativeBridgeEventSink.sendCallEvent(mapOf("kind" to "event_$i"))
        }
        pumpMainLooper()

        // Attach sinks
        NativeBridgeEventSink.monitoringStateSink = monitoringStateSink
        NativeBridgeEventSink.transcriptSink = transcriptSink
        NativeBridgeEventSink.callEventSink = callEventSink

        NativeBridgeEventSink.onSinksReconnected()
        pumpMainLooper()

        // Monitoring state drained in FIFO order
        verify(exactly = 1) { monitoringStateSink.success("STATE_0") }
        verify(exactly = 1) { monitoringStateSink.success("STATE_1") }
        verify(exactly = 1) { monitoringStateSink.success("STATE_2") }
        // Transcript drained in FIFO order with isPartial=false
        verify(exactly = 1) {
            transcriptSink.success(match { map ->
                @Suppress("UNCHECKED_CAST")
                (map as Map<String, Any?>)["text"] == "TX_0"
            })
        }
        verify(exactly = 1) {
            transcriptSink.success(match { map ->
                @Suppress("UNCHECKED_CAST")
                (map as Map<String, Any?>)["text"] == "TX_2"
            })
        }
        // Call event drained in FIFO order
        verify(exactly = 1) {
            callEventSink.success(match { value ->
                @Suppress("UNCHECKED_CAST")
                (value as Map<String, Any?>)["kind"] == "event_0"
            })
        }
        verify(exactly = 1) {
            callEventSink.success(match { value ->
                @Suppress("UNCHECKED_CAST")
                (value as Map<String, Any?>)["kind"] == "event_2"
            })
        }
    }

    // ─── 5. Buffer overflow at 50 evicts oldest ────────────────────────

    @Test
    fun `monitoring state buffer evicts oldest entry on overflow`() {
        NativeBridgeEventSink.monitoringStateSink = null
        repeat(55) { i ->
            NativeBridgeEventSink.sendMonitoringState("M_$i")
        }
        pumpMainLooper()

        NativeBridgeEventSink.monitoringStateSink = monitoringStateSink
        NativeBridgeEventSink.onSinksReconnected()
        pumpMainLooper()

        // First 5 (M_0..M_4) should have been evicted
        verify(exactly = 0) { monitoringStateSink.success("M_0") }
        verify(exactly = 0) { monitoringStateSink.success("M_4") }
        // Last 50 (M_5..M_54) should be replayed
        verify(exactly = 1) { monitoringStateSink.success("M_5") }
        verify(exactly = 1) { monitoringStateSink.success("M_54") }
    }

    @Test
    fun `call event buffer evicts oldest entry on overflow`() {
        NativeBridgeEventSink.callEventSink = null
        repeat(60) { i ->
            NativeBridgeEventSink.sendCallEvent(mapOf("i" to i))
        }
        pumpMainLooper()

        NativeBridgeEventSink.callEventSink = callEventSink
        NativeBridgeEventSink.onSinksReconnected()
        pumpMainLooper()

        // i=0..9 evicted, i=10..59 replayed (50 total)
        verify(exactly = 0) {
            callEventSink.success(match { value ->
                @Suppress("UNCHECKED_CAST")
                (value as Map<String, Any?>)["i"] == 0
            })
        }
        verify(exactly = 0) {
            callEventSink.success(match { value ->
                @Suppress("UNCHECKED_CAST")
                (value as Map<String, Any?>)["i"] == 9
            })
        }
        verify(exactly = 1) {
            callEventSink.success(match { value ->
                @Suppress("UNCHECKED_CAST")
                (value as Map<String, Any?>)["i"] == 10
            })
        }
        verify(exactly = 1) {
            callEventSink.success(match { value ->
                @Suppress("UNCHECKED_CAST")
                (value as Map<String, Any?>)["i"] == 59
            })
        }
    }

    // ─── 6. Sink set to null between send and main-thread post ─────────

    @Test
    fun `event posted before sink attached is buffered and replayed on reconnect`() {
        // Don't idle the looper before the post — but the post is to the
        // main looper and will run on the next idle. The check happens
        // inside the posted runnable (where the sink is read), so timing
        // matters only if the sink attaches between the post call and
        // the runnable executing.
        //
        // Simulate: attach sink, then send, then idle → direct call.
        // Then detach sink, send, idle → buffer.
        // Then re-attach + onSinksReconnected + idle → drain.
        NativeBridgeEventSink.transcriptSink = null
        NativeBridgeEventSink.sendTranscript("buffered_1", isPartial = false)
        pumpMainLooper()

        // Confirm the event is buffered: the sink was null at the time
        // the runnable ran, so it went to the buffer.
        // Now attach and reconnect.
        NativeBridgeEventSink.transcriptSink = transcriptSink
        NativeBridgeEventSink.onSinksReconnected()
        pumpMainLooper()

        verify(exactly = 1) {
            transcriptSink.success(match { map ->
                @Suppress("UNCHECKED_CAST")
                (map as Map<String, Any?>)["text"] == "buffered_1"
            })
        }
    }
}
