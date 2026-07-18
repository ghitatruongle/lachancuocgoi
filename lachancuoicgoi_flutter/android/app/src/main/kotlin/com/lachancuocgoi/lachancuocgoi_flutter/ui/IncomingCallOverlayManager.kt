package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.animation.ObjectAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.lachancuocgoi.lachancuocgoi_flutter.services.BackgroundMonitoringService
import com.lachancuocgoi.lachancuocgoi_flutter.services.ForegroundServiceLauncher
import com.lachancuocgoi.lachancuocgoi_flutter.services.NativeBridgeEventSink

object IncomingCallOverlayManager {

    private var windowManager: WindowManager? = null
    private var incomingCallOverlayView: View? = null

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

        val rootLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(context, 16), dpToPx(context, 16), dpToPx(context, 16), dpToPx(context, 16))
            
            // Initial animation state
            translationY = -100f
            alpha = 0f
        }

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

        var touchStartY = 0f
        card.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    touchStartY = event.rawY
                    false
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val deltaY = event.rawY - touchStartY
                    if (deltaY < -dpToPx(context, 30)) {
                        removeIncomingCallOverlay(context)
                        true
                    } else {
                        false
                    }
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaY = event.rawY - touchStartY
                    deltaY < -dpToPx(context, 30)
                }
                else -> false
            }
        }

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

        val buttonRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

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
                val monitorIntent = Intent(context, BackgroundMonitoringService::class.java).apply {
                    action = BackgroundMonitoringService.ACTION_START
                }
                val result = ForegroundServiceLauncher.safeStartForegroundService(
                    context,
                    monitorIntent,
                )
                if (result == ForegroundServiceLauncher.LaunchResult.SUCCESS) {
                    removeIncomingCallOverlay(context)
                } else {
                    NativeBridgeEventSink.sendMonitoringState(
                        "START_FAILED:backgroundStartDenied"
                    )
                }
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
            
            ObjectAnimator.ofFloat(rootLayout, "translationY", 0f).apply {
                duration = 300
                interpolator = DecelerateInterpolator()
                start()
            }
            ObjectAnimator.ofFloat(rootLayout, "alpha", 1f).apply {
                duration = 300
                start()
            }
        } catch (e: Exception) {
            incomingCallOverlayView = null
        }
    }

    fun removeIncomingCallOverlay(context: Context) {
        incomingCallOverlayView?.let {
            try { getWindowManager(context).removeView(it) } catch (_: Exception) {}
            incomingCallOverlayView = null
        }
    }
}
