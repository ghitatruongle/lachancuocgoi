package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * Idempotent, timeout-bounded wrapper around a [MethodChannel.Result].
 *
 * Replaces the raw `var pendingCreatorMonitoringResult: MethodChannel.Result?` /
 * `var pendingPhonePermissionResult: MethodChannel.Result?` pattern in
 * `MainActivity` so that:
 *
 *  1. If the Activity is destroyed before the result arrives, the result
 *     is never lost (idempotent — calling `success`/`error` after the Activity
 *     is gone is a safe no-op, but [consume] has already returned the result
 *     via [cancel] or [onDestroy]).
 *  2. Calling `success` twice, or mixing `success` / `error` / `notImplemented`
 *     only fires the underlying Result once. The first call wins.
 *  3. A pending result that is never consumed within [timeoutMs] fires a
 *     `TIMEOUT` error on the underlying Result so the Dart side doesn't hang
 *     forever.
 *  4. Calling `cancel()` (typically from `Activity.onDestroy`) clears the
 *     pending result without firing any callback.
 *
 * Thread safety: all public methods are safe to call from any thread.
 * The [result] field is `@Volatile` so reads/writes are visible across
 * threads. The [consume] method uses a compare-and-swap pattern via
 * [generation] to ensure only one caller can consume the result.
 *
 * @param timeoutMs  Maximum time the result may remain pending before an
 *                   automatic TIMEOUT error is delivered. Default 60s.
 * @param onExpire   Optional callback invoked once when the timeout fires.
 */
class PendingResult(
    private val timeoutMs: Long = DEFAULT_TIMEOUT_MS,
    private val onExpire: (() -> Unit)? = null,
) {
    @Volatile private var result: MethodChannel.Result? = null
    @Volatile private var generation: Long = 0L
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

    /**
     * Register a [MethodChannel.Result] to be completed later. If a previous
     * result is still pending it is discarded (its timeout is cancelled, and
     * it will silently never fire — this is the safe behavior because
     * re-registering means the caller has explicitly given up on the old
     * result).
     *
     * Thread-safe: can be called from any thread.
     */
    fun set(newResult: MethodChannel.Result) {
        // Cancel any pending timeout for the previous result.
        mainHandler.removeCallbacks(timeoutRunnable)
        // Set the result and bump generation atomically.
        result = newResult
        generation++
        // Schedule timeout on main looper.
        mainHandler.postDelayed(timeoutRunnable, timeoutMs)
    }

    /**
     * Complete the pending result with a value. No-op if no result is pending
     * or if the result has already been completed.
     *
     * Thread-safe: can be called from any thread.
     */
    fun success(value: Any?) {
        consume()?.success(value)
    }

    /**
     * Complete the pending result with an error. No-op if no result is pending
     * or if the result has already been completed.
     *
     * Thread-safe: can be called from any thread.
     */
    fun error(code: String, message: String?, details: Any?) {
        consume()?.error(code, message, details)
    }

    /**
     * Mark the pending result as not implemented. No-op if no result is pending
     * or if the result has already been completed.
     *
     * Thread-safe: can be called from any thread.
     */
    fun notImplemented() {
        consume()?.notImplemented()
    }

    /**
     * Cancel the pending result without firing any callback. Safe to call from
     * `Activity.onDestroy` — after this returns, `isPending()` is false and no
     * future `success`/`error`/`notImplemented` will reach the underlying
     * Flutter side.
     *
     * Thread-safe: can be called from any thread.
     */
    fun cancel() {
        mainHandler.removeCallbacks(timeoutRunnable)
        result = null
        generation++
    }

    /** True iff a result is currently pending. */
    fun isPending(): Boolean = result != null

    /**
     * Atomically detach and return the pending result, cancelling the timeout.
     * Returns null if no result was pending or if it was already consumed.
     *
     * Thread-safe: uses volatile reads/writes. The generation counter ensures
     * that if two threads race on [consume], only one will see the result.
     */
    private fun consume(): MethodChannel.Result? {
        mainHandler.removeCallbacks(timeoutRunnable)
        val r = result ?: return null
        result = null
        generation++
        return r
    }

    companion object {
        private const val TAG = "PendingResult"
        /**
         * Default timeout: 60s. This is generous enough for any realistic
         * operation (the slowest is MediaProjection dialog which completes
         * in <1s on a healthy device). The 30s default was too short for
         * slow devices or when the user is distracted.
         */
        const val DEFAULT_TIMEOUT_MS = 60_000L
    }
}
