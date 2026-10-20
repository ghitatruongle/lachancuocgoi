package com.example.lachancuocgoi.Analysis

interface Analyzer : HealthCheckable {

    val level: AnalysisLevel

    suspend fun initialize()

    fun isReady(): Boolean

    fun resetSession()

    fun getProcessedTextLength(): Int

    fun syncProcessedTextLength(length: Int)

    fun getLastResult(): AnalysisResult
}
