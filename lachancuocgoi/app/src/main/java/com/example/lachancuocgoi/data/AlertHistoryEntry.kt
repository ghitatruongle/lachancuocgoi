package com.example.lachancuocgoi.data

import androidx.compose.ui.graphics.Color
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Đại diện cho một lần hiển thị cảnh báo (batch hoặc immediate).
 * Được lưu trữ trong lịch sử cuộc gọi để tracking.
 */
data class AlertHistoryEntry(
    val timestamp: Long,                // Thời điểm hiển thị cảnh báo
    val analysisLevel: String,          // "L1", "L2", "L3"
    val riskLevel: String,              // "RED", "ORANGE"
    val alertCount: Int,                // Số cảnh báo trong batch (1 nếu L3)
    val displayedReason: String,        // Lý do cảnh báo được hiển thị
    val allReasons: List<String>? = null // Tất cả lý do trong batch (null nếu L3)
) {
    /**
     * Format timestamp thành HH:mm:ss
     */
    fun getFormattedTime(): String {
        val sdf = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
        return sdf.format(Date(timestamp))
    }
    
    /**
     * Lấy màu tương ứng với risk level
     */
    fun getRiskLevelColor(): Color {
        return when (riskLevel) {
            "RED" -> Color(0xFFD32F2F)
            "ORANGE" -> Color(0xFFFF9800)
            else -> Color(0xFF9E9E9E)
        }
    }
    
    /**
     * Lấy icon emoji tương ứng
     */
    fun getRiskLevelIcon(): String {
        return when (riskLevel) {
            "RED" -> "🔴"
            "ORANGE" -> "🟠"
            else -> "⚪"
        }
    }
}
