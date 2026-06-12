package com.example.lachancuocgoi.services

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.StorageService
import java.io.IOException

sealed class ModelLoadState {
    object Loading : ModelLoadState()
    data class Ready(val sampleRate: Float) : ModelLoadState()
    data class Failed(val error: String, val retriesRemaining: Int) : ModelLoadState()
}

class VoskSttManager(private val context: Context) {
    companion object {
        private const val TAG = "VoskSttManager"
        private const val MAX_RETRIES = 3
        private const val RETRY_DELAY_MS = 5000L
    }

    private var model: Model? = null
    private var recognizer: Recognizer? = null
    private val handler = Handler(Looper.getMainLooper())

    private val _creatorTranscriptFlow = MutableStateFlow("")
    val creatorTranscriptFlow: StateFlow<String> = _creatorTranscriptFlow.asStateFlow()

    private val _modelLoadState = MutableStateFlow<ModelLoadState>(ModelLoadState.Loading)
    val modelLoadState: StateFlow<ModelLoadState> = _modelLoadState.asStateFlow()

    private val _isReady = MutableStateFlow(false)
    val isReady: StateFlow<Boolean> = _isReady.asStateFlow()

    private val _isProcessing = MutableStateFlow(false)
    val isProcessing: StateFlow<Boolean> = _isProcessing.asStateFlow()

    private var cumulativeTranscript = ""
    private var retryCount = 0

    init {
        initModel()
    }

    private fun initModel() {
        _modelLoadState.value = ModelLoadState.Loading
        Log.d(TAG, "Bắt đầu giải nén và khởi tạo mô hình Vosk Offline... (lần ${retryCount + 1}/$MAX_RETRIES)")
        StorageService.unpack(context, "model-vn", "model",
            { model ->
                this.model = model
                // Khởi tạo recognizer với tần số 16kHz (Khớp với chuẩn lấy mẫu của AudioPlaybackCapture)
                this.recognizer = Recognizer(model, 16000.0f)
                this._isReady.value = true
                this.retryCount = 0
                this._modelLoadState.value = ModelLoadState.Ready(16000.0f)
                Log.d(TAG, "Khởi tạo mô hình Vosk thành công!")
            },
            { exception ->
                Log.e(TAG, "Lỗi giải nén mô hình nhận diện giọng nói", exception)
                retryCount++
                val remaining = MAX_RETRIES - retryCount
                _modelLoadState.value = ModelLoadState.Failed(
                    exception?.message ?: "Unknown error",
                    remaining
                )
                if (retryCount < MAX_RETRIES) {
                    Log.w(TAG, "Thử lại sau ${RETRY_DELAY_MS}ms... (còn $remaining lần)")
                    handler.postDelayed({ initModel() }, RETRY_DELAY_MS)
                } else {
                    Log.e(TAG, "Đã thử $MAX_RETRIES lần. Không thể load mô hình Vosk.")
                }
            }
        )
    }

    /** User có thể thử lại từ UI sau khi model load fail */
    fun retryLoad() {
        retryCount = 0
        initModel()
    }

    fun processAudioBuffer(buffer: ByteArray, bytesRead: Int) {
        if (!_isReady.value || recognizer == null) return

        try {
            _isProcessing.value = true
            val isFinal = recognizer!!.acceptWaveForm(buffer, bytesRead)
            
            if (isFinal) {
                // Nhận dạng xong khối âm thanh (Final result chốt câu)
                val resultJson = recognizer!!.result
                val recognizedText = extractText(resultJson, "text")
                if (recognizedText.isNotBlank()) {
                    cumulativeTranscript = if (cumulativeTranscript.isBlank()) recognizedText else "$cumulativeTranscript\n$recognizedText"
                    _creatorTranscriptFlow.value = cumulativeTranscript
                }
            } else {
                // Nhận dạng luồng trực tiếp liên tục (Partial result)
                val partialJson = recognizer!!.partialResult
                val partialText = extractText(partialJson, "partial")
                if (partialText.isNotBlank()) {
                    val currentPreview = if (cumulativeTranscript.isBlank()) partialText else "$cumulativeTranscript\n$partialText"
                    _creatorTranscriptFlow.value = currentPreview
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi chèn byte âm thanh vào Vosk", e)
        } finally {
            _isProcessing.value = false
        }
    }

    private fun extractText(jsonString: String?, key: String): String {
        if (jsonString.isNullOrBlank()) return ""
        return try {
            val jsonObject = JSONObject(jsonString)
            jsonObject.optString(key, "")
        } catch (e: Exception) {
            ""
        }
    }

    val isModelReady: Boolean get() = _isReady.value

    fun resetTranscript() {
        cumulativeTranscript = ""
        _creatorTranscriptFlow.value = ""
    }

    fun destroy() {
        Log.d(TAG, "Tiến hành giải phóng RAM C/C++ cho Vosk...")
        handler.removeCallbacksAndMessages(null)
        recognizer?.close()
        recognizer = null
        model?.close()
        model = null
        _isReady.value = false
        _isProcessing.value = false
        _modelLoadState.value = ModelLoadState.Loading
    }
}
