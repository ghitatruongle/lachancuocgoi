package com.example.lachancuocgoi.Analysis.L1

import android.content.Context
import android.util.Log
import com.example.lachancuocgoi.Analysis.AnalysisLevel
import com.example.lachancuocgoi.Analysis.Analyzer
import com.example.lachancuocgoi.Analysis.AnalysisResult
import com.example.lachancuocgoi.Analysis.HealthReport
import com.example.lachancuocgoi.Analysis.HealthStatus
import com.example.lachancuocgoi.Analysis.KeywordMatch
import com.example.lachancuocgoi.Analysis.common.FuzzyMatcher
import com.example.lachancuocgoi.Analysis.common.TextNormalizer
import com.example.lachancuocgoi.RiskLevel
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.InputStreamReader
import java.util.*

// --- GĐ1, GĐ2, GĐ3: Cấu trúc dữ liệu tối ưu & Bitmasking ---

/**
 * Lớp quản lý bộ nhớ tập trung cho Trie (GĐ1, GĐ2, GĐ3 Optimization)
 */
internal class FlatTrie(initialCapacity: Int = 2000) {
    var childrenMaps = arrayOfNulls<MutableMap<String, Int>>(initialCapacity)
    
    // GĐ3: Sử dụng mảng nguyên thủy và Bitmasking thay cho Object
    // Bit layout: [31: flag_is_match] [23-16: category_id] [7-0: risk_level]
    var nodeMetadata = IntArray(initialCapacity) { 0 }
    var nodeOriginalKeywords = arrayOfNulls<String>(initialCapacity)
    
    // Dictionary để map Category String sang ID (1 byte)
    private val categoryToId = mutableMapOf<String, Int>()
    private val idToCategory = mutableListOf<String>()

    // GĐ2: Failure Links & Dictionary Links cho Aho-Corasick
    var failureLinks = IntArray(initialCapacity) { rootId }
    var dictionaryLinks = IntArray(initialCapacity) { rootId }
    
    var nodesCount = 1

    init {
        childrenMaps[rootId] = mutableMapOf()
    }

    companion object {
        const val rootId = 0
        
        // Bitmask Constants
        const val MASK_RISK_LEVEL = 0xFF
        const val SHIFT_CATEGORY = 8
        const val MASK_CATEGORY = 0xFF shl SHIFT_CATEGORY
        const val FLAG_IS_MATCH = 1 shl 31
    }

    fun ensureCapacity(minCapacity: Int) {
        if (minCapacity > childrenMaps.size) {
            val newSize = childrenMaps.size * 2
            childrenMaps = childrenMaps.copyOf(newSize)
            nodeMetadata = nodeMetadata.copyOf(newSize)
            nodeOriginalKeywords = nodeOriginalKeywords.copyOf(newSize)
            failureLinks = failureLinks.copyOf(newSize)
            dictionaryLinks = dictionaryLinks.copyOf(newSize)
            Log.d("FlatTrie", "Expanded capacity to $newSize")
        }
    }

    fun createNode(): Int {
        ensureCapacity(nodesCount + 1)
        val id = nodesCount++
        childrenMaps[id] = mutableMapOf()
        nodeMetadata[id] = 0
        failureLinks[id] = rootId
        dictionaryLinks[id] = rootId
        return id
    }
    
    fun getChildId(parentId: Int, token: String): Int? {
        return childrenMaps[parentId]?.get(token)
    }

    fun setChildId(parentId: Int, token: String, childId: Int) {
        childrenMaps[parentId]?.put(token, childId)
    }

    // GĐ3: Logic Bitmasking
    fun packMetadata(level: Int, category: String, keyword: String, nodeId: Int) {
        val catId = categoryToId.getOrPut(category) {
            val id = idToCategory.size
            idToCategory.add(category)
            id
        }
        var meta = FLAG_IS_MATCH
        meta = meta or (catId shl SHIFT_CATEGORY)
        meta = meta or (level and MASK_RISK_LEVEL)
        
        nodeMetadata[nodeId] = meta
        nodeOriginalKeywords[nodeId] = keyword
    }

