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
    AUTH_POLICE_LAWSUIT,       // 1. Giả danh công an, tòa án, viện kiểm sát
    TAX_GOV_APP,              // 2. Thuế, VNeID giả, dịch vụ công
    TELECOM_LOCK,             // 3. Dọa khóa SIM, nhà mạng
    TECH_SUPPORT_HIJACK,      // 4. Hỗ trợ kỹ thuật giả (Zalo/FB hack)
    HOSPITAL_EMERGENCY,       // 5. Bệnh viện, viện phí gấp
    VIRTUAL_KIDNAPPING,       // 6. Bắt cóc ảo, đe dọa tính mạng
    CEO_FRAUD_B2B,            // 7. Deepvoice sếp mượn tiền
    SOCIAL_DEEPFAKE_LOAN,     // 8. Deepfake bạn bè mượn tiền
    ROMANCE_SCAM,             // 9. Lừa tình, bưu kiện kẹt hải quan
    SEXTORTION_BLACKMAIL,     // 10. Tống tiền ảnh/clip nhạy cảm
    CHARITY_DONATION,         // 11. Từ thiện ảo, quyên góp
    INVESTMENT_SCAM,          // 12. Đầu tư tiền ảo, Forex
    JOB_TASK_SCAM,            // 13. Tuyển CTV, việc làm online
    GIFT_LOTTERY,             // 14. Trúng thưởng, tri ân
    GAMBLING_PREDICTION,      // 15. Lô đề, dự đoán số
    IMMIGRATION_VISA_SCAM,    // 16. Bao đậu Visa, XKLĐ
    BANK_CARD_FRAUD,          // 17. Ngân hàng giả, thẻ khóa
    DELIVERY_COD,             // 18. Shipper nợ tiền, hoàn phí bưu điện
    FAKE_SUBSCRIPTION,        // 19. Trừ tiền tự động, gói VIP
    BLACK_CREDIT_TERROR,      // 20. Tín dụng đen, khủng bố đòi nợ
    RECOVERY_SCAM,            // 21. Dịch vụ hỗ trợ lấy lại tiền bị lừa
    GENERIC_SCAM,             // 22. Lừa đảo chung chung (đầu tư, chuyển khoản, trúng thưởng...)
    SAFE                      // 23. Hội thoại bình thường / an toàn
}

data class IntentPrediction(
    val intent: ScamIntent,
    val confidence: Float // Từ 0.0 đến 1.0
)

/**
 * Phân loại ý định cuộc gọi sử dụng MobileBERT (TFLite - Quantized).
 *
 * Kiến trúc: WordPiece Tokenizer (Vietnamese vocab) → MobileBERT → Softmax → 22 Scam Categories + SAFE
 *
 * Input tensors:
 *   [0] input_ids     : [1, MAX_SEQ_LEN] int32
 *   [1] attention_mask: [1, MAX_SEQ_LEN] int32
 *   [2] token_type_ids: [1, MAX_SEQ_LEN] int32
 * Output tensor:
 *   [0] logits        : [1, 23] float32  (22 nhóm lừa đảo + SAFE)
 */
class TFLiteIntentClassifier(private val context: Context) {

