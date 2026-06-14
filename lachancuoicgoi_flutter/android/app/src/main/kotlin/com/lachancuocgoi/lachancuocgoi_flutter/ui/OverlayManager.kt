package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.lachancuocgoi.lachancuocgoi_flutter.R
import com.lachancuocgoi.lachancuocgoi_flutter.services.BackgroundMonitoringService

/**
 * View-based OverlayManager for Flutter Android module.
 * Uses programmatic Android Views instead of Jetpack Compose
 * to avoid adding Compose dependency to the Flutter project.
 */
object OverlayManager {

    private var windowManager: WindowManager? = null
    private var alertOverlayView: View? = null
    private var monitoringOverlayView: View? = null
    private var incomingCallOverlayView: View? = null

    // Alarm sound player — plays system alarm ringtone on RED alerts
    // to break the victim's psychological manipulation state.
    private var alarmPlayer: MediaPlayer? = null

    // Handler for repeating heavy vibration pattern on RED alerts.
    private val heavyVibrationHandler = Handler(Looper.getMainLooper())
    private var heavyVibrationRunnable: Runnable? = null

    // Timer state for monitoring overlay
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

    // =========================================================================
    // ALERT OVERLAY (RED / ORANGE)
    // =========================================================================

    fun showRedAlert(context: Context, reason: String) {
        showAlert(context, Color.parseColor("#F44336"), "CẢNH BÁO LỪA ĐẢO!", reason, isRed = true)
    }

    fun showOrangeAlert(context: Context, reason: String) {
        showAlert(context, Color.parseColor("#FF9800"), "CẢNH BÁO NGUY CƠ", reason, isRed = false)
    }

    private fun showAlert(context: Context, color: Int, title: String, summary: String, isRed: Boolean) {
        removeAlertOverlay(context)

        // NOTE: vibration/alarm are started ONLY after addView() succeeds below.
        // Previously they ran unconditionally before addView; if addView then
        // threw (e.g. overlay permission revoked mid-call) there was no dismiss
        // button and the device would vibrate / alarm forever.

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.CENTER }

