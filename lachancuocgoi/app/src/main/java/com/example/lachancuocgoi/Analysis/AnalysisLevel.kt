package com.example.lachancuocgoi.Analysis

/**
 * Type-safe representation of analysis engine level.
 * Thay thế magic strings ("L1", "L2", "L2-AI", "L3") bằng sealed class
 * để compiler bắt lỗi thiếu case trong when-expression.
 */
sealed class AnalysisLevel {
    /** L1: Keyword Trie + Aho-Corasick matching */
    object L1 : AnalysisLevel() {
        override fun toString() = "L1"
    }

    /** L2: GDetection Engine (keyword + pattern + scenario) */
    object L2 : AnalysisLevel() {
        override fun toString() = "L2"
    }

    /** L2-AI: GDetection với Intent Classification (TFLite) */
    object L2AI : AnalysisLevel() {
        override fun toString() = "L2-AI"
    }

    /** L2-Fused: GDetection + WFSA kết hợp */
    object L2Fused : AnalysisLevel() {
        override fun toString() = "L2-Fused"
    }

    /** L3: Gemini API analysis */
    object L3 : AnalysisLevel() {
        override fun toString() = "L3"
    }

    companion object {
        /** Parse từ string (cho backward compatibility với saved data) */
        fun fromString(value: String): AnalysisLevel = when {
            value == "L1" -> L1
            value == "L2-AI" -> L2AI
            value == "L2-Fused" -> L2Fused
            value.startsWith("L2") -> L2
            value == "L3" -> L3
            else -> L1
        }
    }
}
