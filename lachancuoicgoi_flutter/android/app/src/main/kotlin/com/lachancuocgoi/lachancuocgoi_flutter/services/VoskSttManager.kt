package com.lachancuocgoi.lachancuocgoi_flutter.services

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

sealed class ModelLoadState {
    data object Loading : ModelLoadState()
    data class Ready(val sampleRate: Float) : ModelLoadState()
    data class Failed(val error: String, val retriesRemaining: Int) : ModelLoadState()
}

class VoskSttManager(private val context: Context) {
    companion object {
        private const val TAG = "VoskSttManager"
        private const val MAX_RETRIES = 3
        private const val RETRY_DELAY_MS = 5000L
        private val MODEL_ASSET_PATHS = listOf(
            "flutter_assets/assets/model-vn",
            "model-vn",
        )
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

    private fun initModel(assetPathIndex: Int = 0) {
        _modelLoadState.value = ModelLoadState.Loading
        val sourcePath = MODEL_ASSET_PATHS[assetPathIndex]
        StorageService.unpack(
            context,
            sourcePath,
            "model",
            { unpackedModel ->
                model = unpackedModel
                recognizer = Recognizer(unpackedModel, 16000.0f)
                _isReady.value = true
                retryCount = 0
                _modelLoadState.value = ModelLoadState.Ready(16000.0f)
                Log.d(TAG, "Vosk model initialized successfully")
            },
            { exception ->
                val nextAssetPathIndex = assetPathIndex + 1
                if (nextAssetPathIndex < MODEL_ASSET_PATHS.size) {
                    Log.w(
                        TAG,
                        "Failed to load Vosk model from $sourcePath, trying fallback",
                        exception,
                    )
                    initModel(nextAssetPathIndex)
                    return@unpack
                }

                retryCount++
                val retriesRemaining = MAX_RETRIES - retryCount
                _modelLoadState.value = ModelLoadState.Failed(
                    exception?.message ?: "Unknown error",
                    retriesRemaining,
                )
                Log.e(TAG, "Failed to initialize Vosk model", exception)
                if (retryCount < MAX_RETRIES) {
                    handler.postDelayed({ initModel() }, RETRY_DELAY_MS)
                }
            },
        )
    }

    fun retryLoad() {
        retryCount = 0
        initModel()
    }

    fun processAudioBuffer(buffer: ByteArray, bytesRead: Int) {
        val activeRecognizer = recognizer ?: return
        if (!_isReady.value) return

        try {
            _isProcessing.value = true
            val isFinal = activeRecognizer.acceptWaveForm(buffer, bytesRead)
            if (isFinal) {
                val resultJson = activeRecognizer.result
                val recognizedText = extractText(resultJson, "text")
                if (recognizedText.isNotBlank()) {
                    cumulativeTranscript = if (cumulativeTranscript.isBlank()) {
                        recognizedText
                    } else {
                        "$cumulativeTranscript\n$recognizedText"
                    }
                    _creatorTranscriptFlow.value = cumulativeTranscript
                }
            } else {
                val partialJson = activeRecognizer.partialResult
                val partialText = extractText(partialJson, "partial")
                if (partialText.isNotBlank()) {
                    _creatorTranscriptFlow.value = if (cumulativeTranscript.isBlank()) {
                        partialText
                    } else {
                        "$cumulativeTranscript\n$partialText"
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to process buffer in Vosk", e)
        } finally {
            _isProcessing.value = false
        }
    }

    private fun extractText(jsonString: String?, key: String): String {
        if (jsonString.isNullOrBlank()) return ""
        return try {
            JSONObject(jsonString).optString(key, "")
        } catch (_: Exception) {
            ""
        }
    }

    val isModelReady: Boolean
        get() = _isReady.value

    fun resetTranscript() {
        cumulativeTranscript = ""
        _creatorTranscriptFlow.value = ""
    }

    fun destroy() {
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