        val rootLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(context, 24), dpToPx(context, 24), dpToPx(context, 24), dpToPx(context, 24))

            val card = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dpToPx(context, 20), dpToPx(context, 20), dpToPx(context, 20), dpToPx(context, 20))

                val cardBg = GradientDrawable().apply {
                    setColor(Color.argb(242, Color.red(color), Color.green(color), Color.blue(color)))
                    cornerRadius = dpToPx(context, 16).toFloat()
                }
                background = cardBg
                elevation = dpToPx(context, 8).toFloat()
            }

            // Warning icon
            val icon = ImageView(context).apply {
                setImageResource(android.R.drawable.ic_dialog_alert)
                setColorFilter(Color.WHITE)
                val size = dpToPx(context, 48)
                layoutParams = LinearLayout.LayoutParams(size, size).apply {
                    bottomMargin = dpToPx(context, 8)
                }
            }
            card.addView(icon)

            // Title
            val titleView = TextView(context).apply {
                text = title
                setTextColor(Color.WHITE)
                textSize = 20f
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = dpToPx(context, 4) }
            }
            card.addView(titleView)

            // Summary
            val summaryView = TextView(context).apply {
                text = summary
                setTextColor(Color.WHITE)
                textSize = 16f
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = dpToPx(context, 16) }
            }
            card.addView(summaryView)

            // Dismiss button
            val button = Button(context).apply {
                text = "ĐÃ HIỂU"
                setTextColor(color)
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                val buttonBg = GradientDrawable().apply {
                    setColor(Color.WHITE)
                    cornerRadius = dpToPx(context, 8).toFloat()
                }
                background = buttonBg
                setOnClickListener {
                    removeAlertOverlay(context)
                }
            }
            card.addView(button)

            addView(card, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ))
        }

        alertOverlayView = rootLayout
        try {
            getWindowManager(context).addView(rootLayout, params)
            // addView succeeded — NOW it is safe to start vibration / alarm.
            // The dismiss button exists, so the user can stop them.
            if (isRed) {
                startHeavyVibration(context)
                playAlarmSound(context)
            } else {
                vibrate(context)
            }
        } catch (e: Exception) {
            android.util.Log.e("OverlayManager", "Failed to show alert overlay", e)
            alertOverlayView = null
            // Make sure no half-started alarm/vibration lingers (removeAlertOverlay
            // already called stopAlarmSound / stopHeavyVibration at the top, but
            // guard again in case a subclass path started them).
            stopAlarmSound()
            stopHeavyVibration(context)
        }
    }

    fun removeAlertOverlay(context: Context) {
        stopAlarmSound()
        stopHeavyVibration(context)
        alertOverlayView?.let {
            try { getWindowManager(context).removeView(it) } catch (_: Exception) {}
            alertOverlayView = null
        }
    }

    // =========================================================================
    // INCOMING CALL OVERLAY (caller info + action buttons, swipe-to-dismiss)
    // =========================================================================

    @SuppressLint("ClickableViewAccessibility")
    fun showIncomingCallOverlay(context: Context, callerInfo: String) {
        if (incomingCallOverlayView != null) return

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP
            y = dpToPx(context, 50)
        }

        // Root container for swipe-to-dismiss
        val rootLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(context, 16), dpToPx(context, 16), dpToPx(context, 16), dpToPx(context, 16))
        }

        // Card
        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dpToPx(context, 16), dpToPx(context, 16), dpToPx(context, 16), dpToPx(context, 16))

            val cardBg = GradientDrawable().apply {
                setColor(Color.parseColor("#F5F5F5"))
                cornerRadius = dpToPx(context, 16).toFloat()
            }
            background = cardBg
            elevation = dpToPx(context, 8).toFloat()
        }

        // Swipe-to-dismiss gesture on the card
        var touchStartY = 0f
        card.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    touchStartY = event.rawY
                    false // don't consume, let children handle clicks
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val deltaY = event.rawY - touchStartY
                    if (deltaY < -dpToPx(context, 30)) {
                        // Swiped up - dismiss
                        removeIncomingCallOverlay(context)
                        true
                    } else {
                        false
                    }
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaY = event.rawY - touchStartY
                    if (deltaY < -dpToPx(context, 30)) {
                        true // consume to indicate swipe in progress
                    } else {
                        false
                    }
                }
                else -> false
            }
        }

        // Title
        val titleView = TextView(context).apply {
            text = "Giám sát cuộc gọi này?"
            setTextColor(Color.parseColor("#1A1A2E"))
            textSize = 16f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dpToPx(context, 4) }
        }
        card.addView(titleView)

        // Caller info
        val callerInfoView = TextView(context).apply {
            text = callerInfo
            setTextColor(Color.parseColor("#1257C0"))
            textSize = 18f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = dpToPx(context, 16) }
        }
        card.addView(callerInfoView)

        // Button row
        val buttonRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        // "Bỏ qua" button
        val skipButton = Button(context).apply {
            text = "Bỏ qua"
            setTextColor(Color.parseColor("#666666"))
            textSize = 14f
            val skipBg = GradientDrawable().apply {
                setColor(Color.TRANSPARENT)
                setStroke(dpToPx(context, 1), Color.parseColor("#CCCCCC"))
                cornerRadius = dpToPx(context, 8).toFloat()
            }
            background = skipBg
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                rightMargin = dpToPx(context, 8)
            }
            setOnClickListener {
                removeIncomingCallOverlay(context)
            }
        }
        buttonRow.addView(skipButton)

        // "Bật Giám sát" button
        val monitorButton = Button(context).apply {
            text = "Bật Giám sát"
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            val monitorBg = GradientDrawable().apply {
                setColor(Color.parseColor("#1257C0"))
                cornerRadius = dpToPx(context, 8).toFloat()
            }
            background = monitorBg
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                leftMargin = dpToPx(context, 8)
            }
            setOnClickListener {
                // Start monitoring service
                val monitorIntent = Intent(context, BackgroundMonitoringService::class.java).apply {
                    action = BackgroundMonitoringService.ACTION_START
                    putExtra("PHONE_NUMBER", callerInfo)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(monitorIntent)
                } else {
                    context.startService(monitorIntent)
                }
                removeIncomingCallOverlay(context)
            }
        }
        buttonRow.addView(monitorButton)

        card.addView(buttonRow)
        rootLayout.addView(card, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        incomingCallOverlayView = rootLayout
        try {
            getWindowManager(context).addView(rootLayout, params)
        } catch (e: Exception) {
            android.util.Log.e("OverlayManager", "Failed to show incoming call overlay", e)
            incomingCallOverlayView = null
        }
    }

    fun removeIncomingCallOverlay(context: Context) {
        incomingCallOverlayView?.let {
            try { getWindowManager(context).removeView(it) } catch (_: Exception) {}
            incomingCallOverlayView = null
        }
    }

    // =========================================================================
    // MONITORING OVERLAY (top bar with timer + stop button)
    // =========================================================================

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

        // AI badge
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

        // Status + timer column
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

        // Live timer text (MM:SS)
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

        // Stop button
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
            // Start live timer
            monitoringStartTime = System.currentTimeMillis()
            timerHandler = Handler(Looper.getMainLooper())
            timerHandler?.post(timerRunnable)
        } catch (e: Exception) {
            android.util.Log.e("OverlayManager", "Failed to show monitoring overlay", e)
            monitoringOverlayView = null
        }
    }

    fun hideMonitoringOverlay(context: Context) {
        // Stop timer
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

    /**
     * Single light vibration (500ms) — used for ORANGE alerts.
     */
    private fun vibrate(context: Context) {
        try {
            val vibrator = getVibrator(context) ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION") vibrator.vibrate(500)
            }
        } catch (_: Exception) {}
    }

    /**
     * Heavy vibration pattern — repeated bursts designed to break the
     * victim's psychological manipulation state during RED alerts.
     *
     * Pattern: [0ms silence, 400ms vibrate, 150ms silence, 400ms vibrate,
     *           150ms silence, 400ms vibrate] — then repeat every 2 seconds.
     */
    private fun startHeavyVibration(context: Context) {
        stopHeavyVibration(context)
        try {
            val vibrator = getVibrator(context) ?: return
            // Pattern: wait, vibrate, pause, vibrate, pause, vibrate
            val pattern = longArrayOf(0, 400, 150, 400, 150, 400)
            val repeatIndex = 0 // repeat from the beginning

            heavyVibrationRunnable = object : Runnable {
                override fun run() {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            vibrator.vibrate(
                                VibrationEffect.createWaveform(pattern, repeatIndex)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            vibrator.vibrate(pattern, repeatIndex)
                        }
                    } catch (_: Exception) {}
                    // Re-trigger every 2 seconds to sustain the heavy vibration
                    // feel even if the OS limits the waveform duration.
                    heavyVibrationHandler.postDelayed(this, 2000L)
                }
            }
            heavyVibrationHandler.post(heavyVibrationRunnable!!)
        } catch (_: Exception) {}
    }

    private fun stopHeavyVibration(context: Context) {
        heavyVibrationRunnable?.let { heavyVibrationHandler.removeCallbacks(it) }
        heavyVibrationRunnable = null
        try {
            getVibrator(context)?.cancel()
        } catch (_: Exception) {}
    }

    /**
     * Plays the system default ALARM ringtone in a loop.
     * Uses MediaPlayer so we can control start/stop precisely.
     * This is the "âm thanh báo động" described in the thesis — designed
     * to immediately grab the victim's attention and break the scammer's
     * psychological hold.
     */
    private fun playAlarmSound(context: Context) {
        stopAlarmSound()
        try {
            val alarmUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ?: return

            alarmPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(context, alarmUri)
                isLooping = true
                setVolume(1.0f, 1.0f) // Maximum volume
                prepare()
                start()
            }
        } catch (e: Exception) {
            android.util.Log.e("OverlayManager", "Failed to play alarm sound", e)
            alarmPlayer = null
        }
    }

    private fun stopAlarmSound() {
        try {
            alarmPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {}
        alarmPlayer = null
    }

    private fun getVibrator(context: Context): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager =
                context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    fun removeAll(context: Context) {
        removeAlertOverlay(context)
        hideMonitoringOverlay(context)
        removeIncomingCallOverlay(context)
    }
}
