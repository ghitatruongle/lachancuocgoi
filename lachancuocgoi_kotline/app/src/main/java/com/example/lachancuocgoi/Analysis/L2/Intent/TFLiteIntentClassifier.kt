package com.example.lachancuocgoi.Analysis.L2.Intent

import android.content.Context
import android.util.Log
import org.tensorflow.lite.InterpreterApi
import com.google.android.gms.tflite.java.TfLite
import com.google.android.gms.tasks.Tasks
import java.io.BufferedReader
import java.io.FileInputStream
import java.io.InputStreamReader
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.text.Normalizer

enum class ScamIntent {
    AUTH_POLICE_LAWSUIT,
    TAX_GOV_APP,
    TELECOM_LOCK,
    TECH_SUPPORT_HIJACK,
    HOSPITAL_EMERGENCY,
    VIRTUAL_KIDNAPPING,
    CEO_FRAUD_B2B,
    SOCIAL_DEEPFAKE_LOAN,
    ROMANCE_SCAM,
    SEXTORTION_BLACKMAIL,
    CHARITY_DONATION,
    INVESTMENT_SCAM,
    JOB_TASK_SCAM,
    GIFT_LOTTERY,
    GAMBLING_PREDICTION,
    IMMIGRATION_VISA_SCAM,
    BANK_CARD_FRAUD,
    DELIVERY_COD,
    FAKE_SUBSCRIPTION,
    BLACK_CREDIT_TERROR,
    RECOVERY_SCAM,
    GENERIC_SCAM,
    SAFE
}

data class IntentPrediction(
    val intent: ScamIntent,
    val confidence: Float
)

class TFLiteIntentClassifier(private val context: Context) {

    companion object {
        private const val TAG = "IntentClassifier"
        private const val MODEL_FILE = "ghitav3.tflite"
        private const val VOCAB_FILE = "vocab.txt"
        private const val MAX_SEQ_LEN = 256

        private const val CLS_TOKEN = "[CLS]"
        private const val SEP_TOKEN = "[SEP]"
        private const val PAD_TOKEN = "[PAD]"
        private const val UNK_TOKEN = "[UNK]"

        private val INTENT_LABELS = listOf(
            ScamIntent.AUTH_POLICE_LAWSUIT,
            ScamIntent.TAX_GOV_APP,
            ScamIntent.TELECOM_LOCK,
            ScamIntent.TECH_SUPPORT_HIJACK,
            ScamIntent.HOSPITAL_EMERGENCY,
            ScamIntent.VIRTUAL_KIDNAPPING,
            ScamIntent.CEO_FRAUD_B2B,
            ScamIntent.SOCIAL_DEEPFAKE_LOAN,
            ScamIntent.ROMANCE_SCAM,
            ScamIntent.SEXTORTION_BLACKMAIL,
            ScamIntent.CHARITY_DONATION,
            ScamIntent.INVESTMENT_SCAM,
            ScamIntent.JOB_TASK_SCAM,
            ScamIntent.GIFT_LOTTERY,
            ScamIntent.GAMBLING_PREDICTION,
            ScamIntent.IMMIGRATION_VISA_SCAM,
            ScamIntent.BANK_CARD_FRAUD,
            ScamIntent.DELIVERY_COD,
            ScamIntent.FAKE_SUBSCRIPTION,
            ScamIntent.BLACK_CREDIT_TERROR,
            ScamIntent.RECOVERY_SCAM,
            ScamIntent.GENERIC_SCAM,
            ScamIntent.SAFE
        )
    }

    private var interpreter: InterpreterApi? = null
    private val vocab = mutableMapOf<String, Int>()
    private var isReady = false
    private var hasAttemptedInit = false

    private val inputIdsBuf = ByteBuffer.allocateDirect(MAX_SEQ_LEN * 4).apply { order(ByteOrder.nativeOrder()) }
    private val maskBuf = ByteBuffer.allocateDirect(MAX_SEQ_LEN * 4).apply { order(ByteOrder.nativeOrder()) }
    private val typeIdsBuf = ByteBuffer.allocateDirect(MAX_SEQ_LEN * 4).apply { order(ByteOrder.nativeOrder()) }

    private var outputBuf: ByteBuffer? = null
    private var outScale = 1.0f
    private var outZeroPoint = 0
    private var isUint8 = false
    private var isInt8 = false

    private val logits = FloatArray(INTENT_LABELS.size)
    private val probabilities = FloatArray(INTENT_LABELS.size)

    private val inputs = arrayOf<Any>(inputIdsBuf, maskBuf, typeIdsBuf)
    private val outputs = mutableMapOf<Int, Any>()

    private var lastInputHash: Int = 0
    private var lastInputLength: Int = 0
    private var cachedResult: List<IntentPrediction> = emptyList()
    private val CACHE_CHANGE_THRESHOLD = 0.20f

    fun initialize() {
        if (!hasAttemptedInit) {
            hasAttemptedInit = true
            loadResources()
        }
    }

    fun isReady(): Boolean = isReady

