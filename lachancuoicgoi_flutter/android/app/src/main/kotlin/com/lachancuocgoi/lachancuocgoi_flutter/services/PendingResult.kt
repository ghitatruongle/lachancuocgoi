package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class PendingResult(
    private val timeoutMs: Long = DEFAULT_TIMEOUT_MS,
    private val onExpire: (() -> Unit)? = null,
) {
    private val lock = Any()
    @Volatile private var result: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val timeoutRunnable = Runnable {
        val r = consume()
        if (r != null) {
            try {
                r.error(
                    "TIMEOUT",
                    "Result was not delivered within ${timeoutMs}ms",
                    null,
                )
            } catch (e: Exception) {
                Log.w(TAG, "Failed to deliver TIMEOUT error", e)
            }
            onExpire?.invoke()
        }
    }

    fun set(newResult: MethodChannel.Result) = synchronized(lock) {

        mainHandler.removeCallbacks(timeoutRunnable)

        result = newResult

        mainHandler.postDelayed(timeoutRunnable, timeoutMs)
    }

    fun success(value: Any?) {
        consume()?.success(value)
    }

    fun error(code: String, message: String?, details: Any?) {
        consume()?.error(code, message, details)
    }

    fun notImplemented() {
        consume()?.notImplemented()
    }

    fun cancel() = synchronized(lock) {
        mainHandler.removeCallbacks(timeoutRunnable)
        result = null
    }

    fun isPending(): Boolean = synchronized(lock) { result != null }

    private fun consume(): MethodChannel.Result? = synchronized(lock) {
        mainHandler.removeCallbacks(timeoutRunnable)
        val r = result ?: return@synchronized null
        result = null
        r
    }

    companion object {
        private const val TAG = "PendingResult"

        const val DEFAULT_TIMEOUT_MS = 60_000L
    }
}

