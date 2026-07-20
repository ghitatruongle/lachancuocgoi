package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/**
 * Completes the start-monitoring MethodChannel call only after the service has
 * actually promoted itself to foreground and entered its active state.
 *
 * Starting a foreground service is asynchronous: a successful
 * `startForegroundService()` call only means Android accepted the request. It
 * does not prove that `Service.onStartCommand()` ran or that `startForeground()`
 * succeeded. Keeping the pending result here prevents Flutter from displaying
 * an active/protected state before native startup is confirmed.
 */
object MonitoringStartCoordinator {
    private const val CONFIRMATION_TIMEOUT_MS = 5_000L
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Any()
    private var pendingResult: MethodChannel.Result? = null

    private val timeoutRunnable = Runnable {
        complete(
            MonitoringStartResponse(
                MonitoringStartStatus.NATIVE_FAILURE,
                "Dịch vụ giám sát không xác nhận khởi động kịp thời.",
            )
        )
    }

    /** Returns false when another start request is still awaiting confirmation. */
    fun begin(result: MethodChannel.Result): Boolean = synchronized(lock) {
        if (pendingResult != null) return@synchronized false
        pendingResult = result
        mainHandler.postDelayed(timeoutRunnable, CONFIRMATION_TIMEOUT_MS)
        true
    }

    /** Completes at most one pending MethodChannel result. */
    fun complete(response: MonitoringStartResponse) {
        val result = synchronized(lock) {
            val current = pendingResult ?: return
            pendingResult = null
            mainHandler.removeCallbacks(timeoutRunnable)
            current
        }
        mainHandler.post { result.success(response.toMap()) }
    }

    /** Clears an Activity-owned callback without reporting a result. */
    fun cancel() = synchronized(lock) {
        pendingResult = null
        mainHandler.removeCallbacks(timeoutRunnable)
    }

    fun isPending(): Boolean = synchronized(lock) { pendingResult != null }
}
