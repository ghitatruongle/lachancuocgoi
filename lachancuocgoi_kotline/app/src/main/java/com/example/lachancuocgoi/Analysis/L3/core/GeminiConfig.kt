package com.example.lachancuocgoi.Analysis.L3.core

/**
 * Configuration cho Gemini model.
 * Tách riêng config để dễ dàng tune parameters và testing.
 */
data class GeminiConfig(
    val modelName: String = "gemini-2.5-flash-lite",
    val temperature: Float,
    val topK: Int,
    val topP: Float,
    val timeoutMs: Long = 7000L,
    val responseMimeType: String? = null
) {
    companion object {
        /**
         * Config tối ưu cho phân tích lừa đảo.
         * Cần độ chính xác và consistency cao.
         */
        fun forAnalysis() = GeminiConfig(
            modelName = "gemini-2.5-flash-lite",
            temperature = 0.2f,  // Low variance cho kết quả ổn định
            topK = 20,          // Moderate choices
            topP = 0.9f,        // Balance giữa deterministic và flexibility
            responseMimeType = "application/json" // Yêu cầu trả về JSON structure cho GD2
        )
        
        /**
         * Config tối ưu cho tóm tắt cuộc gọi.
         * Cho phép creativity cao hơn để tạo summaries đa dạng.
         */
        fun forSummarization() = GeminiConfig(
            temperature = 0.7f,  // Higher creativity
            topK = 40,          // More variations
            topP = 0.95f        // High diversity
        )
    }
}
