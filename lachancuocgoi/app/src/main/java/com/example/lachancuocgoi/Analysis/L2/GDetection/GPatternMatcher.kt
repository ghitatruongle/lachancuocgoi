package com.example.lachancuocgoi.Analysis.L2.GDetection

import com.example.lachancuocgoi.Analysis.KeywordMatch
import android.util.Log
import kotlin.math.min

/**
 * [B3 UPGRADE] Engine tìm kiếm mẫu câu trong văn bản đã token hóa.
 * [FIX] Pattern keyword được normalize qua GFlash trước khi so khớp với tokens.
 */
object GPatternMatcher {
    private const val TAG = "GPatternMatcher"

    /**
     * Cache normalized keywords để tránh re-tokenize mỗi lần call.
     * Key = raw keyword string, Value = first token (hoặc joined tokens).
     */
    private val normalizedKeywordCache = mutableMapOf<String, String>()

    private fun normalizeKeyword(raw: String): String {
        return normalizedKeywordCache.getOrPut(raw) {
            GFlash.tokenize(raw).joinToString(" ")
        }
    }

    /**
     * Tìm kiếm các mẫu câu trong văn bản.
     * keywordMatches: Set các keyword L2 đã tìm thấy trong transcript (với index)
     */
    fun matchPatterns(
        tokens: List<String>,
        patterns: List<ScamPattern>,
        keywordMatches: Set<KeywordMatch>
    ): List<MatchedPattern> {
        val results = mutableListOf<MatchedPattern>()

        // Build map for efficient lookup: Index -> List<KeywordMatch> starting at this index
        val matchesByIndex = keywordMatches.groupBy { it.startIndex }

        patterns.forEach { pattern ->
            val capturedElements = mutableListOf<String>()
            if (matchSinglePattern(tokens, pattern, matchesByIndex, capturedElements)) {
                results.add(
                    MatchedPattern(
                        patternId = pattern.id,
                        matchedElements = capturedElements.toList(),
                        score = pattern.riskBonus
                    )
                )
                Log.d(TAG, "Pattern matched: ${pattern.id} → [${capturedElements.joinToString(" ... ")}]")
            }
        }

        return results
    }

    private fun matchSinglePattern(
        tokens: List<String>,
        pattern: ScamPattern,
        matchesByIndex: Map<Int, List<KeywordMatch>>,
        capturedElements: MutableList<String>
    ): Boolean {
        val firstElement = pattern.template.firstOrNull() ?: return false

        for (i in tokens.indices) {
            if (checkElementAt(i, firstElement, tokens, matchesByIndex)) {
                capturedElements.clear()
                capturedElements.add(tokens[i])
                if (matchRemainingSequence(i, 1, tokens, pattern, matchesByIndex, capturedElements)) {
                    return true
                }
            }
        }
        capturedElements.clear()
        return false
    }

    private fun matchRemainingSequence(
        currentIndex: Int,
        patternIndex: Int,
        tokens: List<String>,
        pattern: ScamPattern,
        matchesByIndex: Map<Int, List<KeywordMatch>>,
        capturedElements: MutableList<String>
    ): Boolean {
        if (patternIndex >= pattern.template.size) return true

        val targetElement = pattern.template[patternIndex]
        val searchStart = currentIndex + 1
        val searchEnd = min(tokens.size, searchStart + pattern.maxGap + 1)

        for (nextIndex in searchStart until searchEnd) {
            if (checkElementAt(nextIndex, targetElement, tokens, matchesByIndex)) {
                capturedElements.add(tokens[nextIndex])
                if (matchRemainingSequence(nextIndex, patternIndex + 1, tokens, pattern, matchesByIndex, capturedElements)) {
                    return true
                }
                capturedElements.removeAt(capturedElements.lastIndex) // Backtrack
            }
        }

        return false
    }

    private fun checkElementAt(
        index: Int,
        element: PatternElement,
        tokens: List<String>,
        matchesByIndex: Map<Int, List<KeywordMatch>>
    ): Boolean {
        if (index >= tokens.size) return false

        return when (element) {
            is PatternElement.Keyword -> {
                // [FIX - Critical] Normalize the pattern keyword via GFlash before comparing.
                // tokens[] are already normalized (lowercase, no diacritics, slang-replaced).
                // Previously element.value was raw Vietnamese → never matched normalized tokens.
                // Now we normalize the keyword to match, and also try single-token prefix match
                // for multi-word keywords stored as a single phrase.
                val normalizedSingle = normalizeKeyword(element.value)
                // normalizedSingle may be multi-word (e.g. "chuyen tien"), but tokens[index]
                // is a single token. So we only match if normalizedSingle is exactly one token.
                val normalizedTokens = normalizedSingle.split(" ").filter { it.isNotBlank() }
                if (normalizedTokens.size == 1) {
                    tokens[index] == normalizedTokens[0]
                } else {
                    // Multi-word keyword: match the first token here; remaining tokens will be
                    // matched via sequential wildcard steps added by GDetectionEngine at load time.
                    // For now fall back to prefix-match of the first token.
                    tokens[index] == (normalizedTokens.firstOrNull() ?: "")
                }
            }
            is PatternElement.Category -> {
                val matchesHere = matchesByIndex[index]
                matchesHere?.any { it.category.equals(element.categoryName, ignoreCase = true) } == true
            }
            is PatternElement.Wildcard -> true
        }
    }
}
