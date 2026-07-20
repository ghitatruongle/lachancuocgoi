package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.animation.ObjectAnimator
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.lachancuocgoi.lachancuocgoi_flutter.R

object AlertOverlayManager {

    // Bug #11, #12 fix: use OverlayWindow helper for view lifecycle + use
    // MediaPlayer guarded with try/finally to ensure release() runs even if
    // prepare() throws.
    private val overlayWindow = OverlayWindow()

    private var alarmPlayer: MediaPlayer? = null
    private val heavyVibrationHandler = Handler(Looper.getMainLooper())
    private var heavyVibrationRunnable: Runnable? = null

    private fun dpToPx(context: Context, dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            context.resources.displayMetrics
        ).toInt()
    }

    fun showRedAlert(context: Context, reason: String) {
        showAlert(context, Color.parseColor("#F44336"), "CẢNH BÁO LỪA ĐẢO!", reason, isRed = true)
    }

    fun showOrangeAlert(context: Context, reason: String) {
        showAlert(context, Color.parseColor("#FF9800"), "CẢNH BÁO NGUY CƠ", reason, isRed = false)
    }

    private fun showAlert(context: Context, color: Int, title: String, summary: String, isRed: Boolean) {
        removeAlertOverlay(context)

        val rootLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(context, 24), dpToPx(context, 24), dpToPx(context, 24), dpToPx(context, 24))

            // Slide down animation setup
            translationY = -200f
            alpha = 0f

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

            val icon = ImageView(context).apply {
                setImageResource(android.R.drawable.ic_dialog_alert)
                setColorFilter(Color.WHITE)
                val size = dpToPx(context, 48)
                layoutParams = LinearLayout.LayoutParams(size, size).apply {
                    bottomMargin = dpToPx(context, 8)
                }
            }
            card.addView(icon)

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

            val button = Button(context).apply {
                text = context.getString(R.string.alert_acknowledge)
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

        // Bug #11, #12 fix: route through OverlayWindow helper which handles
        // addView failures and the weak reference. On attach failure we
        // explicitly stop the alarm sound (Bug #12 fix) to avoid the audio
        // playing without a visible overlay.
        val attached = overlayWindow.attachOverlay(
            context,
            rootLayout,
            height = WindowManager.LayoutParams.WRAP_CONTENT,
            gravity = Gravity.CENTER,
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        )
        if (!attached) {
            android.util.Log.e("AlertOverlayManager", "Failed to attach alert overlay — stopping alarm")
            stopAlarmSound()
            stopHeavyVibration(context)
            return
        }

        // Animation
        ObjectAnimator.ofFloat(rootLayout, "translationY", 0f).apply {
            duration = 300
            interpolator = DecelerateInterpolator()
            start()
        }
        ObjectAnimator.ofFloat(rootLayout, "alpha", 1f).apply {
            duration = 300
            start()
        }

        if (isRed) {
            startHeavyVibration(context)
            playAlarmSound(context)
        } else {
            vibrate(context)
        }
    }

    fun removeAlertOverlay(context: Context) {
        stopAlarmSound()
        stopHeavyVibration(context)
        overlayWindow.detach()
    }

    private fun vibrate(context: Context) {
        try {
            val vibrator = getVibrator(context) ?: return
            vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
        } catch (_: Exception) {}
    }

    private fun startHeavyVibration(context: Context) {
        stopHeavyVibration(context)
        try {
            val vibrator = getVibrator(context) ?: return
            val pattern = longArrayOf(0, 400, 150, 400, 150, 400)
            val repeatIndex = 0

            heavyVibrationRunnable = object : Runnable {
                override fun run() {
                    try {
                        vibrator.vibrate(VibrationEffect.createWaveform(pattern, repeatIndex))
                    } catch (_: Exception) {}
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

    private fun playAlarmSound(context: Context) {
        stopAlarmSound()
        val alarmUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ?: return

        // Bug #12 fix: wrap MediaPlayer construction + setDataSource + prepare
        // in try/finally so `release()` runs even if `prepare()` throws
        // (which can happen on devices where the alarm URI is invalid or
        // the codec fails). Previously the catch block set alarmPlayer=null
        // but the partially-constructed MediaPlayer leaked.
        val player = try {
            MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(context, alarmUri)
                isLooping = true
                setVolume(1.0f, 1.0f)
                prepare()
            }
        } catch (e: Exception) {
            Log.w("AlertOverlayManager", "Failed to create MediaPlayer for alarm", e)
            null
        }
        if (player == null) return

        // Set the field BEFORE start() so any racing stopAlarmSound() call
        // sees the player and can release it.
        alarmPlayer = player
        try {
            player.start()
        } catch (e: Exception) {
            Log.w("AlertOverlayManager", "MediaPlayer.start() failed — releasing", e)
            stopAlarmSound()
        }
    }

    private fun stopAlarmSound() {
        val player = alarmPlayer
        alarmPlayer = null
        if (player == null) return
        try {
            if (player.isPlaying) player.stop()
        } catch (_: Exception) { /* ignore */ }
        try {
            player.release()
        } catch (_: Exception) { /* ignore */ }
    }

    private fun getVibrator(context: Context): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }
}
