package com.example.lachancuocgoi.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke

@Composable
fun CircularWaveformVisualizer(
    rmsDb: Float,
    color: Color,
    modifier: Modifier = Modifier
) {
    // Map rmsDb (-10 to 40) to normalized 0.1 - 1.0 (similar to old View logic)
    val targetNormalized = ((rmsDb + 10f).coerceAtLeast(0f) / 50f).coerceIn(0.1f, 1.0f)
    
    // Smooth transition
    val currentAmplitude by animateFloatAsState(
        targetValue = targetNormalized,
        animationSpec = tween(durationMillis = 150, easing = LinearEasing),
        label = "amplitude"
    )

    // Infinite phase for ripples
    val infiniteTransition = rememberInfiniteTransition(label = "ripple")
    val phase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = (Math.PI * 2).toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 2000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "phase"
    )

    Canvas(modifier = modifier) {
        val cx = size.width / 2f
        val cy = size.height / 2f
        val w = size.width
        val h = size.height
        if (w == 0f || h == 0f) return@Canvas
        
        val maxRadius = minOf(w, h) / 2f * 0.9f

        // Draw base circles
        val paintAlpha = 0.4f
        drawCircle(
            color = color.copy(alpha = paintAlpha),
            radius = maxRadius * 0.5f,
            center = Offset(cx, cy),
            style = Stroke(width = 2f)
        )
        drawCircle(
            color = color.copy(alpha = paintAlpha),
            radius = maxRadius * 0.8f,
            center = Offset(cx, cy),
            style = Stroke(width = 2f)
        )

        // Dynamic radius based on amplitude
        val dynamicRadius = maxRadius * 0.4f + (maxRadius * 0.6f * currentAmplitude)

        // Draw filled pulsing circle
        drawCircle(
            color = color.copy(alpha = 0.2f),
            radius = dynamicRadius,
            center = Offset(cx, cy)
        )

        // Draw active waveform outline
        drawCircle(
            color = color,
            radius = dynamicRadius,
            center = Offset(cx, cy),
            style = Stroke(width = 6f)
        )

        // Draw ripple effect rings
        val rippleCount = 3
        for (i in 0 until rippleCount) {
            val ripplePhase = (phase + i * (Math.PI / rippleCount)).toFloat() % (Math.PI * 2).toFloat()
            val normalizedPhase = ripplePhase / (Math.PI * 2).toFloat()
            val rippleRadius = maxRadius * 0.3f + (maxRadius * 0.7f * normalizedPhase)
            val rippleAlpha = (1f - normalizedPhase).coerceIn(0f, 1f)
            
            drawCircle(
                color = color.copy(alpha = rippleAlpha),
                radius = rippleRadius,
                center = Offset(cx, cy),
                style = Stroke(width = 3f)
            )
        }
    }
}