    private fun loadResources() {
        try {
            Log.i(TAG, "Đang khởi tạo Google Play Services TFLite...")
            val initTask = TfLite.initialize(context)
            Tasks.await(initTask)

            loadVocab()
            loadModel()
            if (interpreter != null) {
                isReady = true
                Log.i(TAG, "✓ MobileBERT Intent Classifier sẵn sàng. Vocab: ${vocab.size} token.")
            } else {
                Log.w(TAG, "⚠ MobileBERT không hợp lệ. Fallback sang Heuristic.")
                isReady = false
            }
        } catch (e: Exception) {
            Log.e(TAG, "✗ Không thể khởi tạo MobileBERT. Fallback sang Heuristic.", e)
            isReady = false
        }
    }

    private fun loadVocab() {
        context.assets.open(VOCAB_FILE).bufferedReader().useLines { lines ->
            lines.forEachIndexed { index, token ->
                vocab[token.trim()] = index
            }
        }
        Log.d(TAG, "Load vocab: ${vocab.size} entries.")
    }

    private fun loadModel() {
        val fileDescriptor = context.assets.openFd(MODEL_FILE)
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel
        val startOffset = fileDescriptor.startOffset
        val declaredLength = fileDescriptor.declaredLength
        val modelBuffer: MappedByteBuffer = fileChannel.map(
            FileChannel.MapMode.READ_ONLY, startOffset, declaredLength
        )
        fileChannel.close()
        inputStream.close()
        fileDescriptor.close()

        val options = InterpreterApi.Options().apply {
            setRuntime(InterpreterApi.Options.TfLiteRuntime.FROM_SYSTEM_ONLY)
            setNumThreads(Runtime.getRuntime().availableProcessors().coerceAtMost(4))
            setUseXNNPACK(true)
        }
        interpreter = InterpreterApi.create(modelBuffer, options)
        Log.i(TAG, "MobileBERT model loaded: $MODEL_FILE (${declaredLength / 1024}KB)")

        val outputTensor = interpreter!!.getOutputTensor(0)
        val shape = outputTensor.shape()
        val numClasses = shape.last()
        if (numClasses != INTENT_LABELS.size) {
            Log.e(TAG, "Model output size ($numClasses) does not match required classes (${INTENT_LABELS.size}). TFLite inference will be disabled.")
            interpreter?.close()
            interpreter = null
            isReady = false
            return
        }

        val dataType = outputTensor.dataType()
        isUint8 = (dataType == org.tensorflow.lite.DataType.UINT8)
        isInt8 = (dataType == org.tensorflow.lite.DataType.INT8)

        if (isUint8 || isInt8) {
            val params = outputTensor.quantizationParams()
            outScale = params?.scale ?: 1.0f
            outZeroPoint = params?.zeroPoint ?: 0
            outputBuf = ByteBuffer.allocateDirect(INTENT_LABELS.size).apply { order(ByteOrder.nativeOrder()) }
            Log.i(TAG, "Model output quantized ($dataType). Scale: $outScale, ZP: $outZeroPoint")
        } else {
            outputBuf = ByteBuffer.allocateDirect(4 * INTENT_LABELS.size).apply { order(ByteOrder.nativeOrder()) }
            Log.i(TAG, "Model output is Float32.")
        }
        outputs[0] = outputBuf!!
    }

    fun predictIntent(transcript: String): List<IntentPrediction> {
        if (!isReady) {
            throw IllegalStateException("TFLite Model chưa sẵn sàng. Gửi tín hiệu 10101.")
        }
        if (transcript.isBlank()) {
            return emptyList()
        }

        val currentHash = transcript.hashCode()
        val lengthDelta = transcript.length - lastInputLength
        val changeRatio = if (lastInputLength > 0) lengthDelta.toFloat() / lastInputLength else 1.0f

        if (currentHash == lastInputHash) {
            return cachedResult
        }
        if (cachedResult.isNotEmpty() && changeRatio < CACHE_CHANGE_THRESHOLD && changeRatio >= 0) {
            Log.d(TAG, "Cache hit: text changed ${(changeRatio * 100).toInt()}% (< ${(CACHE_CHANGE_THRESHOLD * 100).toInt()}%), skipping inference")
            return cachedResult
        }

        val result = runInference(transcript)

        lastInputHash = currentHash
        lastInputLength = transcript.length
        cachedResult = result

        return result
    }

