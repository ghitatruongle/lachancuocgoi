package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * Thread-safe holder for EventChannel sinks.
 * Native services (running on background threads) use this to stream data
 * to Flutter UI thread via EventChannel.
 *
 * Bug fix: buffers events when sinks are null (during Activity recreate)
 * and replays them when sinks are reconnected.
 */
object NativeBridgeEventSink {

    private val mainHandler = Handler(Looper.getMainLooper())

    // EventChannel sinks — set from MainActivity when EventChannels are configured
    @Volatile var transcriptSink: EventChannel.EventSink? = null
    @Volatile var rmsSink: EventChannel.EventSink? = null
    @Volatile var monitoringStateSink: EventChannel.EventSink? = null
    @Volatile var callEventSink: EventChannel.EventSink? = null

    // Buffers for events that arrive while sinks are null (Activity recreate).
    // Each buffer is capped to avoid unbounded memory growth.
    private const val MAX_BUFFER_SIZE = 50

    /**
     * Internal holder for a transcript that arrived while the EventChannel
     * sink was detached (Activity recreate). On reconnect we re-emit it
     * as a Map so the Dart side sees the same shape as live events.
     */
    private data class BufferedTranscript(val text: String, val isPartial: Boolean)

    private val transcriptBuffer = ConcurrentLinkedQueue<BufferedTranscript>()
    private val monitoringStateBuffer = ConcurrentLinkedQueue<String>()
    private val callEventBuffer = ConcurrentLinkedQueue<Map<String, Any?>>()

    /**
     * Call from MainActivity after configuring EventChannel listeners.
     * Replays any buffered events to the newly connected sinks.
     */
    fun onSinksReconnected() {
        mainHandler.post {
            // Replay buffered monitoring state events
            val stateSink = monitoringStateSink
            if (stateSink != null) {
                while (monitoringStateBuffer.isNotEmpty()) {
                    stateSink.success(monitoringStateBuffer.poll())
                }
            }
            // Replay buffered transcripts (expanded payload with isPartial flag)
            val tSink = transcriptSink
            if (tSink != null) {
                while (transcriptBuffer.isNotEmpty()) {
                    val buffered = transcriptBuffer.poll() ?: break
                    tSink.success(
                        mapOf("text" to buffered.text, "isPartial" to buffered.isPartial)
                    )
                }
            }
            // Replay buffered call events
            val cSink = callEventSink
            if (cSink != null) {
                while (callEventBuffer.isNotEmpty()) {
                    cSink.success(callEventBuffer.poll())
                }
            }
        }
    }

    /**
     * Stream a transcript update to Flutter.
     *
     * @param text  The transcript text (final cumulative or partial current utterance).
     * @param isPartial  True when [text] is a partial/interim result that may be
     *                   revised by the next final result. False when [text] is the
     *                   latest cumulative final transcript.
     *
     * The payload is a Map { "text": String, "isPartial": Boolean } so Dart can
     * distinguish partial from final. The single-arg overload stays for back-compat
     * with any other caller (defaults to isPartial=false).
     */
    fun sendTranscript(text: String, isPartial: Boolean = false) {
        mainHandler.post {
            val sink = transcriptSink
            val payload = mapOf("text" to text, "isPartial" to isPartial)
            if (sink != null) {
                sink.success(payload)
            } else {
                // Buffer for replay when sink reconnects
                if (transcriptBuffer.size >= MAX_BUFFER_SIZE) transcriptBuffer.poll()
                transcriptBuffer.offer(BufferedTranscript(text, isPartial))
            }
        }
    }

    fun sendRms(value: Float) {
        mainHandler.post {
            rmsSink?.success(value.toDouble())
            // RMS is high-frequency — do not buffer (stale data is useless)
        }
    }

    fun sendMonitoringState(state: String) {
        mainHandler.post {
            val sink = monitoringStateSink
            if (sink != null) {
                sink.success(state)
            } else {
                if (monitoringStateBuffer.size >= MAX_BUFFER_SIZE) monitoringStateBuffer.poll()
                monitoringStateBuffer.offer(state)
            }
        }
    }

    fun sendCallEvent(event: Map<String, Any?>) {
        mainHandler.post {
            val sink = callEventSink
            if (sink != null) {
                sink.success(event)
            } else {
                if (callEventBuffer.size >= MAX_BUFFER_SIZE) callEventBuffer.poll()
                callEventBuffer.offer(event)
            }
        }
    }
}
