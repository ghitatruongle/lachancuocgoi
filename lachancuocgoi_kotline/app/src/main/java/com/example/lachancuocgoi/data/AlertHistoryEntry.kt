package com.example.lachancuocgoi.data

import androidx.compose.ui.graphics.Color
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class AlertHistoryEntry(
    val timestamp: Long,
    val analysisLevel: String,
    val riskLevel: String,
    val alertCount: Int,
    val displayedReason: String,
    val allReasons: List<String>? = null
) {

    fun getFormattedTime(): String {
        val sdf = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
        return sdf.format(Date(timestamp))
    }

    fun getRiskLevelColor(): Color {
        return when (riskLevel) {
            "RED" -> Color(0xFFD32F2F)
            "ORANGE" -> Color(0xFFFF9800)
            else -> Color(0xFF9E9E9E)
        }
    }

    fun getRiskLevelIcon(): String {
        return when (riskLevel) {
            "RED" -> "🔴"
            "ORANGE" -> "🟠"
            else -> "⚪"
        }
    }
}
