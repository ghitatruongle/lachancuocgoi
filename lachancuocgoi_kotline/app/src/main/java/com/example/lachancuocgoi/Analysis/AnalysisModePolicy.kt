package com.example.lachancuocgoi.Analysis

import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.AnalysisMode

data class AnalysisRuntimeState(
    val selectedMode: AnalysisMode,
    val effectiveMode: AnalysisMode,
    val networkAvailable: Boolean,
    val isFallbackActive: Boolean
)

object AnalysisModePolicy {

    fun resolveEffectiveMode(
        selectedMode: AnalysisMode,
        networkAvailable: Boolean
    ): AnalysisMode {
        return if (selectedMode == AnalysisMode.GEMINI_API && !networkAvailable) {
            AnalysisMode.GDetection
        } else {
            selectedMode
        }
    }

    fun createRuntimeState(
        selectedMode: AnalysisMode,
        networkAvailable: Boolean
    ): AnalysisRuntimeState {
        val effectiveMode = resolveEffectiveMode(selectedMode, networkAvailable)
        return AnalysisRuntimeState(
            selectedMode = selectedMode,
            effectiveMode = effectiveMode,
            networkAvailable = networkAvailable,
            isFallbackActive = selectedMode == AnalysisMode.GEMINI_API && effectiveMode != AnalysisMode.GEMINI_API
        )
    }
}
