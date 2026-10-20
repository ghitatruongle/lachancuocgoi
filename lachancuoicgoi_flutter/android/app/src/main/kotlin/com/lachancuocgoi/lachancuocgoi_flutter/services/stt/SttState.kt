package com.lachancuocgoi.lachancuocgoi_flutter.services.stt

sealed class SttState {
    object Idle : SttState()
    object Listening : SttState()
    data class Error(val message: String, val recoverable: Boolean) : SttState()
    object Stopped : SttState()
}

