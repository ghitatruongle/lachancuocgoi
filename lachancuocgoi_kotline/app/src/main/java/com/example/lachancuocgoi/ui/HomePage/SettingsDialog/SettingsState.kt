package com.example.lachancuocgoi.ui.HomePage.SettingsDialog

data class SettingsState(
    val isDarkTheme: Boolean,
    val analysisMode: AnalysisMode, // Thay thế AnalysisSensitivity
    val audioBoost: Boolean,
    /**
     * Chỉ khả dụng trong Developer Mode (DeveloperModeManager.isActive).
     * Khi bật: capture audio hệ thống qua MediaProjection/AudioPlaybackCapture
     * thay vì chỉ dùng microphone, giúp lấy được giọng cả 2 đầu cuộc gọi VoIP.
     * KHÔNG hiển thị và KHÔNG có tác dụng với người dùng phổ thông.
     */
    val creatorAudioCapture: Boolean = false
)