    fun getRiskLevel(nodeId: Int): Int = nodeMetadata[nodeId] and MASK_RISK_LEVEL
    fun getCategoryId(nodeId: Int): Int = (nodeMetadata[nodeId] and MASK_CATEGORY) ushr SHIFT_CATEGORY
    fun getCategoryName(nodeId: Int): String = idToCategory.getOrNull(getCategoryId(nodeId)) ?: "Unknown"
    fun isMatchNode(nodeId: Int): Boolean = (nodeMetadata[nodeId] and FLAG_IS_MATCH) != 0
}

// --- Cấu trúc dữ liệu để phân tích JSON từ vựng ---
private data class RiskModelVocabulary(@SerializedName("riskLevels") val riskLevels: List<RiskLevelData>?)
private data class RiskLevelData(
    val level: Int,
    val keywords: List<String>?,
    val threats: Map<String, List<String>>?
)

// --- Cấu trúc dữ liệu cho bigram corrections JSON ---
private data class BigramCorrectionsConfig(
    val corrections: List<BigramCorrectionEntry>
)
private data class BigramCorrectionEntry(
    val from: List<String>,
    val to: List<String>,
    val note: String = ""
)

/**
 * (Bitmasking).
 */
class L1Analyzer(private val context: Context) : Analyzer {

    private val TAG = "L1Analyzer"
    override val level = AnalysisLevel.L1
    private val trie = FlatTrie()

    // Sử dụng TextNormalizer chung thay vì private normalize

    // Danh sách từ khóa đơn (1 token) cho fuzzy matching
    private val singleTokenKeywords = mutableListOf<String>()
    private val fuzzyEnabled = true
    private val fuzzyMaxDistance = 1  // Chỉ cho phép sai 1 ký tự (STT errors nhẹ)
    private val fuzzyMinLength = 5    // P1: Không fuzzy nếu token < 5 chars (tránh false positive ngắn)

    // GĐ6: Bi-gram Correction cho lỗi STT — load từ JSON thay vì hard-code
    private var bigramCorrections: Map<List<String>, List<String>> = emptyMap()

    /**
     * Áp dụng bi-gram correction cho danh sách token.
     * Chỉ sửa khi 2 token liền nhau khớp pattern, KHÔNG sửa từ đơn lẻ.
     */
    private fun applyBigramCorrections(tokens: List<String>): List<String> {
        if (tokens.size < 2) return tokens
        val result = mutableListOf<String>()
        var i = 0
        while (i < tokens.size) {
            if (i + 1 < tokens.size) {
                val bigram = listOf(tokens[i], tokens[i + 1])
                val correction = bigramCorrections[bigram]
                if (correction != null) {
                    result.addAll(correction)
                    i += 2
                    continue
                }
            }
            result.add(tokens[i])
            i++
        }
        return result
    }

    private fun normalizeString(input: String): String {
        return TextNormalizer.normalize(input, applySlang = false, noiseMode = TextNormalizer.NoiseMode.REMOVE)
    }

    private fun tokenize(text: String): List<String> {
        return TextNormalizer.tokenize(text, applySlang = false, noiseMode = TextNormalizer.NoiseMode.REMOVE)
    }

    private var hasInitialized = false
    private val initLock = Any()
    private var customInputStreamProvider: (() -> java.io.InputStream)? = null

    fun setVocabularyProvider(provider: () -> java.io.InputStream) {
        customInputStreamProvider = provider
    }

    override suspend fun initialize() {
        withContext(Dispatchers.IO) {
            initializeIfNeeded()
        }
    }

    override fun isReady(): Boolean = hasInitialized

    private fun initializeIfNeeded() {
        if (hasInitialized) return
        synchronized(initLock) {
            if (!hasInitialized) {
                buildTrie()
                loadBigramCorrections()
                computeAhoCorasickLinks()
                hasInitialized = true
            }
        }
    }

