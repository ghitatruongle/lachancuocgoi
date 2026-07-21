package com.lachancuocgoi.lachancuocgoi_flutter.diagnostics

import android.os.Debug
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.os.Trace
import android.util.Log
import com.lachancuocgoi.lachancuocgoi_flutter.BuildConfig
import java.util.Locale
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicLong

/**
 * Opt-in, low-overhead timing probe for physical-device monitoring tests.
 *
 * The generated build flag is false for normal debug/release builds. It is
 * enabled only by the dedicated `-PmonitoringDevicePerf=true` profile build.
 * No caller data, transcript text, or phone number is recorded.
 */
object MonitoringPerfProbe {
    data class Event(
        val runId: String,
        val stage: String,
        val atMs: Double,
        val wallMs: Double?,
        val cpuMs: Double?,
        val thread: String,
        val threadId: Int,
        val isMainThread: Boolean,
        val details: String,
    )

    class SpanToken internal constructor(
        internal val runId: String,
        internal val stage: String,
        internal val startedAtNanos: Long,
        internal val startedCpuNanos: Long,
        internal val threadId: Long,
        internal val traceStarted: Boolean,
    )

    private const val TAG = "MON_PERF"
    private val events = CopyOnWriteArrayList<Event>()
    private val sequence = AtomicLong(0L)

    @Volatile
    private var active = false

    @Volatile
    private var currentRunId = ""

    @Volatile
    private var runStartedAtNanos = 0L

    fun startRun(label: String): String {
        if (!BuildConfig.MONITORING_PERF_PROBES) return ""
        val runId = "${sanitize(label)}-${sequence.incrementAndGet()}"
        events.clear()
        currentRunId = runId
        runStartedAtNanos = SystemClock.elapsedRealtimeNanos()
        active = true
        mark("run_start", "label=$label")
        return runId
    }

    fun stopRun(details: String = "") {
        if (!isEnabled()) return
        mark("run_stop", details)
        active = false
    }

    fun isEnabled(): Boolean = BuildConfig.MONITORING_PERF_PROBES && active

    fun nowNanos(): Long = SystemClock.elapsedRealtimeNanos()

    fun mark(stage: String, details: String = "") {
        if (!isEnabled()) return
        record(stage, nowNanos(), null, null, details)
    }

    fun begin(stage: String, details: String = ""): SpanToken? {
        if (!isEnabled()) return null
        val startedAt = nowNanos()
        val token = SpanToken(
            runId = currentRunId,
            stage = stage,
            startedAtNanos = startedAt,
            startedCpuNanos = Debug.threadCpuTimeNanos(),
            threadId = Thread.currentThread().id,
            traceStarted = true,
        )
        Trace.beginSection("MON_PERF:${stage.take(96)}")
        record("${stage}_begin", startedAt, null, null, details)
        return token
    }

    fun end(token: SpanToken?, details: String = "") {
        token ?: return
        if (token.traceStarted && token.threadId == Thread.currentThread().id) {
            Trace.endSection()
        }
        if (!isEnabled() || token.runId != currentRunId) return
        val endedAt = nowNanos()
        record(
            stage = "${token.stage}_end",
            atNanos = endedAt,
            wallNanos = endedAt - token.startedAtNanos,
            cpuNanos = Debug.threadCpuTimeNanos() - token.startedCpuNanos,
            details = details,
        )
    }

    fun snapshot(): List<Event> = events.toList()

    fun hasStage(stage: String): Boolean = events.any { it.stage == stage }

    fun dumpToLog(label: String) {
        if (!BuildConfig.MONITORING_PERF_PROBES) return
        Log.i(TAG, "MON_PERF_REPORT_BEGIN|label=${sanitize(label)}|events=${events.size}")
        events.forEach { Log.i(TAG, format(it)) }
        Log.i(TAG, "MON_PERF_REPORT_END|label=${sanitize(label)}")
    }

    fun format(event: Event): String = buildString {
        append("MON_PERF")
        append("|run=").append(sanitize(event.runId))
        append("|stage=").append(sanitize(event.stage))
        append("|at_ms=").append(formatMs(event.atMs))
        event.wallMs?.let { append("|wall_ms=").append(formatMs(it)) }
        event.cpuMs?.let { append("|cpu_ms=").append(formatMs(it)) }
        append("|thread=").append(sanitize(event.thread))
        append("|tid=").append(event.threadId)
        append("|main=").append(event.isMainThread)
        if (event.details.isNotBlank()) {
            append("|details=").append(sanitize(event.details))
        }
    }

    private fun record(
        stage: String,
        atNanos: Long,
        wallNanos: Long?,
        cpuNanos: Long?,
        details: String,
    ) {
        val base = runStartedAtNanos
        if (base == 0L) return
        val event = Event(
            runId = currentRunId,
            stage = stage,
            atMs = (atNanos - base).coerceAtLeast(0L) / 1_000_000.0,
            wallMs = wallNanos?.coerceAtLeast(0L)?.div(1_000_000.0),
            cpuMs = cpuNanos?.coerceAtLeast(0L)?.div(1_000_000.0),
            thread = Thread.currentThread().name,
            threadId = Process.myTid(),
            isMainThread = Looper.myLooper() == Looper.getMainLooper(),
            details = sanitize(details),
        )
        events += event
        Log.i(TAG, format(event))
    }

    private fun formatMs(value: Double): String =
        String.format(Locale.US, "%.3f", value)

    private fun sanitize(value: String): String =
        value.replace('|', '/').replace('\n', ' ').replace('\r', ' ')
}
