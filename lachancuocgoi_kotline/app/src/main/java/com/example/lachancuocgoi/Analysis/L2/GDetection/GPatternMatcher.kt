package com.example.lachancuocgoi.Analysis.L2.GDetection

import com.example.lachancuocgoi.Analysis.KeywordMatch
import android.util.Log
import kotlin.math.min

object GPatternMatcher {
    private const val TAG = "GPatternMatcher"

    private val normalizedKeywordCache = mutableMapOf<String, String>()

    private fun normalizeKeyword(raw: String): String {
        return normalizedKeywordCache.getOrPut(raw) {
            GFlash.tokenize(raw).joinToString(" ")
        }
    }

    fun matchPatterns(
        tokens: List<String>,
        patterns: List<ScamPattern>,
        keywordMatches: Set<KeywordMatch>
    ): List<MatchedPattern> {
        val results = mutableListOf<MatchedPattern>()

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
                capturedElements.removeAt(capturedElements.lastIndex)
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

                val normalizedSingle = normalizeKeyword(element.value)

                val normalizedTokens = normalizedSingle.split(" ").filter { it.isNotBlank() }
                if (normalizedTokens.size == 1) {
                    tokens[index] == normalizedTokens[0]
                } else {

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
