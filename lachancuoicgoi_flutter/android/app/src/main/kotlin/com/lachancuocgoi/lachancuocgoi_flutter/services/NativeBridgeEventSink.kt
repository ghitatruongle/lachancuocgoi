package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ConcurrentLinkedQueue

object NativeBridgeEventSink {

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile var transcriptSink: EventChannel.EventSink? = null
    @Volatile var rmsSink: EventChannel.EventSink? = null
    @Volatile var monitoringStateSink: EventChannel.EventSink? = null
    @Volatile var callEventSink: EventChannel.EventSink? = null
    @Volatile var logsSink: EventChannel.EventSink? = null

    private const val MAX_BUFFER_SIZE = 50

    private data class BufferedTranscript(val text: String, val isPartial: Boolean)

    private val transcriptBuffer = ConcurrentLinkedQueue<BufferedTranscript>()
    private val monitoringStateBuffer = ConcurrentLinkedQueue<String>()
    private val callEventBuffer = ConcurrentLinkedQueue<Map<String, Any?>>()
    private val logsBuffer = ConcurrentLinkedQueue<String>()

    fun onSinksReconnected() {
        mainHandler.post {

            val stateSink = monitoringStateSink
            if (stateSink != null) {
                while (monitoringStateBuffer.isNotEmpty()) {
                    stateSink.success(monitoringStateBuffer.poll())
                }
            }

            val tSink = transcriptSink
            if (tSink != null) {
                while (transcriptBuffer.isNotEmpty()) {
                    val buffered = transcriptBuffer.poll() ?: break
                    tSink.success(
                        mapOf("text" to buffered.text, "isPartial" to buffered.isPartial)
                    )
                }
            }

            val cSink = callEventSink
            if (cSink != null) {
                while (callEventBuffer.isNotEmpty()) {
                    cSink.success(callEventBuffer.poll())
                }
            }

            val lSink = logsSink
            if (lSink != null) {
                while (logsBuffer.isNotEmpty()) {
                    lSink.success(logsBuffer.poll())
                }
            }
        }
    }

    fun sendTranscript(text: String, isPartial: Boolean = false) {
        mainHandler.post {
            val sink = transcriptSink
            val payload = mapOf("text" to text, "isPartial" to isPartial)
            if (sink != null) {
                sink.success(payload)
            } else {

                if (transcriptBuffer.size >= MAX_BUFFER_SIZE) transcriptBuffer.poll()
                transcriptBuffer.offer(BufferedTranscript(text, isPartial))
            }
        }
    }

    fun sendRms(value: Float) {

        synchronized(rmsLock) {
            latestRmsValue = value
            if (!rmsFlushScheduled) {
                rmsFlushScheduled = true
                mainHandler.post {
                    val v: Float
                    synchronized(rmsLock) {
                        v = latestRmsValue ?: return@post
                        latestRmsValue = null
                        rmsFlushScheduled = false
                    }
                    rmsSink?.success(v.toDouble())
                }
            }
        }
    }

    private val rmsLock = Any()
    private var latestRmsValue: Float? = null
    private var rmsFlushScheduled = false

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

        val rawNumber = event["phoneNumber"] as? String
        val stamped = LinkedHashMap<String, Any?>(event.size + 5).apply {
            putAll(event)
            remove("phoneNumber")
            put("type", (event["type"] as? String)?.takeIf { it.isNotBlank() } ?: "UNKNOWN")
            put(
                "timestampMs",
                (event["timestampMs"] as? Number)?.toLong()?.takeIf { it > 0L }
                    ?: System.currentTimeMillis(),
            )
            put(
                "reason",
                (event["reason"] as? String)?.takeIf { it.isNotBlank() } ?: "native_event",
            )
            val available = (event["numberAvailable"] as? Boolean) ?: !rawNumber.isNullOrBlank()
            put("numberAvailable", available)
            put(
                "maskedNumber",
                (event["maskedNumber"] as? String)
                    ?: if (available) NativeCallEvent.maskPhoneNumber(rawNumber) else null,
            )
        }
        mainHandler.post {
            val sink = callEventSink
            if (sink != null) {
                sink.success(stamped)
            } else {
                if (callEventBuffer.size >= MAX_BUFFER_SIZE) callEventBuffer.poll()
                callEventBuffer.offer(stamped)
            }
        }
    }

    fun sendLog(tag: String, message: String, level: String = "INFO") {
        val raw = "$level|$tag|$message"
        mainHandler.post {
            val sink = logsSink
            if (sink != null) {
                sink.success(raw)
            } else {
                if (logsBuffer.size >= MAX_BUFFER_SIZE) logsBuffer.poll()
                logsBuffer.offer(raw)
            }
        }
    }
}

