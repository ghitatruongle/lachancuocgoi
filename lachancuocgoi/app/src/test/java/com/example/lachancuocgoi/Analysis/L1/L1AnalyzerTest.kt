package com.example.lachancuocgoi.Analysis.L1

import android.content.Context
import com.example.lachancuocgoi.RiskLevel
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.MockitoAnnotations
import java.io.ByteArrayInputStream

class L1AnalyzerTest {

    @Mock
    private lateinit var mockContext: Context

    private lateinit var l1Analyzer: L1Analyzer

    private val testVocabularyJson = """
        {
          "riskLevels": [
            {
              "level": 3,
              "threats": {
                "Tài chính": ["chuyển tiền", "tài khoản ngân hàng"],
                "Giả danh": ["công an", "viện kiểm sát"]
              }
            },
            {
              "level": 2,
              "keywords": ["khuyến mãi", "trúng thưởng"]
            }
          ]
        }
    """.trimIndent()

    @Before
    fun setup() {
        MockitoAnnotations.openMocks(this)
        l1Analyzer = L1Analyzer(mockContext)
        // Inject test vocabulary
        l1Analyzer.setVocabularyProvider {
            ByteArrayInputStream(testVocabularyJson.toByteArray())
        }
    }

    @Test
    fun testAnalyze_MatchSingleKeyword() = runBlocking {
        val text = "Chào anh, tôi gọi từ công an quận 1."
        val result = l1Analyzer.analyze(text)
        
        assertEquals(RiskLevel.YELLOW, result.overallRiskLevel)
        assertTrue(result.matches.any { it.keyword == "công an" })
    }

    @Test
    fun testAnalyze_MatchMultipleKeywords() = runBlocking {
        val text = "Yêu cầu anh chuyển tiền vào tài khoản ngân hàng của chúng tôi."
        val result = l1Analyzer.analyze(text)
        
        assertEquals(RiskLevel.RED, result.overallRiskLevel)
        assertTrue(result.matches.any { it.keyword == "chuyển tiền" })
        assertTrue(result.matches.any { it.keyword == "tài khoản ngân hàng" })
    }

    @Test
    fun testAnalyze_NormalKeyword() = runBlocking {
        val text = "Chúc mừng anh đã nhận được khuyến mãi lớn."
        val result = l1Analyzer.analyze(text)
        
        assertEquals(RiskLevel.YELLOW, result.overallRiskLevel)
        assertTrue(result.matches.any { it.keyword == "khuyến mãi" })
    }

    @Test
    fun testAnalyze_NoMatch() = runBlocking {
        val text = "Chào buổi sáng, hôm nay trời đẹp quá."
        val result = l1Analyzer.analyze(text)
        
        assertEquals(RiskLevel.GREEN, result.overallRiskLevel)
        assertTrue(result.matches.isEmpty())
    }

    @Test
    fun testAnalyze_Normalization() = runBlocking {
        // Test with diacritics and uppercase
        val text = "CHUYỂN TIỀN gấp!!!"
        val result = l1Analyzer.analyze(text)
        
        assertEquals(RiskLevel.YELLOW, result.overallRiskLevel)
        assertTrue(result.matches.any { it.keyword == "chuyển tiền" })
    }
}
