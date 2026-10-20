package com.example.lachancuocgoi.Analysis.L2.GDetection

import com.example.lachancuocgoi.RiskLevel

class SentenceMatcher(private val model: RiskModelSentences) {

    private val safeSentenceTrie = TrieNode()
    private val threatSentenceTrieByLevel = mutableMapOf<RiskLevel, TrieNode>()
    private var initialized = false

    private val maxSkipTokens = 1

    private fun ensureInitialized() {
        if (initialized) return

        model.riskLevels?.forEach { levelData ->
            val level = RiskLevel.fromInt(levelData.level)

            if (level == RiskLevel.GREEN) {
                levelData.sentences?.forEach { sentence ->
                    val tokens = GFlash.tokenize(sentence)
                    if (tokens.isNotEmpty()) {
                        insertIntoTrie(safeSentenceTrie, tokens, sentence)
                    }
                }
            } else {

                val trie = threatSentenceTrieByLevel.getOrPut(level) { TrieNode() }
                levelData.threats?.values?.flatten()?.forEach { sentence ->
                    val tokens = GFlash.tokenize(sentence)
                    if (tokens.isNotEmpty()) {
                        insertIntoTrie(trie, tokens, sentence)
                    }
                }
            }
        }
        initialized = true
    }

    private fun insertIntoTrie(root: TrieNode, tokens: List<String>, originalSentence: String) {
        var node = root
        tokens.forEach { token ->
            node = node.children.getOrPut(token) { TrieNode() }
        }
        node.sentence = originalSentence
    }

    fun match(transcriptTokens: List<String>): SentenceMatch? {
        ensureInitialized()

        if (transcriptTokens.isEmpty()) return null

        searchInTrieFuzzy(safeSentenceTrie, transcriptTokens)?.let { sentence ->
            return SentenceMatch(sentence, 0, isSafe = true)
        }

        val riskLevels = listOf(RiskLevel.RED, RiskLevel.ORANGE, RiskLevel.YELLOW)
        for (level in riskLevels) {
            val trie = threatSentenceTrieByLevel[level] ?: continue
            searchInTrieFuzzy(trie, transcriptTokens)?.let { sentence ->
                return SentenceMatch(sentence, level.level, isSafe = false)
            }
        }

        return null
    }

    private fun searchInTrieFuzzy(root: TrieNode, tokens: List<String>): String? {
        var longestMatch: String? = null

        for (startIdx in tokens.indices) {
            val result = searchRecursive(root, tokens, startIdx, 0)
            if (result != null) {
                if (longestMatch == null || result.length > longestMatch.length) {
                    longestMatch = result
                }
            }
        }
        return longestMatch
    }

    private fun searchRecursive(
        node: TrieNode,
        tokens: List<String>,
        idx: Int,
        skipsUsed: Int
    ): String? {

        var bestMatch = node.sentence

        if (idx >= tokens.size) return bestMatch

        val token = tokens[idx]

        node.children[token]?.let { child ->
            val childResult = searchRecursive(child, tokens, idx + 1, skipsUsed)
            if (childResult != null && (bestMatch == null || childResult.length > bestMatch!!.length)) {
                bestMatch = childResult
            }
        }

        if (skipsUsed < maxSkipTokens && idx + 1 < tokens.size) {
            val nextToken = tokens[idx + 1]
            node.children[nextToken]?.let { child ->
                val skipResult = searchRecursive(child, tokens, idx + 2, skipsUsed + 1)
                if (skipResult != null && (bestMatch == null || skipResult.length > bestMatch!!.length)) {
                    bestMatch = skipResult
                }
            }
        }

        return bestMatch
    }

    private class TrieNode {
        val children = mutableMapOf<String, TrieNode>()
        var sentence: String? = null
    }
}