    private fun runInference(text: String): List<IntentPrediction> {

        val normalized = normalizeVietnamese(text)
        val tokens = tokenize(normalized)

        val (inputIds, attentionMask, tokenTypeIds) = buildBertInputs(tokens)

        inputIdsBuf.clear()
        inputIds.forEach { inputIdsBuf.putInt(it) }
        inputIdsBuf.rewind()

        maskBuf.clear()
        attentionMask.forEach { maskBuf.putInt(it) }
        maskBuf.rewind()

        typeIdsBuf.clear()
        tokenTypeIds.forEach { typeIdsBuf.putInt(it) }
        typeIdsBuf.rewind()

        val outBuffer = outputBuf!!
        outBuffer.clear()

        interpreter!!.runForMultipleInputsOutputs(inputs, outputs)

        outBuffer.rewind()
        val expectedBytes = if (isUint8 || isInt8) INTENT_LABELS.size else INTENT_LABELS.size * 4
        if (outBuffer.remaining() < expectedBytes) {
            Log.e(TAG, "BUG 7 GUARD: Output buffer size mismatch! " +
                    "remaining=${outBuffer.remaining()}, expected=$expectedBytes, " +
                    "isUint8=$isUint8, isInt8=$isInt8. Skipping inference.")
            return emptyList()
        }

        if (isUint8) {
            for (i in logits.indices) {
                val quantizedVal = outBuffer.get().toInt() and 0xFF
                logits[i] = (quantizedVal - outZeroPoint) * outScale
            }
        } else if (isInt8) {
            for (i in logits.indices) {
                val quantizedVal = outBuffer.get().toInt()
                logits[i] = (quantizedVal - outZeroPoint) * outScale
            }
        } else {
            for (i in logits.indices) {
                logits[i] = outBuffer.float
            }
        }

        softmaxInPlace(logits, probabilities)

        return INTENT_LABELS.mapIndexed { index, intent ->
            IntentPrediction(intent, probabilities[index])
        }.sortedByDescending { it.confidence }
    }

    private fun normalizeVietnamese(text: String): String {
        return text.lowercase()
            .replace(Regex("[^\\p{L}\\p{N}\\s]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    private fun tokenize(text: String): List<String> {
        val result = mutableListOf<String>()
        for (word in text.split(" ")) {
            if (word.isBlank()) continue

            if (vocab.containsKey(word)) {
                result.add(word)
                continue
            }

            var subwords = wordPieceTokenize(word)

            if (subwords.size == 1 && subwords[0] == UNK_TOKEN) {
                val accentRemoved = removeAccents(word)
                if (accentRemoved != word) {
                    if (vocab.containsKey(accentRemoved)) {
                        subwords = listOf(accentRemoved)
                    } else {
                        subwords = wordPieceTokenize(accentRemoved)
                    }
                }
            }
            result.addAll(subwords)
        }
        return result
    }

    private fun removeAccents(text: String): String {
        val normalized = Normalizer.normalize(text, Normalizer.Form.NFD)
        return Regex("\\p{InCombiningDiacriticalMarks}+").replace(normalized, "")
            .replace('đ', 'd').replace('Đ', 'D')
    }

    private fun wordPieceTokenize(word: String): List<String> {
        val subTokens = mutableListOf<String>()
        var start = 0
        var isBad = false

        while (start < word.length) {
            var end = word.length
            var curSubStr: String? = null

            while (start < end) {
                val substr = if (start > 0) "##${word.substring(start, end)}" else word.substring(start, end)
                if (vocab.containsKey(substr)) {
                    curSubStr = substr
                    break
                }
                end -= 1
            }

            if (curSubStr == null) {
                isBad = true
                break
            }
            subTokens.add(curSubStr)
            start = end
        }

        return if (isBad) listOf(UNK_TOKEN) else subTokens
    }

    private fun buildBertInputs(tokens: List<String>): Triple<IntArray, IntArray, IntArray> {
        val clsId = vocab[CLS_TOKEN] ?: 101
        val sepId = vocab[SEP_TOKEN] ?: 102
        val padId = vocab[PAD_TOKEN] ?: 0
        val unkId = vocab[UNK_TOKEN] ?: 100

        val maxTokens = MAX_SEQ_LEN - 2
        val truncatedTokens = if (tokens.size <= maxTokens) {
            tokens
        } else {
            val head = tokens.take(50)
            val tail = tokens.takeLast(maxTokens - 50)
            head + tail
        }

        val inputIds = IntArray(MAX_SEQ_LEN) { padId }
        val attentionMask = IntArray(MAX_SEQ_LEN) { 0 }
        val tokenTypeIds = IntArray(MAX_SEQ_LEN) { 0 }

        inputIds[0] = clsId
        attentionMask[0] = 1

        truncatedTokens.forEachIndexed { i, token ->
            inputIds[i + 1] = vocab[token] ?: unkId
            attentionMask[i + 1] = 1
        }

        val sepPos = truncatedTokens.size + 1
        inputIds[sepPos] = sepId
        attentionMask[sepPos] = 1

        return Triple(inputIds, attentionMask, tokenTypeIds)
    }

    private fun softmaxInPlace(logits: FloatArray, probs: FloatArray) {
        var maxLogit = -Float.MAX_VALUE
        for (logit in logits) {
            if (logit > maxLogit) {
                maxLogit = logit
            }
        }
        var sum = 0f
        for (i in logits.indices) {
            val expVal = Math.exp((logits[i] - maxLogit).toDouble()).toFloat()
            probs[i] = expVal
            sum += expVal
        }
        for (i in probs.indices) {
            probs[i] /= sum
        }
    }

    fun close() {
        interpreter?.close()
        interpreter = null
        isReady = false
        Log.i(TAG, "TFLiteIntentClassifier đóng và giải phóng tài nguyên.")
    }
}