    private fun buildTrie() {
        try {
            val inputStream = customInputStreamProvider?.invoke() ?: context.assets.open("risk_model_vocabulary.json")
            val model: RiskModelVocabulary = Gson().fromJson(InputStreamReader(inputStream), RiskModelVocabulary::class.java)

            if (model.riskLevels == null) return

            model.riskLevels.forEach { riskLevelData ->
                riskLevelData.threats?.forEach { (category, keywords) ->
                    keywords.forEach { insertKeyword(it, riskLevelData.level, category) }
                }
                riskLevelData.keywords?.forEach { insertKeyword(it, riskLevelData.level, "Chung") }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khởi tạo L1", e)
        }
        Log.i(TAG, "Cây Trie hoàn tất với ${trie.nodesCount} nodes (Bitmasked).")
    }

    private fun loadBigramCorrections() {
        try {
            val inputStream = context.assets.open("bigram_corrections.json")
            val config: BigramCorrectionsConfig = Gson().fromJson(
                InputStreamReader(inputStream), BigramCorrectionsConfig::class.java
            )
            bigramCorrections = config.corrections.associate { it.from to it.to }
            Log.i(TAG, "Đã nạp ${bigramCorrections.size} bigram corrections từ JSON")
        } catch (e: Exception) {
            Log.w(TAG, "Không thể nạp bigram_corrections.json, dùng empty map", e)
            bigramCorrections = emptyMap()
        }
    }

    private fun insertKeyword(keyword: String, levelValue: Int, category: String) {
        val tokens = tokenize(keyword)
        if (tokens.isEmpty()) return

        // Lưu từ khóa đơn (1 token) cho fuzzy matching
        if (tokens.size == 1) {
            singleTokenKeywords.add(tokens[0])
        }

        var currentNodeId = FlatTrie.rootId
        tokens.forEach { token ->
            val childId = trie.getChildId(currentNodeId, token)
            if (childId != null) {
                currentNodeId = childId
            } else {
                val nextNodeId = trie.createNode()
                trie.setChildId(currentNodeId, token, nextNodeId)
                currentNodeId = nextNodeId
            }
        }
        // GĐ3: Pack dữ liệu vào Bitmask
        trie.packMetadata(levelValue, category, keyword, currentNodeId)
    }

    private fun computeAhoCorasickLinks() {
        val queue: Queue<Int> = LinkedList()
        trie.childrenMaps[FlatTrie.rootId]?.forEach { (_, childId) ->
            trie.failureLinks[childId] = FlatTrie.rootId
            queue.add(childId)
        }

        while (queue.isNotEmpty()) {
            val uId = queue.poll() ?: break
            trie.childrenMaps[uId]?.forEach { (token, vId) ->
                var fId = trie.failureLinks[uId]
                while (fId != FlatTrie.rootId && trie.getChildId(fId, token) == null) {
                    fId = trie.failureLinks[fId]
                }
                trie.failureLinks[vId] = trie.getChildId(fId, token) ?: FlatTrie.rootId
                
                val fvId = trie.failureLinks[vId]
                trie.dictionaryLinks[vId] = if (trie.isMatchNode(fvId)) {
                    fvId
                } else {
                    trie.dictionaryLinks[fvId]
                }
                queue.add(vId)
            }
        }
    }

    // --- GĐ5: Stateful Streaming Analysis ---
    private var currentSessionStateId = FlatTrie.rootId
    private var processedWordCount = 0
    private var lastFullTranscript: String = ""
    private val sessionLock = Any()
    private var processedTextLength = 0
    private var lastResult: AnalysisResult = AnalysisResult(RiskLevel.GREEN, emptyList(), analysisLevel = AnalysisLevel.L1)

    /**
     * Khởi tạo lại phiên làm việc (Ví dụ: Khi bắt đầu cuộc gọi mới)
     */
    override fun resetSession() {
        synchronized(sessionLock) {
            currentSessionStateId = FlatTrie.rootId
            processedWordCount = 0
            lastFullTranscript = ""
            processedTextLength = 0
            lastResult = AnalysisResult(RiskLevel.GREEN, emptyList(), analysisLevel = AnalysisLevel.L1)
        }
        Log.i(TAG, "L1 Session Reset.")
    }

    override fun getProcessedTextLength(): Int = synchronized(sessionLock) { processedTextLength }

    override fun syncProcessedTextLength(length: Int) {
        synchronized(sessionLock) { processedTextLength = length.coerceAtLeast(0) }
    }

    override fun getLastResult(): AnalysisResult = synchronized(sessionLock) { lastResult }

    override fun healthCheck(): HealthReport {
        val trieNodes = trie.nodesCount
        val hasKeywords = trieNodes > 1  // rootId = 0, nodesCount khởi đầu = 1, nên >1 nghĩa là có data
        val hasBigramCorrections = bigramCorrections.isNotEmpty()

        return when {
            !hasKeywords -> HealthReport(
                HealthStatus.DOWN,
                "L1",
                "Trie rỗng (0 nodes ngoài root). Keywords JSON có thể bị lỗi hoặc chưa load."
            )
            !hasBigramCorrections -> HealthReport(
                HealthStatus.DEGRADED,
                "L1",
                "Trie OK ($trieNodes nodes) nhưng không có bigram corrections. STT error handling giảm."
            )
            else -> HealthReport(
                HealthStatus.HEALTHY,
                "L1",
                "Trie OK ($trieNodes nodes, ${bigramCorrections.size} bigram corrections). Fuzzy=${fuzzyEnabled}"
            )
        }
    }

    /**
     * Phân tích luồng văn bản (Stream). Chỉ quét phần mới thêm vào.
     * @param fullTranscript Toàn bộ văn bản hiện tại nhận được từ STT.
     */
    suspend fun analyzeStream(fullTranscript: String): AnalysisResult = withContext(Dispatchers.IO) {
        initializeIfNeeded()
        
        synchronized(sessionLock) {
            // Nếu văn bản mới ngắn hơn văn bản cũ, có thể STT đã thực hiện "Correction"
            // Hoặc nếu văn bản thay đổi nhưng không phải là phần tail
            if (fullTranscript.length < lastFullTranscript.length || !fullTranscript.startsWith(lastFullTranscript)) {
                Log.d(TAG, "STT Correction detected. Resetting session state.")
                currentSessionStateId = FlatTrie.rootId
                processedWordCount = 0
            }
            
            val rawTokens = tokenize(fullTranscript)
            val allTokens = applyBigramCorrections(rawTokens)
            if (allTokens.size <= processedWordCount) {
                lastFullTranscript = fullTranscript
                return@withContext L1ResultParser.parse(emptySet(), allTokens.size)
            }

            // Tính vị trí token trong text gốc (word index)
            val newTokens = allTokens.subList(processedWordCount, allTokens.size)
            val matches = mutableSetOf<KeywordMatch>()
            val unmatchedTokens = mutableListOf<Pair<String, Int>>() // token + wordIndex

            newTokens.forEachIndexed { idx, token ->
                val wordIndex = processedWordCount + idx
                // Men theo failure links nếu không có đường đi trực tiếp
                while (currentSessionStateId != FlatTrie.rootId && trie.getChildId(currentSessionStateId, token) == null) {
                    currentSessionStateId = trie.failureLinks[currentSessionStateId]
                }
                currentSessionStateId = trie.getChildId(currentSessionStateId, token) ?: FlatTrie.rootId
                
                // Tìm tất cả các từ khóa kết thúc tại trạng thái này (bao gồm cả các từ là suffix)
                var found = false
                var tempStateId = currentSessionStateId
                // BUG FIX: Thêm visited set để tránh vòng lặp vô hạn nếu dictionaryLinks tự trỏ vào chính nó
                val visitedDictNodes = mutableSetOf<Int>()
                while (tempStateId != FlatTrie.rootId && visitedDictNodes.add(tempStateId)) {
                    if (trie.isMatchNode(tempStateId)) {
                        val level = RiskLevel.fromInt(trie.getRiskLevel(tempStateId))
                        val category = trie.getCategoryName(tempStateId)
                        val keyword = trie.nodeOriginalKeywords[tempStateId] ?: ""
                        // Ước lượng số token trong keyword gốc
                        val keywordTokenCount = tokenize(keyword).size.coerceAtLeast(1)
                        matches.add(KeywordMatch(
                            keyword, level, category,
                            startIndex = wordIndex - keywordTokenCount + 1,
                            endIndex = wordIndex
                        ))
                        found = true
                    }
                    tempStateId = trie.dictionaryLinks[tempStateId]
                }
                if (!found) unmatchedTokens.add(token to wordIndex)
            }

            // Fuzzy matching cho các token không khớp chính xác
            if (fuzzyEnabled && unmatchedTokens.isNotEmpty() && singleTokenKeywords.isNotEmpty()) {
                for ((token, wordIndex) in unmatchedTokens) {
                    // P1: Bỏ qua token ngắn < fuzzyMinLength để tránh false positive
                    if (token.length < fuzzyMinLength) continue
                    val fuzzyMatch = FuzzyMatcher.findClosest(token, singleTokenKeywords, fuzzyMaxDistance)
                    if (fuzzyMatch != null) {
                        val nodeId = findExactMatchNode(fuzzyMatch)
                        if (nodeId != null && trie.isMatchNode(nodeId)) {
                            val level = RiskLevel.fromInt(trie.getRiskLevel(nodeId))
                            val category = trie.getCategoryName(nodeId)
                            val keyword = trie.nodeOriginalKeywords[nodeId] ?: ""
                            matches.add(KeywordMatch(keyword, level, category, startIndex = wordIndex, endIndex = wordIndex, isFuzzy = true))
                            Log.d(TAG, "Fuzzy match: '$token' → '$fuzzyMatch' (keyword='$keyword')")
                        }
                    }
                }
            }

            processedWordCount = allTokens.size
            lastFullTranscript = fullTranscript
            val result = L1ResultParser.parse(matches, allTokens.size)
            processedTextLength = fullTranscript.length
            lastResult = result
            result
        }
    }

    /**
     * Phân tích một đoạn văn bản độc lập (Không lưu trạng thái).
     */
    suspend fun analyze(text: String): AnalysisResult = withContext(Dispatchers.IO) {
        initializeIfNeeded()
        val rawTokens = tokenize(text)
        val tokens = applyBigramCorrections(rawTokens)
        val matches = findMatchesLinear(tokens)
        L1ResultParser.parse(matches)
    }

    private fun findMatchesLinear(tokens: List<String>): Set<KeywordMatch> {
        if (tokens.isEmpty()) return emptySet()

        val matches = mutableSetOf<KeywordMatch>()
        val unmatchedTokens = mutableListOf<String>()
        var currentStateId = FlatTrie.rootId

        tokens.forEach { token ->
            while (currentStateId != FlatTrie.rootId && trie.getChildId(currentStateId, token) == null) {
                currentStateId = trie.failureLinks[currentStateId]
            }
            currentStateId = trie.getChildId(currentStateId, token) ?: FlatTrie.rootId
            
            var found = false
            var tempStateId = currentStateId
            // BUG FIX: Thêm visited set để tránh vòng lặp vô hạn nếu dictionaryLinks tự trỏ vào chính nó
            val visitedDictNodes = mutableSetOf<Int>()
            while (tempStateId != FlatTrie.rootId && visitedDictNodes.add(tempStateId)) {
                if (trie.isMatchNode(tempStateId)) {
                    val level = RiskLevel.fromInt(trie.getRiskLevel(tempStateId))
                    val category = trie.getCategoryName(tempStateId)
                    val keyword = trie.nodeOriginalKeywords[tempStateId] ?: ""
                    matches.add(KeywordMatch(keyword, level, category))
                    found = true
                }
                tempStateId = trie.dictionaryLinks[tempStateId]
            }
            if (!found) unmatchedTokens.add(token)
        }

        // Fuzzy matching cho các token không khớp chính xác
        if (fuzzyEnabled && unmatchedTokens.isNotEmpty() && singleTokenKeywords.isNotEmpty()) {
            for (token in unmatchedTokens) {
                val fuzzyMatch = FuzzyMatcher.findClosest(token, singleTokenKeywords, fuzzyMaxDistance)
                if (fuzzyMatch != null) {
                    val nodeId = findExactMatchNode(fuzzyMatch)
                    if (nodeId != null && trie.isMatchNode(nodeId)) {
                        val level = RiskLevel.fromInt(trie.getRiskLevel(nodeId))
                        val category = trie.getCategoryName(nodeId)
                        val keyword = trie.nodeOriginalKeywords[nodeId] ?: ""
                        matches.add(KeywordMatch(keyword, level, category, isFuzzy = true))
                        Log.d(TAG, "Fuzzy match: '$token' → '$fuzzyMatch' (keyword='$keyword')")
                    }
                }
            }
        }

        return matches
    }

    /**
     * Tìm node trong Trie cho một token đơn (exact match từ root).
     */
    private fun findExactMatchNode(token: String): Int? {
        val childId = trie.getChildId(FlatTrie.rootId, token) ?: return null
        return if (trie.isMatchNode(childId)) childId else null
    }
}
