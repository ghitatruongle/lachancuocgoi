package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.content.Context
import android.graphics.PixelFormat
import android.util.Log
import android.view.View
import android.view.WindowManager
import com.lachancuocgoi.lachancuocgoi_flutter.diagnostics.MonitoringPerfProbe
import java.lang.ref.WeakReference

class OverlayWindow {

    private var viewRef: WeakReference<View>? = null
    private var params: WindowManager.LayoutParams? = null
    private var contextRef: WeakReference<Context>? = null

    val isAttached: Boolean
        get() = viewRef?.get() != null

    fun attach(context: Context, view: View, params: WindowManager.LayoutParams): Boolean {
        if (viewRef?.get() === view) {

            return true
        }

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

    fun detach() {
        val view = viewRef?.get()
        if (view == null) {

            return
        }
        val context = contextRef?.get()
        if (context == null) {

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

