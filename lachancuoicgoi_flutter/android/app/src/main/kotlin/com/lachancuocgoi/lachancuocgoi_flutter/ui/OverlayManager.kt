package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.TypedValue
import android.view.Gravity
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
        showAlert(context, Color.parseColor("#F44336"), "CẢNH BÁO LỪA ĐẢO!", reason)
    }

    fun showOrangeAlert(context: Context, reason: String) {
        showAlert(context, Color.parseColor("#FF9800"), "CẢNH BÁO NGUY CƠ", reason)
    }

    private fun showAlert(context: Context, color: Int, title: String, summary: String) {
        removeAlertOverlay(context)
        vibrate(context)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
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
        } catch (e: Exception) {
            android.util.Log.e("OverlayManager", "Failed to show alert overlay", e)
            alertOverlayView = null
        }
    }

    fun removeAlertOverlay(context: Context) {
        alertOverlayView?.let {
            try { getWindowManager(context).removeView(it) } catch (_: Exception) {}
            alertOverlayView = null
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

        // Status text
        val statusText = TextView(context).apply {
            text = "Đang theo dõi"
            setTextColor(Color.parseColor("#1A1A2E"))
            textSize = 14f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        rootLayout.addView(statusText)

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
        } catch (e: Exception) {
            android.util.Log.e("OverlayManager", "Failed to show monitoring overlay", e)
            monitoringOverlayView = null
        }
    }

    fun hideMonitoringOverlay(context: Context) {
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
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(stopIntent)
            } else {
                context.startService(stopIntent)
            }
        } catch (_: Exception) {}
    }

    private fun vibrate(context: Context) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION") vibrator.vibrate(500)
            }
        } catch (_: Exception) {}
    }

    fun removeAll(context: Context) {
        removeAlertOverlay(context)
        hideMonitoringOverlay(context)
    }
}
