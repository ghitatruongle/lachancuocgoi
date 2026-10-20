package com.example.lachancuocgoi.ui.HomePage.SettingsDialog

data class SettingsState(
    val isDarkTheme: Boolean,
    val analysisMode: AnalysisMode,
    val audioBoost: Boolean,

    val creatorAudioCapture: Boolean = false
)
