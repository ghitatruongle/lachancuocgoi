package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.animation.ObjectAnimator
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.lachancuocgoi.lachancuocgoi_flutter.services.BackgroundMonitoringService

object MonitoringOverlayManager {

    private var windowManager: WindowManager? = null
    private var monitoringOverlayView: View? = null

    private var monitoringStartTime: Long = 0L
    private var timerHandler: Handler? = null
    private var timerTextView: TextView? = null
    private val timerRunnable = object : Runnable {
        override fun run() {
            val elapsed = System.currentTimeMillis() - monitoringStartTime
            val totalSeconds = (elapsed / 1000).toInt()
            val minutes = totalSeconds / 60
            val seconds = totalSeconds % 60
            timerTextView?.text = String.format("%02d:%02d", minutes, seconds)
            timerHandler?.postDelayed(this, 1000L)
        }
    }

    private fun getWindowManager(context: Context): WindowManager {
        if (windowManager == null) {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        }
        return windowManager!!
    }

    private fun dpToPx(context: Context, dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            context.resources.displayMetrics
        ).toInt()
    }

    fun showMonitoringOverlay(context: Context) {
        if (monitoringOverlayView != null) return

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            dpToPx(context, 64),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP }

        val rootLayout = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dpToPx(context, 16), dpToPx(context, 8), dpToPx(context, 16), dpToPx(context, 8))

            translationY = -dpToPx(context, 64).toFloat()

            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#F6F8FC"))
                cornerRadii = floatArrayOf(
                    0f, 0f, 0f, 0f,
                    dpToPx(context, 16).toFloat(), dpToPx(context, 16).toFloat(),
                    dpToPx(context, 16).toFloat(), dpToPx(context, 16).toFloat()
                )
            }
            background = bg
            elevation = dpToPx(context, 8).toFloat()
        }

        val aiBadge = TextView(context).apply {
            text = "AI"
            setTextColor(Color.parseColor("#1257C0"))
            textSize = 12f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(dpToPx(context, 8), dpToPx(context, 4), dpToPx(context, 8), dpToPx(context, 4))
            val badgeBg = GradientDrawable().apply {
                setColor(Color.parseColor("#E3EFFF"))
                cornerRadius = dpToPx(context, 8).toFloat()
            }
            background = badgeBg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { rightMargin = dpToPx(context, 12) }
        }
        rootLayout.addView(aiBadge)

        val textColumn = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val statusText = TextView(context).apply {
            text = "Đang theo dõi"
            setTextColor(Color.parseColor("#1A1A2E"))
            textSize = 14f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        textColumn.addView(statusText)

        val elapsedText = TextView(context).apply {
            text = "00:00"
            setTextColor(Color.parseColor("#666666"))
            textSize = 12f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dpToPx(context, 2) }
        }
        timerTextView = elapsedText
        textColumn.addView(elapsedText)
        rootLayout.addView(textColumn)

        val stopButton = Button(context).apply {
            text = "✕"
            setTextColor(Color.parseColor("#C53E3E"))
            textSize = 16f
            val stopBg = GradientDrawable().apply {
                setColor(Color.parseColor("#FFE0E0"))
                cornerRadius = dpToPx(context, 12).toFloat()
            }
            background = stopBg
            val size = dpToPx(context, 40)
            layoutParams = LinearLayout.LayoutParams(size, size)
            setOnClickListener {
                stopMonitoring(context)
            }
        }
        rootLayout.addView(stopButton)

        monitoringOverlayView = rootLayout
        try {
            getWindowManager(context).addView(rootLayout, params)
            
            ObjectAnimator.ofFloat(rootLayout, "translationY", 0f).apply {
                duration = 300
                interpolator = DecelerateInterpolator()
                start()
            }

            monitoringStartTime = System.currentTimeMillis()
            timerHandler = Handler(Looper.getMainLooper())
            timerHandler?.post(timerRunnable)
        } catch (e: Exception) {
            monitoringOverlayView = null
        }
    }

    fun hideMonitoringOverlay(context: Context) {
        timerHandler?.removeCallbacks(timerRunnable)
        timerHandler = null
        timerTextView = null
        monitoringOverlayView?.let {
            try { getWindowManager(context).removeView(it) } catch (_: Exception) {}
            monitoringOverlayView = null
        }
    }

    private fun stopMonitoring(context: Context) {
        try {
            val stopIntent = Intent(context, BackgroundMonitoringService::class.java).apply {
                action = BackgroundMonitoringService.ACTION_STOP
            }
            context.startService(stopIntent)
        } catch (_: Exception) {}
    }
}
