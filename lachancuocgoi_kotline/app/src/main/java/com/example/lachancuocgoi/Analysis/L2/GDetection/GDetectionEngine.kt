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

class GDetectionEngine(private val context: Context) {

    private val initMutex = Mutex()
    @Volatile private var isReady = false

    private var customInputStreamProvider: ((String) -> java.io.InputStream)? = null

    fun setInputStreamProvider(provider: (String) -> java.io.InputStream) {
        customInputStreamProvider = provider
    }

    private lateinit var riskKeywordTrie: TrieNode
    private val keywordToTopicsMap = mutableMapOf<String, MutableList<String>>()
    private var scamPatterns: List<ScamPattern> = emptyList()
    private var scenarioMatcher: ScenarioMatcher? = null
    private var sentenceMatcher: SentenceMatcher? = null
    private var scoringConfig: ScoringConfig = ScoringConfig()

    companion object {
        private const val VOCABULARY_FILE = "risk_model_vocabulary.json"
        private const val AI_CHECK_FILE = "vocabulary_ai_check.json"
        private const val SLANG_FILE = "slang_config.json"
        private const val PATTERNS_FILE = "phrase_patterns.json"
        private const val SITUATION_FILE = "risk_scenarios_master.json"
        private const val SENTENCES_FILE = "risk_model_sentences.json"
        private const val SCORING_CONFIG_FILE = "scoring_config.json"
        private const val TIER_CONFIG_FILE = "tier_config.json"
        private const val TOPIC_CONFIRMATION_THRESHOLD = 3
    }

    fun isEngineReady(): Boolean = isReady

    suspend fun initialize() {
        initMutex.withLock {
            if (isReady) return
            try {
                withContext(Dispatchers.IO) {

                    loadSlangMap()

                    loadScoringConfig()

                    loadTierConfig()

                    riskKeywordTrie = buildTrie()
                    buildTopicMap()

                    loadPatterns()

                    loadMatchers()

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
            scoringConfig = ScoringConfig()
        }
    }

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

            getInputStream(SITUATION_FILE).use { sitIs ->
                val masterModel: RiskScenariosMaster = Gson().fromJson(InputStreamReader(sitIs), RiskScenariosMaster::class.java)
                scenarioMatcher = ScenarioMatcher(masterModel)
                android.util.Log.i("GDetectionEngine", "ScenarioMatcher loaded: ${masterModel.scenarios?.size ?: 0} scenarios")
            }

            getInputStream(SENTENCES_FILE).use { sentIs ->
                val sentModel: RiskModelSentences = Gson().fromJson(InputStreamReader(sentIs), RiskModelSentences::class.java)
                sentenceMatcher = SentenceMatcher(sentModel)
            }
        } catch (e: Exception) {
            android.util.Log.e("GDetectionEngine", "Failed to load matchers", e)
        }
    }

    suspend fun performFullAnalysis(text: String): GResult {

        initMutex.withLock {  }

        if (!isReady) {
            return GResult(riskLevel = RiskLevel.GREEN, reason = "Hệ thống L2 đang khởi tạo.")
        }

        val tokens = GFlash.tokenize(text)
        if (tokens.isEmpty()) {
            return GResult(riskLevel = RiskLevel.GREEN, reason = "Không có nội dung để phân tích.")
        }

        val sentenceMatch = sentenceMatcher?.match(tokens)
        if (sentenceMatch != null && !sentenceMatch.isSafe) {

            return GThinking.analyze(
                allMatchedKeywords = emptySet(),
                topTopic = null,
                sentenceMatch = sentenceMatch,
                config = scoringConfig
            )
        }

        val allMatchedKeywords = extractKeywordsFromTrie(tokens)

        if (sentenceMatch != null && sentenceMatch.isSafe) {
             return GThinking.analyze(
                 allMatchedKeywords = allMatchedKeywords,
                 topTopic = null,
                 sentenceMatch = sentenceMatch,
                 config = scoringConfig
             )
        }

        val topTopic = classifyAndScoreTopics(allMatchedKeywords)

        val matchedPatterns = GPatternMatcher.matchPatterns(tokens, scamPatterns, allMatchedKeywords)

        val contextScore = calculateContextScore(allMatchedKeywords, tokens.size)

        val scenarioMatch = scenarioMatcher?.match(tokens)

        return GThinking.analyze(
            allMatchedKeywords = allMatchedKeywords,
            matchedPatterns = matchedPatterns,
            topTopic = topTopic,
            contextScore = contextScore,
            scenarioMatch = scenarioMatch,
            sentenceMatch = null,
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

    private fun extractKeywordsFromTrie(tokens: List<String>): Set<KeywordMatch> {
        val matches = mutableSetOf<KeywordMatch>()

        for (i in tokens.indices) {
            var currentNode = riskKeywordTrie
            for (j in i until tokens.size) {
                val token = tokens[j]
                currentNode = currentNode.children[token] ?: break

                currentNode.keywordData?.let {

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

    private fun calculateProximityBonus(
        matches: Set<KeywordMatch>
    ): Float {
        if (matches.size < 2) return 0f

        val sortedMatches = matches.sortedBy { it.startIndex }
        var totalBonus = 0f

        for (i in 0 until sortedMatches.size - 1) {
            val current = sortedMatches[i]
            val next = sortedMatches[i + 1]

            val distance = next.startIndex - current.endIndex - 1

            if (distance in 0..5) {
                totalBonus += 0.15f
            } else if (distance in 6..10) {
                totalBonus += 0.05f
            }
        }

        return totalBonus.coerceAtMost(0.5f)
    }

    private fun getPositionWeight(tokenIndex: Int, totalTokens: Int): Float {
        if (totalTokens == 0) return 1.0f

        val relativePosition = tokenIndex.toFloat() / totalTokens.toFloat()
        return when {
            relativePosition < 0.25 -> 1.25f
            relativePosition < 0.6 -> 1.0f
            else -> 0.9f
        }
    }

    fun calculateContextScore(matches: Set<KeywordMatch>, totalTokens: Int): Float {
        val proximityBonus = calculateProximityBonus(matches)

        var totalPosWeight = 0f
        matches.forEach {
           totalPosWeight += getPositionWeight(it.startIndex, totalTokens)
        }
        val avgPosWeight = if (matches.isNotEmpty()) totalPosWeight / matches.size else 1.0f

        return proximityBonus + (avgPosWeight - 1.0f)
    }
}
