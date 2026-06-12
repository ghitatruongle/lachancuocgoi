package com.example.lachancuocgoi.Analysis.L2.GDetection

import android.content.Context
import com.example.lachancuocgoi.RiskLevel
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.Mock
import org.mockito.MockitoAnnotations
import java.io.ByteArrayInputStream

class GDetectionEngineTest {

    @Mock
    private lateinit var mockContext: Context

    private lateinit var gDetectionEngine: GDetectionEngine

    // FIX: JSON format khớp đúng với data models thực tế
    private val vocabularyJson = """
        {
          "riskLevels": [
            {
              "level": 3,
              "threats": {
                "Tài chính": ["chuyển tiền", "tài khoản ngân hàng"]
              }
            }
          ]
        }
    """.trimIndent()

    private val scoringConfigJson = """
        {
          "topicConfirmationThreshold": 3,
          "scenarioSimilarityThreshold": 0.3,
          "scenario_alert_threshold": 0.6,
          "high_keyword_threshold": 0.5,
          "riskLevelThresholds": {
            "red": 0.70,
            "orange": 0.50,
            "yellow": 0.30
          },
          "weights": {
            "keyword": 0.25,
            "topic": 0.20,
            "pattern": 0.25,
            "scenario": 0.20,
            "context": 0.10
          }
        }
    """.trimIndent()

    private val patternsJson = """
        {
          "patterns": [
            {
              "id": "P1",
              "description": "Yêu cầu chuyển tiền ngay lập tức",
              "risk_bonus": 0.5,
              "min_gap": 0,
              "max_gap": 5,
              "template": [
                {"type": "keyword", "value": "chuyen"},
                {"type": "keyword", "value": "tien"},
                {"type": "keyword", "value": "gap"}
              ]
            }
          ]
        }
    """.trimIndent()

    // FIX: Dùng đúng field names của RiskScenariosMaster/MasterScenario model
    private val masterScenariosJson = """
        {
          "title": "Test Scenarios",
          "version": "1.0",
          "total_scenarios": 1,
          "scenarios": [
            {
              "id": "S1",
              "name": "Gia danh cong an",
              "risk_level": 3,
              "risk_level_name": "Nguy hiểm",
              "risk_color": "RED",
              "category": "Giả danh cơ quan",
              "trigger_phrases": ["cong an", "vien kiem sat"],
              "required_context": ["lenh bat", "dieu tra"]
            }
          ]
        }
    """.trimIndent()

    // FIX: Dùng đúng format RiskModelSentences (riskLevels, not sentences)
    private val sentencesJson = """
        {
          "riskLevels": []
        }
    """.trimIndent()

    private val slangJson = """
        {
          "slang_map": {
            "chuyển": "chuyển",
            "tiền": "tiền"
          }
        }
    """.trimIndent()

    @Before
    fun setup() {
        MockitoAnnotations.openMocks(this)
        gDetectionEngine = GDetectionEngine(mockContext)
        
        gDetectionEngine.setInputStreamProvider { fileName ->
            val content = when (fileName) {
                "risk_model_vocabulary.json" -> vocabularyJson
                "scoring_config.json" -> scoringConfigJson
                "phrase_patterns.json" -> patternsJson
                "risk_scenarios_master.json" -> masterScenariosJson
                "risk_model_sentences.json" -> sentencesJson
                "slang_config.json" -> slangJson
                else -> "{}"
            }
            ByteArrayInputStream(content.toByteArray())
        }
        
        // Initialize synchronously for testing
        runBlocking {
            gDetectionEngine.initialize()
        }
    }

    @Test
    fun testPerformFullAnalysis_BasicMatch() = runBlocking {
        // Wait for initialize to complete (async via engineScope.launch + Mutex)
        var retries = 0
        while (!gDetectionEngine.isEngineReady() && retries < 20) {
            kotlinx.coroutines.delay(100)
            retries++
        }
        
        assertTrue("Engine should be ready", gDetectionEngine.isEngineReady())

        val text = "Yêu cầu chuyển tiền vào tài khoản."
        val result = gDetectionEngine.performFullAnalysis(text)
        
        // With RED level keywords ("chuyển tiền", "tài khoản ngân hàng"), should trigger risk
        assertNotEquals(RiskLevel.GREEN, result.riskLevel)
    }

    @Test
    fun testPerformFullAnalysis_PatternMatch() = runBlocking {
        var retries = 0
        while (!gDetectionEngine.isEngineReady() && retries < 20) {
            kotlinx.coroutines.delay(100)
            retries++
        }

        val text = "Anh phải chuyển tiền gấp để xử lý vụ việc."
        val result = gDetectionEngine.performFullAnalysis(text)
        
        // Pattern "chuyen tien gap" is RED
        assertEquals(RiskLevel.RED, result.riskLevel)
    }

    @Test
    fun testPerformFullAnalysis_ScenarioMatch() = runBlocking {
        var retries = 0
        while (!gDetectionEngine.isEngineReady() && retries < 20) {
            kotlinx.coroutines.delay(100)
            retries++
        }

        val text = "Tôi là công an đây, chúng tôi đang điều tra lệnh bắt."
        val result = gDetectionEngine.performFullAnalysis(text)
        
        // Scenario "Gia danh cong an" is RED
        assertEquals(RiskLevel.RED, result.riskLevel)
    }

    @Test
    fun testPerformFullAnalysis_SafeText() = runBlocking {
        var retries = 0
        while (!gDetectionEngine.isEngineReady() && retries < 20) {
            kotlinx.coroutines.delay(100)
            retries++
        }

        val text = "Hôm nay trời đẹp quá, mình đi ăn cơm nhé."
        val result = gDetectionEngine.performFullAnalysis(text)
        
        // Safe text should be GREEN
        assertEquals(RiskLevel.GREEN, result.riskLevel)
    }
}
