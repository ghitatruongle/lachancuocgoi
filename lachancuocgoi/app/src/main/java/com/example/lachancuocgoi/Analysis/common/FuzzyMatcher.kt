package com.example.lachancuocgoi.Analysis.common

/**
 * Fuzzy matching sử dụng Levenshtein distance cho STT errors.
 * Dùng khi Aho-Corasick exact match thất bại → thử matching gần đúng.
 */
object FuzzyMatcher {

    /**
     * Tính khoảng cách Levenshtein (edit distance) giữa 2 chuỗi.
     * Early exit nếu vượt maxDistance.
     */
    fun levenshtein(a: String, b: String, maxDistance: Int = 2): Int {
        if (a == b) return 0
        if (a.isEmpty()) return b.length.coerceAtMost(maxDistance + 1)
        if (b.isEmpty()) return a.length.coerceAtMost(maxDistance + 1)

        val lenDiff = kotlin.math.abs(a.length - b.length)
        if (lenDiff > maxDistance) return maxDistance + 1

        // DP với 2 hàng để tiết kiệm memory
        var prev = IntArray(a.length + 1) { it }
        var curr = IntArray(a.length + 1)

        for (j in 1..b.length) {
            curr[0] = j
            var minVal = j
            for (i in 1..a.length) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                curr[i] = minOf(
                    curr[i - 1] + 1,       // insert
                    prev[i] + 1,            // delete
                    prev[i - 1] + cost      // replace
                )
                minVal = minOf(minVal, curr[i])
            }
            // Early exit: nếu minVal trong hàng đã vượt maxDistance
            if (minVal > maxDistance) return maxDistance + 1
            val tmp = prev
            prev = curr
            curr = tmp
        }
        return prev[a.length]
    }

    /**
     * Tìm token gần nhất trong danh sách từ khóa.
     * @param token Token cần tìm (đã normalize)
     * @param candidates Danh sách từ khóa ứng viên (đã normalize)
     * @param maxDistance Khoảng cách tối đa cho phép (mặc định 2 cho STT errors)
     * @return Từ khóa khớp gần nhất, hoặc null nếu không tìm thấy
     */
    fun findClosest(token: String, candidates: Collection<String>, maxDistance: Int = 2): String? {
        var bestMatch: String? = null
        var bestDist = maxDistance + 1

        for (candidate in candidates) {
            // Quick length check trước khi tính DP
            if (kotlin.math.abs(token.length - candidate.length) > maxDistance) continue
            val dist = damerauLevenshtein(token, candidate, maxDistance)
            if (dist < bestDist) {
                bestDist = dist
                bestMatch = candidate
            }
        }
        return if (bestDist <= maxDistance) bestMatch else null
    }

    /**
     * Tính khoảng cách Damerau-Levenshtein (Extended Levenshtein).
     * Bao gồm cả transposition (hoán đổi 2 ký tự liền nhau).
     * Rất hữu ích cho STT errors vì tính nature của speech recognition.
     */
    fun damerauLevenshtein(a: String, b: String, maxDistance: Int = 2): Int {
        if (a == b) return 0
        if (a.isEmpty()) return b.length.coerceAtMost(maxDistance + 1)
        if (b.isEmpty()) return a.length.coerceAtMost(maxDistance + 1)

        val lenDiff = kotlin.math.abs(a.length - b.length)
        if (lenDiff > maxDistance) return maxDistance + 1

        val aLen = a.length
        val bLen = b.length

        // DP với full matrix cho Damerau-Levenshtein
        val dp = Array(aLen + 1) { IntArray(bLen + 1) { 0 } }

        for (i in 0..aLen) dp[i][0] = i
        for (j in 0..bLen) dp[0][j] = j

        for (i in 1..aLen) {
            for (j in 1..bLen) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                dp[i][j] = minOf(
                    dp[i - 1][j] + 1,        // deletion
                    dp[i][j - 1] + 1,        // insertion
                    dp[i - 1][j - 1] + cost  // substitution
                )
                // Transposition (hoán đổi 2 ký tự liền nhau)
                if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
                    dp[i][j] = minOf(dp[i][j], dp[i - 2][j - 2] + cost)
                }
            }
        }

        return dp[aLen][bLen]
    }
}
