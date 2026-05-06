package com.example.lachancuocgoi.Analysis.L2.GDetection

/**
 * [A5 UPGRADE] Matcher for risk_scenarios_master.json (250+ scenarios).
 * Uses trigger_phrases and required_context for weighted matching.
 *
 * Cải tiến A5: Thêm bigram bonus để giữ word order, giảm false positive.
 * Cải tiến M5: Tận dụng l2_analysis_hints metadata (urgency, authority, financial).
 * [FIX-1.2] required_context bắt buộc >= 1 match khi scenario có context phrases.
 * [UPGRADE-2.2] Fuzzy phrase matching: accept >= 75% token overlap for phrases >= 3 tokens.
 * [UPGRADE-3.2] Dynamic threshold: scales with average phrase length to reduce false positives.
 */
class ScenarioMatcher(private val masterModel: RiskScenariosMaster) {

    private val tokenToScenarios = mutableMapOf<String, MutableSet<String>>()
    private val scenarioData = mutableMapOf<String, ScenarioInfo>()
    private var initialized = false

    private data class ScenarioInfo(
        val name: String,
        val category: String?,
        val level: Int,
        val triggerPhrases: List<Set<String>>,
        val contextPhrases: List<Set<String>>,
        val triggerBigrams: List<Set<String>>,
        val contextBigrams: List<Set<String>>,
        val hints: L2AnalysisHints?,
        // [FIX-1.2] Pre-computed: whether this scenario has required_context defined
        val hasRequiredContext: Boolean,
        // [UPGRADE-3.2] Average phrase length for dynamic threshold
        val avgPhraseLength: Float
    )

    private fun ensureInitialized() {
        if (initialized) return

        masterModel.scenarios?.forEach { scenario ->
            val triggerPhrasesTokenized = (scenario.triggerPhrases ?: emptyList())
                .map { GFlash.tokenize(it) }
                .filter { it.isNotEmpty() }

            val contextPhrasesTokenized = (scenario.requiredContext ?: emptyList())
                .map { GFlash.tokenize(it) }
                .filter { it.isNotEmpty() }

            val triggerPhrasesTokens = triggerPhrasesTokenized.map { it.toSet() }
            val contextPhrasesTokens = contextPhrasesTokenized.map { it.toSet() }

            val triggerBigrams = triggerPhrasesTokenized.map { tokens ->
                tokens.zipWithNext().map { "${it.first} ${it.second}" }.toSet()
            }
            val contextBigrams = contextPhrasesTokenized.map { tokens ->
                tokens.zipWithNext().map { "${it.first} ${it.second}" }.toSet()
            }

            // [UPGRADE-3.2] Compute average phrase size across all phrases
            val allPhraseSizes = (triggerPhrasesTokens + contextPhrasesTokens).map { it.size }
            val avgPhraseLength = if (allPhraseSizes.isNotEmpty())
                allPhraseSizes.average().toFloat() else 1f

            scenarioData[scenario.id] = ScenarioInfo(
                name = scenario.name,
                category = scenario.category,
                level = scenario.riskLevel,
                triggerPhrases = triggerPhrasesTokens,
                contextPhrases = contextPhrasesTokens,
                triggerBigrams = triggerBigrams,
                contextBigrams = contextBigrams,
                hints = scenario.l2AnalysisHints,
                hasRequiredContext = contextPhrasesTokens.isNotEmpty(),
                avgPhraseLength = avgPhraseLength
            )

            (triggerPhrasesTokens + contextPhrasesTokens).flatten().forEach { token ->
                tokenToScenarios.getOrPut(token) { mutableSetOf() }.add(scenario.id)
            }
        }

        android.util.Log.i("ScenarioMatcher", "Initialized ${scenarioData.size} scenarios (bigram + fuzzy + dynamic threshold)")
        initialized = true
    }

