package com.lachancuocgoi.lachancuocgoi_flutter.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import kotlin.math.abs

/** Lightweight native waveform used by the compact monitoring overlay. */
class MonitoringWaveformView(context: Context) : View(context) {
    private val samples = FloatArray(SAMPLE_COUNT) { MIN_AMPLITUDE }
    private var writeIndex = 0
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#2E7DFF")
        strokeCap = Paint.Cap.ROUND
        strokeWidth = resources.displayMetrics.density * 2f
    }

    fun addRms(rms: Float) {
        // Android SpeechRecognizer normally reports roughly -60..0 dB. Some
        // OEM engines report a positive magnitude, so support both shapes.
        val normalized = if (rms <= 0f) {
            ((rms + 60f) / 60f).coerceIn(MIN_AMPLITUDE, 1f)
        } else {
            (abs(rms) / 12f).coerceIn(MIN_AMPLITUDE, 1f)
        }
        samples[writeIndex] = normalized
        writeIndex = (writeIndex + 1) % SAMPLE_COUNT
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (width <= 0 || height <= 0) return
        val centerY = height / 2f
        val spacing = width.toFloat() / SAMPLE_COUNT
        for (index in 0 until SAMPLE_COUNT) {
            val sampleIndex = (writeIndex + index) % SAMPLE_COUNT
            val halfHeight = samples[sampleIndex] * height * 0.42f
            val x = spacing * index + spacing / 2f
            canvas.drawLine(x, centerY - halfHeight, x, centerY + halfHeight, paint)
        }
    }

    private companion object {
        const val SAMPLE_COUNT = 32
        const val MIN_AMPLITUDE = 0.08f
    }
}
