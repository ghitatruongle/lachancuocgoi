package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Thread-safe holder for EventChannel sinks.
 * Native services (running on background threads) use this to stream data
 * to Flutter UI thread via EventChannel.
 */
object NativeBridgeEventSink {

    private val mainHandler = Handler(Looper.getMainLooper())

    // EventChannel sinks — set from MainActivity when EventChannels are configured
    @Volatile var transcriptSink: EventChannel.EventSink? = null
    @Volatile var rmsSink: EventChannel.EventSink? = null
    @Volatile var monitoringStateSink: EventChannel.EventSink? = null
    @Volatile var callEventSink: EventChannel.EventSink? = null

    fun sendTranscript(text: String) {
        mainHandler.post {
            transcriptSink?.success(text)
        }
    }

    fun sendRms(value: Float) {
        mainHandler.post {
            rmsSink?.success(value.toDouble())
        }
    }

    fun sendMonitoringState(state: String) {
        mainHandler.post {
            monitoringStateSink?.success(state)
        }
    }

    fun sendCallEvent(event: Map<String, Any?>) {
        mainHandler.post {
            callEventSink?.success(event)
        }
    }
}
