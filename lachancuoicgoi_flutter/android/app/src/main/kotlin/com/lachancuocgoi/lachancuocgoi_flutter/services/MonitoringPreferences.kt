package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.content.Context

object MonitoringPreferences {
    const val PREFS_NAME = "monitoring_config"
    const val KEY_ANALYSIS_MODE = "analysis_mode"
    const val KEY_AUTO_ENABLE_SPEAKERPHONE = "auto_enable_speakerphone"

    private const val DEFAULT_MODE = "GDetection"
    private const val DEFAULT_AUTO_ENABLE_SPEAKERPHONE = true
    private val allowedModes = setOf("NORMAL", "GDetection", "GEMINI_API", "PARALLEL")

    fun writeAnalysisMode(context: Context, rawMode: String) {
        val mode = rawMode.takeIf(allowedModes::contains) ?: DEFAULT_MODE
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ANALYSIS_MODE, mode)
            .apply()
    }

    fun readAnalysisMode(context: Context): String =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_ANALYSIS_MODE, DEFAULT_MODE)
            ?.takeIf(allowedModes::contains)
            ?: DEFAULT_MODE

    fun writeAutoEnableSpeakerphone(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_AUTO_ENABLE_SPEAKERPHONE, enabled)
            .apply()
    }

    fun readAutoEnableSpeakerphone(context: Context): Boolean =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_AUTO_ENABLE_SPEAKERPHONE, DEFAULT_AUTO_ENABLE_SPEAKERPHONE)

    fun displayLabel(mode: String): String = when (mode) {
        "NORMAL" -> "L1"
        "GDetection" -> "L2"
        "GEMINI_API" -> "L3"
        "PARALLEL" -> "L1 + L2 + L3"
        else -> "L2"
    }
}
