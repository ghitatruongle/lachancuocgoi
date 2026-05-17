package com.example.lachancuocgoi.Analysis.L2.GDetection

import android.content.Context
import com.example.lachancuocgoi.Analysis.KeywordMatch
import com.example.lachancuocgoi.Analysis.L2.Safety.SafetyFilter
import com.example.lachancuocgoi.RiskLevel
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileInputStream
import java.io.InputStream
import java.io.InputStreamReader

// Internal models moved to GModels.kt


class GDetectionEngine(private val context: Context) {

    private val initMutex = Mutex()
    @Volatile private var isReady = false

    // (NEW) Dành cho testing: Cho phép inject các InputStream trực tiếp
    private var customInputStreamProvider: ((String) -> java.io.InputStream)? = null

    fun setInputStreamProvider(provider: (String) -> java.io.InputStream) {
        customInputStreamProvider = provider
    }

    private lateinit var riskKeywordTrie: TrieNode
    private val keywordToTopicsMap = mutableMapOf<String, MutableList<String>>()
    private var scamPatterns: List<ScamPattern> = emptyList()
    private var scenarioMatcher: ScenarioMatcher? = null  // RENAMED from situationMatcher, NEW type
    private var sentenceMatcher: SentenceMatcher? = null
    private var scoringConfig: ScoringConfig = ScoringConfig() // Default config



    companion object {
        private const val VOCABULARY_FILE = "risk_model_vocabulary.json"
        private const val AI_CHECK_FILE = "vocabulary_ai_check.json"
        private const val SLANG_FILE = "slang_config.json"
        private const val PATTERNS_FILE = "phrase_patterns.json"
        private const val SITUATION_FILE = "risk_scenarios_master.json"  // UPDATED: Use new master file with 250 scenarios
        private const val SENTENCES_FILE = "risk_model_sentences.json"
        private const val SCORING_CONFIG_FILE = "scoring_config.json" // NEW
        private const val TIER_CONFIG_FILE = "tier_config.json" // A1: Externalized tier keywords
        private const val TOPIC_CONFIRMATION_THRESHOLD = 3
    }



    fun isEngineReady(): Boolean = isReady

    /**
     * (SỬA BUG 4) Khởi tạo engine một cách đồng bộ (suspend).
     * Trước đây initialize() dùng engineScope.launch (fire-and-forget) → isReady luôn
     * false ngay sau khi gọi → lần phân tích đầu tiên luôn trả GREEN.
     * Giờ chạy inline, đảm bảo isReady = true trước khi return.
     */
    suspend fun initialize() {
        initMutex.withLock {
            if (isReady) return // Đã khởi tạo rồi
            try {
                withContext(Dispatchers.IO) {
                    // 1. Nạp cấu hình từ lóng trước để GFlash có dữ liệu chuẩn hóa
                    loadSlangMap()
                    
                    // 2. Load scoring config
                    loadScoringConfig()
                    
                    // 3. Load tier config (A1: externalized from GThinking)
                    loadTierConfig()
                    
                    // 4. Xây dựng cây trie và bản đồ chủ đề
                    riskKeywordTrie = buildTrie()
                    buildTopicMap()
                    
                    // 5. Load patterns
                    loadPatterns()

                    // 6. Load Matchers
                    loadMatchers()

                    // 7. Load SafetyFilter config
                    SafetyFilter.loadConfig(context)
                }
                isReady = true
                android.util.Log.i("GDetectionEngine", "✓ L2 GDetection Engine initialized successfully.")
            } catch (e: Exception) {
                android.util.Log.e("GDetectionEngine", "✗ Failed to initialize GDetection Engine", e)
                isReady = false
            }
        }
    }

    /**
     * Hỗ trợ đọc file từ Internal Storage (để cập nhật động sau này) hoặc Assets.
     */
    private fun getInputStream(fileName: String): InputStream {
        customInputStreamProvider?.let { return it(fileName) }
        val internalFile = File(context.filesDir, fileName)
        return if (internalFile.exists()) {
            FileInputStream(internalFile)
        } else {
            context.assets.open(fileName)
        }
    }

