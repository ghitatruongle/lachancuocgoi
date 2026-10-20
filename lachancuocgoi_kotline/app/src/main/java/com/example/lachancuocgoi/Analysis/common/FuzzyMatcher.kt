package com.example.lachancuocgoi.Analysis.common

object FuzzyMatcher {

    fun levenshtein(a: String, b: String, maxDistance: Int = 2): Int {
        if (a == b) return 0
        if (a.isEmpty()) return b.length.coerceAtMost(maxDistance + 1)
        if (b.isEmpty()) return a.length.coerceAtMost(maxDistance + 1)

        val lenDiff = kotlin.math.abs(a.length - b.length)
        if (lenDiff > maxDistance) return maxDistance + 1

        var prev = IntArray(a.length + 1) { it }
        var curr = IntArray(a.length + 1)

        for (j in 1..b.length) {
            curr[0] = j
            var minVal = j
            for (i in 1..a.length) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                curr[i] = minOf(
                    curr[i - 1] + 1,
                    prev[i] + 1,
                    prev[i - 1] + cost
                )
                minVal = minOf(minVal, curr[i])
            }

            if (minVal > maxDistance) return maxDistance + 1
            val tmp = prev
            prev = curr
            curr = tmp
        }
        return prev[a.length]
    }

    fun findClosest(token: String, candidates: Collection<String>, maxDistance: Int = 2): String? {
        var bestMatch: String? = null
        var bestDist = maxDistance + 1

        for (candidate in candidates) {

            if (kotlin.math.abs(token.length - candidate.length) > maxDistance) continue
            val dist = damerauLevenshtein(token, candidate, maxDistance)
            if (dist < bestDist) {
                bestDist = dist
                bestMatch = candidate
            }
        }
        return if (bestDist <= maxDistance) bestMatch else null
    }

    fun damerauLevenshtein(a: String, b: String, maxDistance: Int = 2): Int {
        if (a == b) return 0
        if (a.isEmpty()) return b.length.coerceAtMost(maxDistance + 1)
        if (b.isEmpty()) return a.length.coerceAtMost(maxDistance + 1)

        val lenDiff = kotlin.math.abs(a.length - b.length)
        if (lenDiff > maxDistance) return maxDistance + 1

        val aLen = a.length
        val bLen = b.length

        val dp = Array(aLen + 1) { IntArray(bLen + 1) { 0 } }

        for (i in 0..aLen) dp[i][0] = i
        for (j in 0..bLen) dp[0][j] = j

        for (i in 1..aLen) {
            for (j in 1..bLen) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                dp[i][j] = minOf(
                    dp[i - 1][j] + 1,
                    dp[i][j - 1] + 1,
                    dp[i - 1][j - 1] + cost
                )

                if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
                    dp[i][j] = minOf(dp[i][j], dp[i - 2][j - 2] + cost)
                }
            }
        }

        return dp[aLen][bLen]
    }
}
