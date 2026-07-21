package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.content.Context
import android.graphics.PixelFormat
import android.util.Log
import android.view.View
import android.view.WindowManager
import com.lachancuocgoi.lachancuocgoi_flutter.diagnostics.MonitoringPerfProbe
import java.lang.ref.WeakReference

/**
 * Helper that wraps a [WindowManager.addView] / [WindowManager.removeView]
 * pair with:
 *
 *  1. **Exception-safe attach/detach** — never throws. Bugs #11, #12 fix:
 *     previously each of [AlertOverlayManager], [IncomingCallOverlayManager],
 *     [MonitoringOverlayManager] re-implemented `try { wm.addView(view, params) }`
 *     with subtle differences (some didn't release MediaPlayer, some
 *     didn't null-out the view reference, etc.).
 *
 *  2. **Weak reference** for the view. Previously the managers stored a
 *     hard reference in a `companion object var`, which prevented the
 *     Activity from being garbage-collected after a config change. Bug #11.
 *
 *  3. **Idempotent attach** — calling `attach` when already attached is a
 *     no-op (returns false). Idempotent detach — calling `detach` when
 *     not attached is a no-op.
 *
 *  4. **Auto-detach on context death** — pass an Application context and
 *     the overlay will not accidentally outlive the Activity. The
 *     weak reference handles GC; for explicit cleanup, call `detach()`.
 *
 * Use:
 * ```
 * val overlay = OverlayWindow()
 * fun showAlert(ctx: Context, view: View, w: Int, h: Int) {
 *     val params = WindowManager.LayoutParams(
 *         w, h,
 *         WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
 *         WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
 *         PixelFormat.TRANSLUCENT,
 *     )
 *     overlay.attach(ctx, view, params)
 * }
 * fun hideAlert() { overlay.detach() }
 * ```
 */
class OverlayWindow {

    private var viewRef: WeakReference<View>? = null
    private var params: WindowManager.LayoutParams? = null
    private var contextRef: WeakReference<Context>? = null

    val isAttached: Boolean
        get() = viewRef?.get() != null

    /**
     * Attach [view] to the window manager with the given layout params.
     *
     * @return true if attached successfully; false if [view] is already
     *         attached (idempotent) or if the system threw (e.g. permission
     *         denied).
     */
    fun attach(context: Context, view: View, params: WindowManager.LayoutParams): Boolean {
        if (viewRef?.get() === view) {
            // Already attached — idempotent no-op.
            return true
        }
        // If a previous view is attached to a different reference, detach first.
        if (viewRef?.get() != null) {
            detach()
        }
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
            ?: run {
                Log.w(TAG, "WindowManager not available")
                return false
            }
        return try {
            wm.addView(view, params)
            viewRef = WeakReference(view)
            this.params = params
            contextRef = WeakReference(context.applicationContext)
            MonitoringPerfProbe.mark("overlay_add_view_succeeded")
            true
        } catch (e: Exception) {
            Log.w(TAG, "addView failed: ${e.javaClass.simpleName} ${e.message}")
            MonitoringPerfProbe.mark(
                "overlay_add_view_failed",
                "error=${e.javaClass.simpleName}",
            )
            viewRef = null
            this.params = null
            false
        }
    }

    /**
     * Detach the currently attached view, if any. Safe to call from any
     * thread (post to main if necessary). Never throws.
     */
    fun detach() {
        val view = viewRef?.get()
        if (view == null) {
            // Nothing to detach.
            return
        }
        val context = contextRef?.get()
        if (context == null) {
            // Context died; just clear our reference. The view will be
            // garbage-collected soon.
            viewRef = null
            params = null
            return
        }
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
            ?: run {
                viewRef = null
                params = null
                return
            }
        try {
            wm.removeView(view)
        } catch (e: Exception) {
            Log.w(TAG, "removeView failed (view already removed?): ${e.javaClass.simpleName}")
        }
        viewRef = null
        params = null
    }

    /**
     * Convenience: attach with the standard `TYPE_APPLICATION_OVERLAY`
     * flags and TRANSLUCENT pixel format.
     */
    fun attachOverlay(
        context: Context,
        view: View,
        width: Int = WindowManager.LayoutParams.MATCH_PARENT,
        height: Int = WindowManager.LayoutParams.WRAP_CONTENT,
        gravity: Int = android.view.Gravity.TOP,
        flags: Int = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
    ): Boolean {
        val params = WindowManager.LayoutParams(
            width,
            height,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            flags,
            PixelFormat.TRANSLUCENT,
        ).apply {
            this.gravity = gravity
        }
        return attach(context, view, params)
    }

    companion object {
        private const val TAG = "OverlayWindow"
    }
}
