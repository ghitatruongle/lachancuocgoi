package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.animation.ObjectAnimator
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.lachancuocgoi.lachancuocgoi_flutter.services.CallSessionCoordinator
import com.lachancuocgoi.lachancuocgoi_flutter.services.MonitoringPreferences
import com.lachancuocgoi.lachancuocgoi_flutter.R
import java.lang.ref.WeakReference
import java.util.Locale

/** Compact, app-independent version of the monitoring page. */
object MonitoringOverlayManager {
    private val overlayWindow = OverlayWindow()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var monitoringStartTime = 0L
    private var timerTextRef: WeakReference<TextView>? = null
    private var waveformRef: WeakReference<MonitoringWaveformView>? = null

    private val timerRunnable = object : Runnable {
        override fun run() {
            val elapsedSeconds =
                ((System.currentTimeMillis() - monitoringStartTime).coerceAtLeast(0L) / 1000L)
            val hours = elapsedSeconds / 3600L
            val minutes = (elapsedSeconds % 3600L) / 60L
            val seconds = elapsedSeconds % 60L
            timerTextRef?.get()?.text = if (hours > 0L) {
                String.format(Locale.getDefault(), "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                String.format(Locale.getDefault(), "%02d:%02d", minutes, seconds)
            }
            mainHandler.postDelayed(this, 1000L)
        }
    }

    fun showMonitoringOverlay(context: Context, startedAtMs: Long): Boolean {
        if (Looper.myLooper() != Looper.getMainLooper()) return false
        if (overlayWindow.isAttached) return true

        val appContext = context.applicationContext
        val root = LinearLayout(appContext).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(appContext, 16), dp(appContext, 10), dp(appContext, 16), dp(appContext, 10))
            translationY = -dp(appContext, OVERLAY_HEIGHT_DP).toFloat()
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F8FAFF"))
                cornerRadii = floatArrayOf(
                    0f, 0f, 0f, 0f,
                    dp(appContext, 18).toFloat(), dp(appContext, 18).toFloat(),
                    dp(appContext, 18).toFloat(), dp(appContext, 18).toFloat(),
                )
            }
            elevation = dp(appContext, 10).toFloat()
        }

        val header = LinearLayout(appContext).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val titleColumn = LinearLayout(appContext).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        titleColumn.addView(TextView(appContext).apply {
            text = appContext.getString(R.string.monitoring_overlay_title)
            setTextColor(Color.parseColor("#111827"))
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
        })
        titleColumn.addView(TextView(appContext).apply {
            val mode = MonitoringPreferences.readAnalysisMode(appContext)
            text = appContext.getString(
                R.string.monitoring_overlay_model,
                MonitoringPreferences.displayLabel(mode),
            )
            setTextColor(Color.parseColor("#4B5563"))
            textSize = 12f
        })
        header.addView(titleColumn)

        val timer = TextView(appContext).apply {
            text = appContext.getString(R.string.monitoring_overlay_timer_initial)
            setTextColor(Color.parseColor("#1257C0"))
            textSize = 18f
            typeface = Typeface.MONOSPACE
            gravity = Gravity.CENTER
            contentDescription = "Thời gian giám sát"
            layoutParams = LinearLayout.LayoutParams(dp(appContext, 86), dp(appContext, 42))
        }
        timerTextRef = WeakReference(timer)
        header.addView(timer)
        root.addView(header)

        val bottomRow = LinearLayout(appContext).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(appContext, 52),
            ).apply { topMargin = dp(appContext, 4) }
        }
        val waveform = MonitoringWaveformView(appContext).apply {
            contentDescription = "Sóng âm trực tiếp"
            layoutParams = LinearLayout.LayoutParams(0, dp(appContext, 42), 1f).apply {
                marginEnd = dp(appContext, 12)
            }
        }
        waveformRef = WeakReference(waveform)
        bottomRow.addView(waveform)

        bottomRow.addView(Button(appContext).apply {
            text = appContext.getString(R.string.monitoring_overlay_end_call)
            isAllCaps = false
            setTextColor(Color.WHITE)
            textSize = 12f
            contentDescription = "Kết thúc cuộc gọi và lưu lịch sử"
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#C62828"))
                cornerRadius = dp(appContext, 12).toFloat()
            }
            minWidth = 0
            minimumWidth = 0
            layoutParams = LinearLayout.LayoutParams(dp(appContext, 138), dp(appContext, 44))
            setOnClickListener { CallSessionCoordinator.endFromUser(appContext) }
        })
        root.addView(bottomRow)

        val attached = overlayWindow.attachOverlay(
            appContext,
            root,
            height = dp(appContext, OVERLAY_HEIGHT_DP),
            gravity = Gravity.TOP,
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        )
        if (!attached) {
            timerTextRef = null
            waveformRef = null
            return false
        }

        ObjectAnimator.ofFloat(root, "translationY", 0f).apply {
            duration = 250L
            interpolator = DecelerateInterpolator()
            start()
        }
        monitoringStartTime = startedAtMs.takeIf { it > 0L } ?: System.currentTimeMillis()
        mainHandler.removeCallbacks(timerRunnable)
        mainHandler.post(timerRunnable)
        return true
    }

    fun updateRms(rms: Float) {
        mainHandler.post { waveformRef?.get()?.addRms(rms) }
    }

    fun hideMonitoringOverlay() {
        mainHandler.removeCallbacks(timerRunnable)
        timerTextRef = null
        waveformRef = null
        overlayWindow.detach()
    }

    private fun dp(context: Context, value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            context.resources.displayMetrics,
        ).toInt()

    private const val OVERLAY_HEIGHT_DP = 128
}
