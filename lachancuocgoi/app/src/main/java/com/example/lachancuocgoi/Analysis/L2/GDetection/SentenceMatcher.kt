package com.example.lachancuocgoi.Analysis.L2.GDetection

import com.example.lachancuocgoi.RiskLevel

/**
 * [A4 UPGRADE] Tìm kiếm các câu thoại từ risk_model_sentences.json.
 * Sử dụng Trie với noise-tolerant matching (cho phép skip 1 token nhiễu từ STT).
 * Tìm match DÀI NHẤT thay vì match ĐẦU TIÊN [E2].
 */
class SentenceMatcher(private val model: RiskModelSentences) {

    private val safeSentenceTrie = TrieNode()
    private val threatSentenceTrieByLevel = mutableMapOf<RiskLevel, TrieNode>()
    private var initialized = false

    // Số token noise tối đa được phép skip (STT hay chen "ờ", "ừm", "à")
    private val maxSkipTokens = 1

    /**
     * Lazy initialization - chỉ build Trie khi match() được gọi lần đầu.
     */
    private fun ensureInitialized() {
        if (initialized) return
        
        model.riskLevels?.forEach { levelData ->
            val level = RiskLevel.fromInt(levelData.level)
            
            // Level 0: Safe Sentences
            if (level == RiskLevel.GREEN) {
                levelData.sentences?.forEach { sentence ->
                    val tokens = GFlash.tokenize(sentence)
                    if (tokens.isNotEmpty()) {
                        insertIntoTrie(safeSentenceTrie, tokens, sentence)
                    }
                }
            } else {
                // Levels 1, 2, 3: Threat Sentences
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

    /**
     * Tìm kiếm câu phù hợp nhất bằng cách duyệt qua transcript với Trie.
     */
    fun match(transcriptTokens: List<String>): SentenceMatch? {
        ensureInitialized()
        
        if (transcriptTokens.isEmpty()) return null
        
        // 1. Check Safe Sentences First (High Priority to reduce FP)
        searchInTrieFuzzy(safeSentenceTrie, transcriptTokens)?.let { sentence ->
            return SentenceMatch(sentence, 0, isSafe = true)
        }

        // 2. Check Threat Sentences (High Risk first)
        val riskLevels = listOf(RiskLevel.RED, RiskLevel.ORANGE, RiskLevel.YELLOW)
        for (level in riskLevels) {
            val trie = threatSentenceTrieByLevel[level] ?: continue
            searchInTrieFuzzy(trie, transcriptTokens)?.let { sentence ->
                return SentenceMatch(sentence, level.level, isSafe = false)
            }
        }
        
        return null
    }

    /**
     * [A4+E2] Noise-tolerant Trie search + longest match.
     * Cho phép skip tối đa `maxSkipTokens` token nhiễu (ờ, ừm, à, ...) giữa các token khớp.
     * Trả về match DÀI NHẤT thay vì match đầu tiên.
     */
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

    /**
     * Recursive search qua Trie với skip tolerance.
     * @param node Current trie node
     * @param tokens Full transcript token list
     * @param idx Current position in tokens
     * @param skipsUsed Number of skips used so far
     * @return Matched sentence string or null
     */
    private fun searchRecursive(
        node: TrieNode,
        tokens: List<String>,
        idx: Int,
        skipsUsed: Int
    ): String? {
        // Tìm match dài nhất: continue matching even after finding a sentence
        var bestMatch = node.sentence
        
        if (idx >= tokens.size) return bestMatch
        
        val token = tokens[idx]
        
        // Path 1: Exact match — token khớp trực tiếp
        node.children[token]?.let { child ->
            val childResult = searchRecursive(child, tokens, idx + 1, skipsUsed)
            if (childResult != null && (bestMatch == null || childResult.length > bestMatch!!.length)) {
                bestMatch = childResult
            }
        }
        
        // Path 2: Skip — bỏ qua token hiện tại (noise từ STT: "ờ", "ừm", "à", "ạ")
        // Chỉ skip nếu chưa dùng hết quota VÀ token tiếp theo có thể match
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

    /**
     * Internal Trie node for sentence matching.
     */
    private class TrieNode {
        val children = mutableMapOf<String, TrieNode>()
        var sentence: String? = null
    }
}