    private fun loadSlangMap() {
        try {
            getInputStream(SLANG_FILE).use { inputStream ->
                val config: SlangConfig = Gson().fromJson(InputStreamReader(inputStream), SlangConfig::class.java)
                config.slangMap?.let {
                    GFlash.loadSlangConfig(it)
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("GDetectionEngine", "Failed to load slang map", e)
        }
    }

    private fun loadScoringConfig() {
        try {
            getInputStream(SCORING_CONFIG_FILE).use { inputStream ->
                scoringConfig = Gson().fromJson(InputStreamReader(inputStream), ScoringConfig::class.java)
            }
        } catch (e: Exception) {
            android.util.Log.w("GDetectionEngine", "Failed to load scoring config, using defaults", e)
            scoringConfig = ScoringConfig() // Use defaults
        }
    }

    /**
     * (A1) Load tier keywords from tier_config.json and inject into GThinking.
     */
    private fun loadTierConfig() {
        try {
            getInputStream(TIER_CONFIG_FILE).use { inputStream ->
                val config: TierConfig = Gson().fromJson(InputStreamReader(inputStream), TierConfig::class.java)
                GThinking.loadTierConfig(
                    tier1 = config.tier1Topics?.toSet() ?: emptySet(),
                    tier2 = config.tier2Urgency?.toSet() ?: emptySet(),
                    tier3 = config.tier3Pii?.toSet() ?: emptySet()
                )
            }
        } catch (e: Exception) {
            android.util.Log.e("GDetectionEngine", "Failed to load tier config, GThinking will have empty tiers", e)
        }
    }

    private fun buildTrie(): TrieNode {
        val root = TrieNode()
        try {
            getInputStream(VOCABULARY_FILE).use { inputStream ->
                val model: RiskModelVocabulary = Gson().fromJson(InputStreamReader(inputStream), RiskModelVocabulary::class.java)

                (model.riskLevels ?: emptyList()).forEach { riskLevelData ->
                    val riskLevel = RiskLevel.fromInt(riskLevelData.level)
                    
                    val allKeywords = (riskLevelData.keywords ?: emptyList()) + 
                                      (riskLevelData.threats?.values?.flatten() ?: emptyList())

                    allKeywords.forEach { keyword ->
                        val processedTokens = GFlash.tokenize(keyword)
                        if (processedTokens.isNotEmpty()) {
                            var currentNode = root
                            processedTokens.forEach {
                                currentNode = currentNode.children.getOrPut(it) { TrieNode() }
                            }
                            val category = riskLevelData.threats?.entries?.find { it.value.contains(keyword) }?.key ?: "Chung"
                            currentNode.keywordData = KeywordTrieData(riskLevel, category, keyword)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("GDetectionEngine", "Failed to build trie", e)
        }
        return root
    }


    private fun buildTopicMap() {
        val file = File(context.filesDir, AI_CHECK_FILE)
        if (!file.exists()) {
            // Optional file, fail silently or log debug only
            // android.util.Log.d("GDetectionEngine", "Optional topic map file not found, skipping.")
            return
        }

        try {
            FileInputStream(file).use { inputStream ->
                val model: AiCheckModel = Gson().fromJson(InputStreamReader(inputStream), AiCheckModel::class.java)

                (model.situations ?: emptyList()).forEach { situation ->
                    val topicName = situation.name
                    val allKeywordsForTopic = (situation.triggerPhrases ?: emptyList()) + (situation.requiredContext ?: emptyList())

                    allKeywordsForTopic.forEach { keyword ->
                        val tokenizedKeyword = GFlash.tokenize(keyword)
                        if (tokenizedKeyword.isNotEmpty()) {
                            val fullKeywordKey = tokenizedKeyword.joinToString(" ")
                            keywordToTopicsMap.getOrPut(fullKeywordKey) { mutableListOf() }.add(topicName)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("GDetectionEngine", "Failed to build topic map", e)
        }
    }


    private fun loadPatterns() {
        try {
            getInputStream(PATTERNS_FILE).use { inputStream ->
                val config: PatternConfigDTO = Gson().fromJson(InputStreamReader(inputStream), PatternConfigDTO::class.java)
                scamPatterns = config.patterns?.map { it.toDomain() } ?: emptyList()
            }
        } catch (e: Exception) {
            android.util.Log.e("GDetectionEngine", "Failed to load patterns", e)
        }
    }


    private fun loadMatchers() {
        try {
            // Load Scenario Matcher (250 scenarios from risk_scenarios_master.json)
            getInputStream(SITUATION_FILE).use { sitIs ->
                val masterModel: RiskScenariosMaster = Gson().fromJson(InputStreamReader(sitIs), RiskScenariosMaster::class.java)
                scenarioMatcher = ScenarioMatcher(masterModel)
                android.util.Log.i("GDetectionEngine", "ScenarioMatcher loaded: ${masterModel.scenarios?.size ?: 0} scenarios")
            }

            // Load Sentence Matcher
            getInputStream(SENTENCES_FILE).use { sentIs ->
                val sentModel: RiskModelSentences = Gson().fromJson(InputStreamReader(sentIs), RiskModelSentences::class.java)
                sentenceMatcher = SentenceMatcher(sentModel)
            }
        } catch (e: Exception) {
            android.util.Log.e("GDetectionEngine", "Failed to load matchers", e)
        }
    }



    suspend fun performFullAnalysis(text: String): GResult {
        // Đợi init hoàn tất nếu đang chạy (giải quyết race condition)
        initMutex.withLock { /* Đảm bảo init xong */ }

        if (!isReady) {
            return GResult(riskLevel = RiskLevel.GREEN, reason = "Hệ thống L2 đang khởi tạo.")
        }

        val tokens = GFlash.tokenize(text)
        if (tokens.isEmpty()) {
            return GResult(riskLevel = RiskLevel.GREEN, reason = "Không có nội dung để phân tích.")
        }

        // ==========================================
        // FAST TRACK: Sentence Matching
        // Chạy SentenceMatcher đầu tiên, nếu khớp 100% câu nguy hiểm, báo động ngay lập tức
        // Bỏ qua tất cả các bước phân tích sâu nặng nề (Trie, Pattern, Scenario)
        // ==========================================
        val sentenceMatch = sentenceMatcher?.match(tokens)
        if (sentenceMatch != null && !sentenceMatch.isSafe) {
            // Usually RED or ORANGE based on sentenceMatch.level
            return GThinking.analyze(
                allMatchedKeywords = emptySet(), // Tiết kiệm trích xuất
                topTopic = null,
                sentenceMatch = sentenceMatch,
                config = scoringConfig
            )
        }

        val allMatchedKeywords = extractKeywordsFromTrie(tokens)
        // Nếu là câu safe hoàn toàn, hoặc không có keyword nào rủi ro
        if (sentenceMatch != null && sentenceMatch.isSafe) {
             return GThinking.analyze(
                 allMatchedKeywords = allMatchedKeywords,
                 topTopic = null,
                 sentenceMatch = sentenceMatch,
                 config = scoringConfig
             )
        }

        val topTopic = classifyAndScoreTopics(allMatchedKeywords)

        // Pattern Matching
        val matchedPatterns = GPatternMatcher.matchPatterns(tokens, scamPatterns, allMatchedKeywords)

        // Context Scoring
        val contextScore = calculateContextScore(allMatchedKeywords, tokens.size)

        // Scenario Matching (Heaviest operation)
        val scenarioMatch = scenarioMatcher?.match(tokens)

        return GThinking.analyze(
            allMatchedKeywords = allMatchedKeywords,
            matchedPatterns = matchedPatterns,
            topTopic = topTopic,
            contextScore = contextScore,
            scenarioMatch = scenarioMatch,
            sentenceMatch = null, // Đã check qua Fast Track
            config = scoringConfig
        )
    }

    private fun classifyAndScoreTopics(foundKeywords: Set<KeywordMatch>): String? {
        if (foundKeywords.isEmpty()) return null

        val topicScores = mutableMapOf<String, Int>()

        foundKeywords.forEach { match ->
            val tokenizedKeyword = GFlash.tokenize(match.keyword).joinToString(" ")
            keywordToTopicsMap[tokenizedKeyword]?.forEach { topicName ->
                topicScores[topicName] = (topicScores[topicName] ?: 0) + 1
            }
        }

        val bestTopicEntry = topicScores.filter {
            it.value > TOPIC_CONFIRMATION_THRESHOLD
        }.maxByOrNull { it.value }

        return bestTopicEntry?.key
    }

    /**
     * (UPDATED) Trích xuất từ khóa từ Trie và lưu thông tin vị trí.
     */
    private fun extractKeywordsFromTrie(tokens: List<String>): Set<KeywordMatch> {
        val matches = mutableSetOf<KeywordMatch>()

        for (i in tokens.indices) {
            var currentNode = riskKeywordTrie
            for (j in i until tokens.size) {
                val token = tokens[j]
                currentNode = currentNode.children[token] ?: break

                currentNode.keywordData?.let {
                    // Start index = i, End index = j
                    matches.add(KeywordMatch(
                        keyword = it.originalKeyword, 
                        level = it.riskLevel, 
                        category = it.category,
                        startIndex = i,
                        endIndex = j
                    ))
                }
            }
        }
        return matches
    }
    
    /**
     * (NEW - Phase 1) Tính điểm thưởng dựa trên khoảng cách giữa các từ khóa rủi ro.
     * Các từ khóa xuất hiện gần nhau cho thấy mức độ tập trung của ý định lừa đảo.
     */
    private fun calculateProximityBonus(
        matches: Set<KeywordMatch>
    ): Float {
        if (matches.size < 2) return 0f
        
        // Sắp xếp các từ khóa theo vị trí xuất hiện
        val sortedMatches = matches.sortedBy { it.startIndex }
        var totalBonus = 0f
        
        for (i in 0 until sortedMatches.size - 1) {
            val current = sortedMatches[i]
            val next = sortedMatches[i + 1]
            
            // Khoảng cách giữa điểm cuối từ trước và điểm đầu từ sau
            val distance = next.startIndex - current.endIndex - 1
            
            // Nếu khoảng cách < 5 từ (rất gần) -> Thưởng lớn
            if (distance in 0..5) {
                totalBonus += 0.15f // +15% cho mỗi cặp từ gần nhau
            } else if (distance in 6..10) {
                totalBonus += 0.05f // +5% cho khoảng cách trung bình
            }
        }
        
        // Cap bonus tối đa ở mức 50%
        return totalBonus.coerceAtMost(0.5f)
    }

    /**
     * (NEW - Phase 1) Tính trọng số dựa trên vị trí xuất hiện của từ khóa.
     * Từ khóa ở đầu cuộc gọi thường quan trọng hơn (ví dụ: giới thiệu giả danh).
     */
    private fun getPositionWeight(tokenIndex: Int, totalTokens: Int): Float {
        if (totalTokens == 0) return 1.0f
        
        val relativePosition = tokenIndex.toFloat() / totalTokens.toFloat()
        return when {
            relativePosition < 0.25 -> 1.25f // 25% đầu cuộc gọi: Quan trọng nhất (Mở bài)
            relativePosition < 0.6 -> 1.0f   // Đoạn giữa: Bình thường
            else -> 0.9f                     // Cuối cuộc gọi: Giảm nhẹ trọng số
        }
    }

    // Public method để truy cập logic scoring mới từ bên ngoài (cho testing hoặc GThinking)
    fun calculateContextScore(matches: Set<KeywordMatch>, totalTokens: Int): Float {
        val proximityBonus = calculateProximityBonus(matches)
        
        // Tính điểm trung bình trọng số vị trí
        var totalPosWeight = 0f
        matches.forEach { 
           totalPosWeight += getPositionWeight(it.startIndex, totalTokens)
        }
        val avgPosWeight = if (matches.isNotEmpty()) totalPosWeight / matches.size else 1.0f
        
        // Kết hợp đơn giản (sẽ được thay thế bởi logic phức tạp hơn ở Phase 4)
        return proximityBonus + (avgPosWeight - 1.0f) // Trả về phần chênh lệch (bonus/penalty)
    }
}
