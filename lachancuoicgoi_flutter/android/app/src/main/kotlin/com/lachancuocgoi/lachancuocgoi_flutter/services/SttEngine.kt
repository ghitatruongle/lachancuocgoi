package com.lachancuocgoi.lachancuocgoi_flutter.services

import kotlinx.coroutines.flow.StateFlow

/**
 * Interface chung cho các STT engine.
 * Cho phép SpeechToTextManager switch giữa Google (online) và Vosk (offline)
 * mà không thay đổi API public.
 */
interface SttEngine {
    /** Bắt đầu nhận diện */
    fun start()

    /** Dừng nhận diện */
    fun stop()

    /** Giải phóng tài nguyên */
    fun destroy()

    /** Flow transcript lũy kế (final results) */
    val fullTranscriptFlow: StateFlow<String>

    /** Flow kết quả từng utterance (final result gần nhất) */
    val textResults: StateFlow<String>

    /** Flow trạng thái đang nghe */
    val isListening: StateFlow<Boolean>

    /** Flow RMS dB cho waveform */
    val rmsDbFlow: StateFlow<Float>

    /** Xóa transcript */
    fun clearTranscript()

    /** Engine có sẵn sàng không? */
    val isReady: Boolean

    /** Tên engine (cho logging) */
    val name: String
}