    companion object {
        private const val TAG = "IntentClassifier"
        private const val MODEL_FILE = "ghitav3.tflite"
        private const val VOCAB_FILE = "vocab.txt"
        private const val MAX_SEQ_LEN = 256

        // Các token đặc biệt của BERT
        private const val CLS_TOKEN = "[CLS]"
        private const val SEP_TOKEN = "[SEP]"
        private const val PAD_TOKEN = "[PAD]"
        private const val UNK_TOKEN = "[UNK]"

        // Mapping nhãn đầu ra — thứ tự phải khớp chính xác với output logits của model
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

    // Pre-allocated buffers cho Inference (Tránh Garbage Collection trashing)
    private val inputIdsBuf = ByteBuffer.allocateDirect(MAX_SEQ_LEN * 4).apply { order(ByteOrder.nativeOrder()) }
    private val maskBuf = ByteBuffer.allocateDirect(MAX_SEQ_LEN * 4).apply { order(ByteOrder.nativeOrder()) }
    private val typeIdsBuf = ByteBuffer.allocateDirect(MAX_SEQ_LEN * 4).apply { order(ByteOrder.nativeOrder()) }
    
    // Thuộc tính để nhận diện Quantization Model
    private var outputBuf: ByteBuffer? = null
    private var outScale = 1.0f
    private var outZeroPoint = 0
    private var isUint8 = false
    private var isInt8 = false
    
    private val logits = FloatArray(INTENT_LABELS.size)
    private val probabilities = FloatArray(INTENT_LABELS.size)

    private val inputs = arrayOf<Any>(inputIdsBuf, maskBuf, typeIdsBuf)
    private val outputs = mutableMapOf<Int, Any>()

    // [E1] Inference cache — tránh re-run MobileBERT khi text thay đổi ít
    private var lastInputHash: Int = 0
    private var lastInputLength: Int = 0
    private var cachedResult: List<IntentPrediction> = emptyList()
    private val CACHE_CHANGE_THRESHOLD = 0.20f // Re-run nếu > 20% text mới

    // Đã chuyển loadResources sang initialize() để tránh tự động khởi động khi không cần thiết
    fun initialize() {
        if (!hasAttemptedInit) {
            hasAttemptedInit = true
            loadResources()
        }
    }

    fun isReady(): Boolean = isReady

    // =========================================================================
    // KHỞI TẠO MÔ HÌNH
    // =========================================================================

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

    /**
     * Load từ điển WordPiece từ assets/vocab.txt.
     * Mỗi dòng là một token, index = số thứ tự dòng.
     */
    private fun loadVocab() {
        context.assets.open(VOCAB_FILE).bufferedReader().useLines { lines ->
            lines.forEachIndexed { index, token ->
                vocab[token.trim()] = index
            }
        }
        Log.d(TAG, "Load vocab: ${vocab.size} entries.")
    }

    /**
     * Load model TFLite từ assets vào bộ nhớ ánh xạ (MappedByteBuffer).
     * Tắt NNAPI nếu không tương thích thiết bị.
     */
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
            setRuntime(InterpreterApi.Options.TfLiteRuntime.FROM_SYSTEM_ONLY) // Buộc lấy TFLite engine từ Google Play Services
            setNumThreads(Runtime.getRuntime().availableProcessors().coerceAtMost(4))
            setUseXNNPACK(true)  // Tăng tốc trên CPU ARM (thiết bị Android hiện đại)
        }
        interpreter = InterpreterApi.create(modelBuffer, options)
        Log.i(TAG, "MobileBERT model loaded: $MODEL_FILE (${declaredLength / 1024}KB)")

        // Validate model output shape và chuẩn bị Tensor
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

        // Tự động kiểm tra DataType để cấp phát Buffer và xuất Params Dequantize
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

    // =========================================================================
    // INFERENCE CHÍNH
    // =========================================================================

    /**
     * Dự đoán ý định của đoạn hội thoại tiếng Việt.
     * @param transcript Đoạn text cần phân loại (1-3 câu)
     * @return Danh sách IntentPrediction đã được sắp xếp theo confidence giảm dần
     */
    fun predictIntent(transcript: String): List<IntentPrediction> {
        if (!isReady) {
            throw IllegalStateException("TFLite Model chưa sẵn sàng. Gửi tín hiệu 10101.")
        }
        if (transcript.isBlank()) {
            return emptyList()
        }
        
        // [E1] Cache check: Chỉ re-inference khi text thay đổi đáng kể
        val currentHash = transcript.hashCode()
        val lengthDelta = transcript.length - lastInputLength
        val changeRatio = if (lastInputLength > 0) lengthDelta.toFloat() / lastInputLength else 1.0f
        
        if (currentHash == lastInputHash) {
            return cachedResult // Same text → same result
        }
        if (cachedResult.isNotEmpty() && changeRatio < CACHE_CHANGE_THRESHOLD && changeRatio >= 0) {
            Log.d(TAG, "Cache hit: text changed ${(changeRatio * 100).toInt()}% (< ${(CACHE_CHANGE_THRESHOLD * 100).toInt()}%), skipping inference")
            return cachedResult
        }
        
        val result = runInference(transcript)
        
        // Update cache
        lastInputHash = currentHash
        lastInputLength = transcript.length
        cachedResult = result
        
        return result
    }

