package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ObjectAnimator
import android.content.Context
import android.graphics.Color
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.app.KeyguardManager
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.util.Log
import android.view.Gravity
import android.view.ViewTreeObserver
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.lachancuocgoi.lachancuocgoi_flutter.services.CallSessionCoordinator
import com.lachancuocgoi.lachancuocgoi_flutter.services.MonitoringPreferences
import com.lachancuocgoi.lachancuocgoi_flutter.R
import com.lachancuocgoi.lachancuocgoi_flutter.diagnostics.MonitoringPerfProbe
import java.lang.ref.WeakReference
import java.util.Locale

private const val TAG = "MonitoringOverlayManager"

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
        if (Looper.myLooper() != Looper.getMainLooper()) {
            MonitoringPerfProbe.mark("overlay_show_rejected", "reason=wrong_thread")
            return false
        }
        if (overlayWindow.isAttached) {
            MonitoringPerfProbe.mark("overlay_show_reused", "already_attached=true")
            return true
        }

        val appContext = context.applicationContext
        val keyguard = appContext.getSystemService(KeyguardManager::class.java)
            ?.isKeyguardLocked == true
        if (keyguard) {
            monitoringStartTime = startedAtMs.takeIf { it > 0L } ?: System.currentTimeMillis()
            val activityIntent = android.content.Intent(appContext, MonitoringOverlayActivity::class.java).apply {
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                    android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(MonitoringOverlayActivity.EXTRA_STARTED_AT_MS, monitoringStartTime)
            }
            runCatching { appContext.startActivity(activityIntent) }
                .onSuccess { MonitoringPerfProbe.mark("overlay_activity_requested", "keyguard=true") }
                .onFailure {
                    MonitoringPerfProbe.mark("overlay_activity_failed", "error=${it.javaClass.simpleName}")
                    Log.w(TAG, "Unable to show monitoring activity above keyguard", it)
                }
            return true
        }

        val showToken = MonitoringPerfProbe.begin("overlay_show_total")
        val buildToken = MonitoringPerfProbe.begin("overlay_view_build")
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

        MonitoringPerfProbe.end(buildToken)

        var firstPredrawRecorded = false
        val visibleRect = Rect()
        val firstFrameListener = object : ViewTreeObserver.OnPreDrawListener {
            override fun onPreDraw(): Boolean {
                if (!firstPredrawRecorded) {
                    firstPredrawRecorded = true
                    MonitoringPerfProbe.mark(
                        "overlay_first_predraw",
                        "translation_y=${root.translationY},height=${root.height}",
                    )
                }
                val visible = root.isShown &&
                    root.getGlobalVisibleRect(visibleRect) &&
                    visibleRect.height() > 0 &&
                    root.translationY > -root.height.toFloat()
                if (visible) {
                    MonitoringPerfProbe.mark(
                        "overlay_first_visible_predraw",
                        "translation_y=${root.translationY},visible_height=${visibleRect.height()}",
                    )
                    if (root.viewTreeObserver.isAlive) {
                        root.viewTreeObserver.removeOnPreDrawListener(this)
                    }
                }
                return true
            }
        }
        root.viewTreeObserver.addOnPreDrawListener(firstFrameListener)

        val addViewToken = MonitoringPerfProbe.begin("overlay_add_view")
        val attached = try {
            overlayWindow.attachOverlay(
                appContext,
                root,
                height = dp(appContext, OVERLAY_HEIGHT_DP),
                gravity = Gravity.TOP,
                flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            )
        } finally {
            MonitoringPerfProbe.end(addViewToken)
        }
        if (!attached) {
            timerTextRef = null
            waveformRef = null
            MonitoringPerfProbe.end(showToken, "attached=false")
            return false
        }

        ObjectAnimator.ofFloat(root, "translationY", 0f).apply {
            duration = 250L
            interpolator = DecelerateInterpolator()
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationStart(animation: Animator) {
                    MonitoringPerfProbe.mark("overlay_animation_started")
                }

                override fun onAnimationEnd(animation: Animator) {
                    MonitoringPerfProbe.mark("overlay_animation_finished")
                }

                override fun onAnimationCancel(animation: Animator) {
                    MonitoringPerfProbe.mark("overlay_animation_cancelled")
                }
            })
            start()
        }
        monitoringStartTime = startedAtMs.takeIf { it > 0L } ?: System.currentTimeMillis()
        mainHandler.removeCallbacks(timerRunnable)
        mainHandler.post(timerRunnable)
        MonitoringPerfProbe.end(showToken, "attached=true")
        return true
    }

    fun updateRms(rms: Float) {
        mainHandler.post { waveformRef?.get()?.addRms(rms) }
        MonitoringOverlayActivity.updateRms(rms)
    }

    fun hideMonitoringOverlay() {
        mainHandler.removeCallbacks(timerRunnable)
        timerTextRef = null
        waveformRef = null
        overlayWindow.detach()
        MonitoringOverlayActivity.close()
    }

    private fun dp(context: Context, value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            context.resources.displayMetrics,
        ).toInt()

    private const val OVERLAY_HEIGHT_DP = 128
}
