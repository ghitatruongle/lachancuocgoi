package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.Window
import android.view.WindowManager
import android.view.ViewTreeObserver
import android.util.TypedValue
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.lachancuocgoi.lachancuocgoi_flutter.R
import com.lachancuocgoi.lachancuocgoi_flutter.services.CallSessionCoordinator
import com.lachancuocgoi.lachancuocgoi_flutter.services.MonitoringPreferences
import com.lachancuocgoi.lachancuocgoi_flutter.diagnostics.MonitoringPerfProbe
import java.lang.ref.WeakReference
import java.util.Locale

/** Activity-backed monitoring surface used when the keyguard hides app overlays. */
class MonitoringOverlayActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var startedAtMs = 0L
    private var timer: TextView? = null

    private val timerRunnable = object : Runnable {
        override fun run() {
            val elapsed = ((System.currentTimeMillis() - startedAtMs).coerceAtLeast(0L) / 1000L)
            val minutes = elapsed / 60L
            val seconds = elapsed % 60L
            timer?.text = String.format(Locale.getDefault(), "%02d:%02d", minutes, seconds)
            handler.postDelayed(this, 1000L)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureWindow(window)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        instanceRef = WeakReference(this)
        startedAtMs = intent.getLongExtra(EXTRA_STARTED_AT_MS, System.currentTimeMillis())
        setContentView(buildContent())
        installFirstFrameProbe()
        activeWaveform = WeakReference(waveform)
        handler.post(timerRunnable)
    }

    override fun onNewIntent(intent: android.content.Intent?) {
        super.onNewIntent(intent)
        intent ?: return
        startedAtMs = intent.getLongExtra(EXTRA_STARTED_AT_MS, startedAtMs)
    }

    override fun onDestroy() {
        handler.removeCallbacks(timerRunnable)
        if (activeWaveform?.get() === waveform) activeWaveform = null
        timer = null
        waveform = null
        super.onDestroy()
    }

    private fun buildContent(): View {
        val root = FrameLayout(this)
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(10), dp(16), dp(10))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F8FAFF"))
                cornerRadii = floatArrayOf(0f, 0f, 0f, 0f, dp(18).toFloat(), dp(18).toFloat(), dp(18).toFloat(), dp(18).toFloat())
            }
            elevation = dp(10).toFloat()
        }
        val header = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        val titleColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        titleColumn.addView(TextView(this).apply {
            text = getString(R.string.monitoring_overlay_title)
            setTextColor(Color.parseColor("#111827")); textSize = 15f; typeface = Typeface.DEFAULT_BOLD
        })
        titleColumn.addView(TextView(this).apply {
            val mode = MonitoringPreferences.readAnalysisMode(this@MonitoringOverlayActivity)
            text = getString(R.string.monitoring_overlay_model, MonitoringPreferences.displayLabel(mode))
            setTextColor(Color.parseColor("#4B5563")); textSize = 12f
        })
        header.addView(titleColumn)
        timer = TextView(this).apply {
            textSize = 18f; typeface = Typeface.MONOSPACE; gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#1257C0")); layoutParams = LinearLayout.LayoutParams(dp(86), dp(42))
        }
        header.addView(timer)
        panel.addView(header)

        val bottom = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(52)).apply { topMargin = dp(4) }
        }
        waveform = MonitoringWaveformView(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, dp(42), 1f).apply { marginEnd = dp(12) }
        }
        bottom.addView(waveform)
        bottom.addView(Button(this).apply {
            text = getString(R.string.monitoring_overlay_end_call); isAllCaps = false
            setTextColor(Color.WHITE); textSize = 12f; minWidth = 0; minimumWidth = 0
            background = GradientDrawable().apply { setColor(Color.parseColor("#C62828")); cornerRadius = dp(12).toFloat() }
            layoutParams = LinearLayout.LayoutParams(dp(138), dp(44))
            setOnClickListener { CallSessionCoordinator.endFromUser(applicationContext) }
        })
        panel.addView(bottom)
        root.addView(panel, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, dp(128), Gravity.TOP))
        return root
    }

    private fun installFirstFrameProbe() {
        val content = findViewById<View>(android.R.id.content)
        var recorded = false
        val listener = object : ViewTreeObserver.OnPreDrawListener {
            override fun onPreDraw(): Boolean {
                if (!recorded) {
                    recorded = true
                    MonitoringPerfProbe.mark("overlay_first_predraw", "surface=activity")
                    MonitoringPerfProbe.mark("overlay_first_visible_predraw", "surface=activity")
                    if (content.viewTreeObserver.isAlive) content.viewTreeObserver.removeOnPreDrawListener(this)
                }
                return true
            }
        }
        content.viewTreeObserver.addOnPreDrawListener(listener)
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics).toInt()

    companion object {
        const val EXTRA_STARTED_AT_MS = "startedAtMs"
        private var instanceRef: WeakReference<MonitoringOverlayActivity>? = null
        private var activeWaveform: WeakReference<MonitoringWaveformView>? = null
        private var waveform: MonitoringWaveformView? = null

        fun updateRms(rms: Float) { activeWaveform?.get()?.addRms(rms) }

        fun close() { instanceRef?.get()?.finish(); instanceRef = null }

        private fun configureWindow(window: Window) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            window.setStatusBarColor(Color.parseColor("#F8FAFF"))
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        }
    }
}
