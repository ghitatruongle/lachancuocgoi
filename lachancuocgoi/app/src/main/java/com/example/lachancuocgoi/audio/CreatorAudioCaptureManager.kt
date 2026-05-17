package com.example.lachancuocgoi.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * ⚠️  CHỈ DÀNH CHO DEVELOPER MODE ⚠️
 *
 * Capture audio hệ thống từ các ứng dụng VoIP (Zalo, Telegram, WhatsApp...)
 * bằng [AudioPlaybackCaptureConfiguration] (API 29+).
 *
 * Chức năng:
 *  - Lấy luồng PCM raw (16kHz, mono) từ audio đang phát trên loa hệ thống
 *  - Cung cấp [AudioRecord] để SpeechToTextManager đọc và chuyển sang text
 *  - KHÔNG lưu audio xuống disk
 *  - KHÔNG hoạt động với cuộc gọi GSM/PSTN (hardware protected)
 *
 * Cách mở khóa: Nhấn "Cài đặt" 10 lần → nhập mật mã → bật toggle trong Settings.
 *
 * Caller phải tự kiểm tra [DeveloperModeManager.isActive] trước khi gọi [startCapture].
 */
object CreatorAudioCaptureManager {

    private const val TAG = "CreatorAudioCapture"

    // PCM config — khớp với config mà SpeechToTextManager mong đợi
    const val SAMPLE_RATE = 16_000        // 16 kHz — tốt nhất cho STT tiếng Việt
    const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
    const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

    // Buffer = 320ms để cân bằng latency vs. overhead
    val BUFFER_SIZE: Int = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        .coerceAtLeast(SAMPLE_RATE * 2 * 320 / 1000)   // ≥ 320ms worth of PCM

    // ── Internal state ────────────────────────────────────────────────────────
    private val _state = MutableStateFlow(CaptureState.IDLE)
    val state: StateFlow<CaptureState> = _state.asStateFlow()

    private val _amplitudeFlow = MutableSharedFlow<Float>(extraBufferCapacity = 100)
    val amplitudeFlow = _amplitudeFlow.asSharedFlow()

    private val _creatorTranscriptFlow = MutableStateFlow("")
    val creatorTranscriptFlow = _creatorTranscriptFlow.asStateFlow()

    fun emitAmplitude(amp: Float) {
        _amplitudeFlow.tryEmit(amp)
    }

    fun updateTranscript(text: String) {
        _creatorTranscriptFlow.value = text
    }

    @Volatile private var audioRecord: AudioRecord? = null

    // ── Public API ────────────────────────────────────────────────────────────

    /**
     * Bắt đầu capture audio hệ thống từ [projection].
     *
     * @param projection MediaProjection token nhận được từ system dialog "Bắt đầu chụp màn hình?"
     * @return [AudioRecord] đang trong trạng thái RECORDING, hoặc null nếu thiết bị
     *         không hỗ trợ (API < 29) hoặc có lỗi khởi tạo.
     *
     * Caller chịu trách nhiệm đọc PCM từ AudioRecord trả về trong một coroutine riêng.
     */
    fun startCapture(projection: MediaProjection): AudioRecord? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            Log.w(TAG, "AudioPlaybackCapture requires Android 10+. Skipping.")
            _state.value = CaptureState.ERROR
            return null
        }

        if (_state.value == CaptureState.CAPTURING) {
            Log.w(TAG, "Capture already running. Call stopCapture() first.")
            return audioRecord
        }

        return try {
            startCaptureInternal(projection)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start capture", e)
            _state.value = CaptureState.ERROR
            null
        }
    }

    /**
     * Dừng capture và giải phóng tài nguyên AudioRecord.
     * An toàn để gọi nhiều lần.
     */
    fun stopCapture() {
        try {
            audioRecord?.let { record ->
                if (record.state == AudioRecord.STATE_INITIALIZED) {
                    record.stop()
                }
                record.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping AudioRecord", e)
        } finally {
            audioRecord = null
            _state.value = CaptureState.IDLE
            Log.d(TAG, "AudioPlaybackCapture stopped.")
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun startCaptureInternal(projection: MediaProjection): AudioRecord? {
        // Capture audio hệ thống cho STT.
        // - USAGE_MEDIA/GAME/UNKNOWN: nhạc, video, game
        // - USAGE_VOICE_COMMUNICATION: Android CẤM capture (privacy) → thử thêm,
        //   bắt exception nếu bị reject, fallback về config không có nó.
        // Lưu ý: AudioPlaybackCaptureConfiguration.Builder KHÔNG có addMatchingContentType.
        //   Chỉ có addMatchingUsage/addMatchingUid/excludeUid/excludeUsage.
        val captureConfig = try {
            val builder = AudioPlaybackCaptureConfiguration.Builder(projection)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            // Thử thêm VOICE_COMMUNICATION — có thể bị Android cấm
            try {
                builder.addMatchingUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                Log.d(TAG, "USAGE_VOICE_COMMUNICATION added to capture config")
            } catch (e: SecurityException) {
                Log.w(TAG, "Android cấm capture USAGE_VOICE_COMMUNICATION (expected). Fallback.")
            } catch (e: IllegalArgumentException) {
                Log.w(TAG, "USAGE_VOICE_COMMUNICATION không hỗ trợ cho AudioPlaybackCapture. Fallback.")
            }
            builder.build()
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException khi tạo capture config", e)
            _state.value = CaptureState.ERROR
            return null
        }

        val record = AudioRecord.Builder()
            .setAudioPlaybackCaptureConfig(captureConfig)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AUDIO_FORMAT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(CHANNEL_CONFIG)
                    .build()
            )
            .setBufferSizeInBytes(BUFFER_SIZE)
            .build()

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            Log.e(TAG, "AudioRecord failed to initialize. state=${record.state}")
            record.release()
            _state.value = CaptureState.ERROR
            return null
        }

        record.startRecording()
        audioRecord = record
        _state.value = CaptureState.CAPTURING
        Log.d(TAG, "AudioPlaybackCapture started. SAMPLE_RATE=$SAMPLE_RATE BUFFER=$BUFFER_SIZE")
        return record
    }

    // ── State enum ────────────────────────────────────────────────────────────

    enum class CaptureState {
        IDLE,       // Chưa khởi động
        CAPTURING,  // Đang capture
        ERROR       // Lỗi khởi tạo
    }
}