    fun match(transcriptTokens: List<String>): ScenarioMatch? {
        ensureInitialized()

        if (transcriptTokens.isEmpty()) return null

        val transcriptSet = transcriptTokens.toSet()
        val transcriptBigrams = transcriptTokens.zipWithNext()
            .map { "${it.first} ${it.second}" }
            .toSet()

        // Inverted index: at least 2 common tokens to be considered a candidate
        val candidateScenarios = transcriptSet
            .flatMap { token -> tokenToScenarios[token] ?: emptySet() }
            .groupingBy { it }
            .eachCount()
            .filter { it.value >= 2 }
            .keys

        var bestMatch: ScenarioMatch? = null
        var maxScore = 0f

        candidateScenarios.forEach { scenarioId ->
            val info = scenarioData[scenarioId] ?: return@forEach

            val bestTrigger = findBestPhraseMatchWithBigram(
                transcriptSet, transcriptBigrams,
                info.triggerPhrases, info.triggerBigrams
            )
            val bestContext = findBestPhraseMatchWithBigram(
                transcriptSet, transcriptBigrams,
                info.contextPhrases, info.contextBigrams
            )

            // [FIX-1.2] If scenario has required_context, at least 1 context phrase must match
            // (bestContext.first > 0 means at least 1 token overlapped)
            if (info.hasRequiredContext && bestContext.first <= 0f) {
                return@forEach // Skip: trigger matched but no context — likely false positive
            }

            val triggerPhraseSize = if (bestTrigger.second > 0) bestTrigger.second.toFloat()
            else (info.triggerPhrases.minOfOrNull { it.size }?.toFloat() ?: 0f)
            val contextPhraseSize = if (bestContext.second > 0) bestContext.second.toFloat()
            else (info.contextPhrases.minOfOrNull { it.size }?.toFloat() ?: 0f)
            val maxPossibleWeight = (triggerPhraseSize * 2.0f) + (contextPhraseSize * 1.0f)

            if (maxPossibleWeight > 0) {
                val currentWeight = (bestTrigger.first * 2.0f) + (bestContext.first * 1.0f)
                var score = (currentWeight / maxPossibleWeight).coerceAtMost(1.0f)

                // [M5] Hint bonus
                if (info.hints != null && score > 0.3f) {
                    score = applyHintBonus(score, info.hints)
                }

                // [UPGRADE-3.2] Dynamic threshold based on avg phrase length.
                // Short phrases (1–2 tokens) need higher precision (0.60).
                // Long phrases (5+ tokens) are harder to fully match, lower threshold (0.35).
                val dynamicThreshold = when {
                    info.avgPhraseLength >= 4f -> 0.35f
                    info.avgPhraseLength >= 3f -> 0.42f
                    else -> 0.55f  // Short phrases need high score to avoid false positives
                }

                if (score > dynamicThreshold && score > maxScore) {
                    maxScore = score
                    bestMatch = ScenarioMatch(
                        scenarioId = scenarioId.hashCode(),
                        situationName = info.name,
                        similarityScore = score,
                        group = info.category,
                        level = info.level
                    )
                }
            }
        }

        if (bestMatch != null) {
            android.util.Log.d(
                "ScenarioMatcher",
                "BEST: ${bestMatch?.situationName} score=${bestMatch?.similarityScore} (threshold was dynamic)"
            )
        }

        return bestMatch
    }

    /**
     * [A5 + UPGRADE-2.2] Find the best matching phrase using unigram + bigram scoring.
     * [UPGRADE-2.2] Fuzzy match: for phrases >= 3 tokens, accept if >= 75% tokens overlap.
     *
     * @return Pair(effectiveMatchScore × phraseSize, phraseSize) of the best phrase.
     */
    private fun findBestPhraseMatchWithBigram(
        transcriptSet: Set<String>,
        transcriptBigrams: Set<String>,
        phrases: List<Set<String>>,
        phraseBigrams: List<Set<String>>
    ): Pair<Float, Int> {
        if (phrases.isEmpty()) return Pair(0f, 0)

        var bestScore = 0f
        var bestPhraseSize = 0

        phrases.forEachIndexed { idx, phrase ->
            if (phrase.isEmpty()) return@forEachIndexed

            val unigramMatched = transcriptSet.intersect(phrase).size
            val unigramRatio = unigramMatched.toFloat() / phrase.size

            // [UPGRADE-2.2] Fuzzy phrase matching: accept >= 75% overlap for phrases >= 3 tokens
            // This handles STT dropping 1 word from a 4-word phrase
            val effectiveUnigramRatio = if (phrase.size >= 3 && unigramRatio >= 0.75f) {
                // Boost partial match to the same weight as full match
                minOf(unigramRatio * 1.15f, 1.0f)
            } else {
                unigramRatio
            }

            // Bigram overlap (weight: 0.3) — maintains word order awareness
            val bigrams = if (idx < phraseBigrams.size) phraseBigrams[idx] else emptySet()
            val bigramScore = if (bigrams.isNotEmpty()) {
                val bigramMatched = transcriptBigrams.intersect(bigrams).size
                bigramMatched.toFloat() / bigrams.size
            } else {
                effectiveUnigramRatio
            }

            val combinedScore = effectiveUnigramRatio * 0.7f + bigramScore * 0.3f

            if (combinedScore > bestScore) {
                bestScore = combinedScore
                bestPhraseSize = phrase.size
            }
        }

        return Pair(bestScore * bestPhraseSize, bestPhraseSize)
    }

    /**
     * [M5] Apply l2_analysis_hints bonus.
     */
    private fun applyHintBonus(baseScore: Float, hints: L2AnalysisHints): Float {
        var bonus = 0f
        if (hints.authorityClaim == true) bonus += 0.05f
        if (hints.financialRequest == true) bonus += 0.05f
        when (hints.urgencyLevel?.lowercase()) {
            "critical" -> bonus += 0.08f
            "high"     -> bonus += 0.05f
            "medium"   -> bonus += 0.02f
        }
        return (baseScore + bonus).coerceAtMost(1.0f)
    }
}
