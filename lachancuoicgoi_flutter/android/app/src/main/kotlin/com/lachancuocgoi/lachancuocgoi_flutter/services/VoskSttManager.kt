package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.StorageService

sealed class ModelLoadState {
    data object Loading : ModelLoadState()
    data class Ready(val sampleRate: Float) : ModelLoadState()
    data class Failed(val error: String, val retriesRemaining: Int) : ModelLoadState()
}

class VoskSttManager(
    private val context: Context,
    private val recognizerFactory: (Model, Float) -> Recognizer = { model, sampleRate ->
        Recognizer(model, sampleRate)
    }
) {
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
    private val modelScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    @Volatile private var isDestroyed = false

    private val _creatorTranscriptFlow = MutableStateFlow("")
    val creatorTranscriptFlow: StateFlow<String> = _creatorTranscriptFlow.asStateFlow()

    private val _voskFullTranscript = MutableStateFlow("")
    val voskFullTranscript: StateFlow<String> = _voskFullTranscript.asStateFlow()

    private val _voskTextResults = MutableStateFlow("")
    val voskTextResults: StateFlow<String> = _voskTextResults.asStateFlow()

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
        if (isDestroyed) return
        _modelLoadState.value = ModelLoadState.Loading
        val sourcePath = MODEL_ASSET_PATHS[assetPathIndex]
        StorageService.unpack(
            context,
            sourcePath,
            "model",
            { unpackedModel ->
                if (isDestroyed) {
                    try { unpackedModel.close() } catch (_: Exception) {}
                    return@unpack
                }
                modelScope.launch {
                    try {
                        val newRecognizer = recognizerFactory(unpackedModel, 16000.0f)
                        if (isDestroyed) {
                            try { unpackedModel.close() } catch (_: Exception) {}
                            try { newRecognizer.close() } catch (_: Exception) {}
                            return@launch
                        }
                        handler.post {
                            if (isDestroyed) {
                                try { unpackedModel.close() } catch (_: Exception) {}
                                try { newRecognizer.close() } catch (_: Exception) {}
                                return@post
                            }
                            val oldModel = model
                            model = unpackedModel
                            recognizer = newRecognizer
                            oldModel?.close()
                            _isReady.value = true
                            retryCount = 0
                            _modelLoadState.value = ModelLoadState.Ready(16000.0f)
                            Log.d(TAG, "Vosk model initialized successfully")
                        }
                    } catch (e: Exception) {
                        try { unpackedModel.close() } catch (_: Exception) {}
                        Log.e(TAG, "Failed to create Vosk Recognizer in background", e)
                        handler.post {
                            if (isDestroyed) return@post
                            val nextAssetPathIndex = assetPathIndex + 1
                            if (nextAssetPathIndex < MODEL_ASSET_PATHS.size) {
                                Log.w(
                                    TAG,
                                    "Failed to load Vosk model from $sourcePath, trying fallback",
                                    e,
                                )
                                initModel(nextAssetPathIndex)
                            } else {
                                retryCount++
                                val retriesRemaining = MAX_RETRIES - retryCount
                                _modelLoadState.value = ModelLoadState.Failed(
                                    e.message ?: "Failed to create recognizer",
                                    retriesRemaining,
                                )
                                if (retryCount < MAX_RETRIES) {
                                    handler.postDelayed({ initModel() }, RETRY_DELAY_MS)
                                }
                            }
                        }
                    }
                }
            },
            { exception ->
                if (isDestroyed) return@unpack
                val nextAssetPathIndex = assetPathIndex + 1
                if (nextAssetPathIndex < MODEL_ASSET_PATHS.size) {
                    Log.w(
                        TAG,
                        "Failed to unpack Vosk model from $sourcePath, trying fallback",
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
                Log.e(TAG, "Failed to unpack Vosk model", exception)
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
                    _voskFullTranscript.value = cumulativeTranscript
                    _voskTextResults.value = ""
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
                    _voskTextResults.value = partialText
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
        _voskFullTranscript.value = ""
        _voskTextResults.value = ""
    }

    fun destroy() {
        isDestroyed = true
        handler.removeCallbacksAndMessages(null)
        try {
            modelScope.cancel()
        } catch (_: Exception) {}
        recognizer?.close()
        recognizer = null
        model?.close()
        model = null
        _isReady.value = false
        _isProcessing.value = false
        _modelLoadState.value = ModelLoadState.Loading
    }
}
