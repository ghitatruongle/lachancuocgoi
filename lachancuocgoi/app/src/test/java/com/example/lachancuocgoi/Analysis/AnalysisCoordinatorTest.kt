package com.example.lachancuocgoi.Analysis

import android.content.Context
import com.example.lachancuocgoi.Analysis.L1.L1Analyzer
import com.example.lachancuocgoi.Analysis.L2.L2Analyzer
import com.example.lachancuocgoi.Analysis.L3.L3Analyzer
import com.example.lachancuocgoi.RiskLevel
import com.example.lachancuocgoi.ui.HomePage.SettingsDialog.AnalysisMode
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.MockitoAnnotations
import org.mockito.kotlin.any

class AnalysisCoordinatorTest {

    @Mock
    private lateinit var mockContext: Context
    @Mock
    private lateinit var mockL1: L1Analyzer
    @Mock
    private lateinit var mockL2: L2Analyzer
    @Mock
    private lateinit var mockL3: L3Analyzer

    private lateinit var coordinator: AnalysisCoordinator

    @Before
    fun setup() {
        MockitoAnnotations.openMocks(this)
        // Note: AnalysisCoordinator creates its own analyzers, but we can use reflection 
        // or refactor it to accept them. Let's refactor it slightly to allow injecting mock analyzers.
        coordinator = AnalysisCoordinator(mockContext)
        
        // Use reflection to inject mocks for testing
        val l1Field = coordinator.javaClass.getDeclaredField("l1Analyzer")
        l1Field.isAccessible = true
        l1Field.set(coordinator, mockL1)

        val l2Field = coordinator.javaClass.getDeclaredField("l2Analyzer")
        l2Field.isAccessible = true
        l2Field.set(coordinator, mockL2)

        val l3Field = coordinator.javaClass.getDeclaredField("l3Analyzer")
        l3Field.isAccessible = true
        l3Field.set(coordinator, mockL3)
    }

    @Test
    fun testAnalyzeIncremental_Windowing() = runBlocking {
        `when`(mockL2.isReady()).thenReturn(true)
        `when`(mockL2.analyze(any(), any())).thenReturn(AnalysisResult(RiskLevel.GREEN, emptyList()))

        // 1. First analysis
        val text1 = "Đây là đoạn văn bản đầu tiên."
        coordinator.analyzeIncremental(text1, AnalysisMode.GDetection)
        assertEquals(text1.length, coordinator.getProcessedTextLength())

        // 2. Second analysis with new text
        val text2 = text1 + " Đây là đoạn văn bản thứ hai."
        coordinator.analyzeIncremental(text2, AnalysisMode.GDetection)
        assertEquals(text2.length, coordinator.getProcessedTextLength())
    }

    @Test
    fun testAnalyzeIncremental_L3_Threshold() = runBlocking {
        `when`(mockL3.analyze(any())).thenReturn(AnalysisResult(RiskLevel.GREEN, emptyList()))

        // L3 has a threshold of 50 chars for incremental updates
        val textShort = "Đoạn ngắn."
        val result = coordinator.analyzeIncremental(textShort, AnalysisMode.GEMINI_API)
        
        // Should return lastResult (GREEN) and NOT update processedTextLength
        assertEquals(0, coordinator.getProcessedTextLength())
        assertEquals(RiskLevel.GREEN, result.overallRiskLevel)

        val textLong = "Đây là một đoạn văn bản dài hơn 50 ký tự để kiểm tra threshold của L3........................................"
        coordinator.analyzeIncremental(textLong, AnalysisMode.GEMINI_API)
        assertEquals(textLong.length, coordinator.getProcessedTextLength())
    }

    @Test
    fun testReset() = runBlocking {
        coordinator.analyzeIncremental("Văn bản test", AnalysisMode.NORMAL)
        assertTrue(coordinator.getProcessedTextLength() > 0)
        
        coordinator.reset()
        assertEquals(0, coordinator.getProcessedTextLength())
    }
}
