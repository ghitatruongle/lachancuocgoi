package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

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

    fun begin(result: MethodChannel.Result): Boolean = synchronized(lock) {
        if (pendingResult != null) return@synchronized false
        pendingResult = result
        mainHandler.postDelayed(timeoutRunnable, CONFIRMATION_TIMEOUT_MS)
        true
    }

    fun complete(response: MonitoringStartResponse) {
        val result = synchronized(lock) {
            val current = pendingResult ?: return
            pendingResult = null
            mainHandler.removeCallbacks(timeoutRunnable)
            current
        }
        mainHandler.post { result.success(response.toMap()) }
    }

    fun cancel() = synchronized(lock) {
        pendingResult = null
        mainHandler.removeCallbacks(timeoutRunnable)
    }

    fun isPending(): Boolean = synchronized(lock) { pendingResult != null }
}