    private fun runInference(text: String): List<IntentPrediction> {
        // 1. Tiền xử lý: chuẩn hóa & tokenize
        val normalized = normalizeVietnamese(text)
        val tokens = tokenize(normalized)

        // 2. Tạo các tensor đầu vào
        val (inputIds, attentionMask, tokenTypeIds) = buildBertInputs(tokens)

        // 3. Chuẩn bị buffers
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

        // 4. Chạy model
        interpreter!!.runForMultipleInputsOutputs(inputs, outputs)

        // 5. Đọc logits và giải lượng tử hóa (Dequantize) nếu cần
        // (SỬA BUG 7) Thêm guard clause kiểm tra buffer remaining.
        // Trên một số thiết bị, dataType() API có thể trả về sai kiểu → đọc buffer
        // sai kích thước → BufferUnderflowException. Guard này phát hiện sớm.
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
        
        // 6. Tính Softmax In-place
        softmaxInPlace(logits, probabilities)

        // 7. Map kết quả sang IntentPrediction
        return INTENT_LABELS.mapIndexed { index, intent ->
            IntentPrediction(intent, probabilities[index])
        }.sortedByDescending { it.confidence }
    }

    // =========================================================================
    // TOKENIZER: WordPiece (Vietnamese-aware)
    // =========================================================================

    /**
     * Chuẩn hóa văn bản tiếng Việt:
     * - Lowercase
     * - Giữ nguyên dấu (KHÔNG bỏ dấu - cần thiết cho tiếng Việt)
     * - Bỏ ký tự đặc biệt ngoài chữ cái, số và khoảng trắng
     */
    private fun normalizeVietnamese(text: String): String {
        return text.lowercase()
            .replace(Regex("[^\\p{L}\\p{N}\\s]"), " ")  // Giữ chữ Unicode (Letter + Number)
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    /**
     * WordPiece Tokenizer: Tách text thành các subword token.
     * Áp dụng Fallback cạo dấu (Accent stripping) cho các từ OOV (Out-of-vocabulary).
     */
    private fun tokenize(text: String): List<String> {
        val result = mutableListOf<String>()
        for (word in text.split(" ")) {
            if (word.isBlank()) continue
            // Kiểm tra nguyên từ trước
            if (vocab.containsKey(word)) {
                result.add(word)
                continue
            }
            // WordPiece: phân tách subword
            var subwords = wordPieceTokenize(word)
            
            // Xử lý OOV thông minh: Nếu bị rơi vào [UNK] toàn cục, gỡ dấu tiếng Việt (môi trường STT giọng nói hay sai dấu)
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

    /**
     * WordPiece greedy tokenization cho một từ.
     * Áp dụng chiến lược longest-match-first.
     */
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

    /**
     * Xây dựng BERT inputs từ danh sách token:
     * [CLS] token1 token2 ... [SEP] [PAD] [PAD] ...
     */
    private fun buildBertInputs(tokens: List<String>): Triple<IntArray, IntArray, IntArray> {
        val clsId = vocab[CLS_TOKEN] ?: 101
        val sepId = vocab[SEP_TOKEN] ?: 102
        val padId = vocab[PAD_TOKEN] ?: 0
        val unkId = vocab[UNK_TOKEN] ?: 100

        // Chiến lược Sliding Truncation: Giữ 50 token đầu tiên có chứa lời chào hỏi hung hăng (Xưng danh cảnh sát, shipper...) + Phần cuối
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

        // CLS
        inputIds[0] = clsId
        attentionMask[0] = 1

        // Tokens
        truncatedTokens.forEachIndexed { i, token ->
            inputIds[i + 1] = vocab[token] ?: unkId
            attentionMask[i + 1] = 1
        }

        // SEP
        val sepPos = truncatedTokens.size + 1
        inputIds[sepPos] = sepId
        attentionMask[sepPos] = 1

        return Triple(inputIds, attentionMask, tokenTypeIds)
    }

    // =========================================================================
    // UTILITIES
    // =========================================================================

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

    // Đã gỡ bỏ fallbackHeuristic cũ vì giờ hệ thống dùng GDetection (Luồng 2) cho Fallback.

    /**
     * Giải phóng tài nguyên khi không còn cần thiết.
     */
    fun close() {
        interpreter?.close()
        interpreter = null
        isReady = false
        Log.i(TAG, "TFLiteIntentClassifier đóng và giải phóng tài nguyên.")
    }
}
