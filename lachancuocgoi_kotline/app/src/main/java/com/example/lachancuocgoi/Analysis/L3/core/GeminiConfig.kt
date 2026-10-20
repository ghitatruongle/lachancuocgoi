package com.example.lachancuocgoi.Analysis.L3.core

data class GeminiConfig(
    val modelName: String = "gemini-2.5-flash-lite",
    val temperature: Float,
    val topK: Int,
    val topP: Float,
    val timeoutMs: Long = 7000L,
    val responseMimeType: String? = null
) {
    companion object {

        fun forAnalysis() = GeminiConfig(
            modelName = "gemini-2.5-flash-lite",
            temperature = 0.2f,
            topK = 20,
            topP = 0.9f,
            responseMimeType = "application/json"
        )

        fun forSummarization() = GeminiConfig(
            temperature = 0.7f,
            topK = 40,
            topP = 0.95f
        )
    }
}
