package com.example.lachancuocgoi.services

import kotlinx.coroutines.flow.StateFlow

interface SttEngine {

    fun start()

    fun stop()

    fun destroy()

    val fullTranscriptFlow: StateFlow<String>

    val textResults: StateFlow<String>

    val isListening: StateFlow<Boolean>

    val rmsDbFlow: StateFlow<Float>

    fun clearTranscript()

    val isReady: Boolean

    val name: String
}
