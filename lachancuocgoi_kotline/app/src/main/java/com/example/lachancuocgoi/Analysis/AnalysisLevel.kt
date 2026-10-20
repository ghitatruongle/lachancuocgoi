package com.example.lachancuocgoi.Analysis

sealed class AnalysisLevel {

    object L1 : AnalysisLevel() {
        override fun toString() = "L1"
    }

    object L2 : AnalysisLevel() {
        override fun toString() = "L2"
    }

    object L2AI : AnalysisLevel() {
        override fun toString() = "L2-AI"
    }

    object L2Fused : AnalysisLevel() {
        override fun toString() = "L2-Fused"
    }

    object L3 : AnalysisLevel() {
        override fun toString() = "L3"
    }

    companion object {

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
