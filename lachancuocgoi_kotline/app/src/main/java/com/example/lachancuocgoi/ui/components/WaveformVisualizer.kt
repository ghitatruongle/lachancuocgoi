package com.example.lachancuocgoi.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import kotlin.random.Random

@Composable
fun WaveformVisualizer(
    rmsDb: Float,
    tick: Int,
    color: Color,
    modifier: Modifier = Modifier
) {
    val barCount = 40
    // Keep history of magnitudes
    val magnitudes = remember { mutableStateListOf(*Array(barCount) { 0.1f }) }

    // Update history when tick changes
    LaunchedEffect(tick) {
        val targetNormalized = ((rmsDb + 10f).coerceAtLeast(0f) / 50f).coerceIn(0.1f, 1.0f)
        magnitudes.removeAt(0)
        // Add some random organic variance to end bar
        magnitudes.add(targetNormalized * (0.8f + Random.nextFloat() * 0.4f))
    }

    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        if (w == 0f || h == 0f) return@Canvas

        val totalBarWidth = w / barCount
        val gap = totalBarWidth * 0.4f
        val barWidth = totalBarWidth - gap

        val centerY = h / 2f
        val maxAmplitude = h / 2f * 0.9f

        for (i in 0 until barCount) {
            val x = i * totalBarWidth + totalBarWidth / 2f
            
            var safeAmplitude = magnitudes.getOrNull(i) ?: 0.1f
            if (safeAmplitude < 0.1f) safeAmplitude = 0.1f
            
            val barHeight = safeAmplitude * maxAmplitude

            drawLine(
                color = color,
                start = Offset(x, centerY + barHeight),
                end = Offset(x, centerY - barHeight),
                strokeWidth = barWidth,
                cap = StrokeCap.Round
            )
        }
    }
}
