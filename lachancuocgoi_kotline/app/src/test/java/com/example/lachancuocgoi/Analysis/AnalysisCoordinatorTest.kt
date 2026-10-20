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
import org.mockito.kotlin.whenever

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

    private var l1Length = 0
    private var l2Length = 0
    private var l3Length = 0
    private val defaultResult = AnalysisResult(RiskLevel.GREEN, emptyList())

    @Before
    fun setup() {
        runBlocking {
            MockitoAnnotations.openMocks(this@AnalysisCoordinatorTest)
            l1Length = 0
            l2Length = 0
            l3Length = 0

            coordinator = AnalysisCoordinator(mockContext)

            val l1Field = coordinator.javaClass.getDeclaredField("l1Analyzer")
            l1Field.isAccessible = true
            l1Field.set(coordinator, mockL1)

            val l2Field = coordinator.javaClass.getDeclaredField("l2Analyzer")
            l2Field.isAccessible = true
            l2Field.set(coordinator, mockL2)

            val l3Field = coordinator.javaClass.getDeclaredField("l3Analyzer")
            l3Field.isAccessible = true
            l3Field.set(coordinator, mockL3)

            `when`(mockL1.getLastResult()).thenReturn(defaultResult)
            `when`(mockL1.getProcessedTextLength()).thenAnswer { l1Length }
            `when`(mockL1.resetSession()).thenAnswer { l1Length = 0 }
            whenever(mockL1.analyzeStream(any())).thenAnswer { invocation ->
                val text = invocation.getArgument<String>(0)
                l1Length = text.length
                defaultResult
            }

            `when`(mockL2.getLastResult()).thenReturn(defaultResult)
            `when`(mockL2.getProcessedTextLength()).thenAnswer { l2Length }
            `when`(mockL2.resetSession()).thenAnswer { l2Length = 0 }
            `when`(mockL2.isReady()).thenReturn(true)
            whenever(mockL2.analyze(any(), any())).thenAnswer { invocation ->
                val fullText = invocation.getArgument<String>(1)
                l2Length = fullText.length
                defaultResult
            }

            `when`(mockL3.getLastResult()).thenReturn(defaultResult)
            `when`(mockL3.getProcessedTextLength()).thenAnswer { l3Length }
            `when`(mockL3.resetSession()).thenAnswer { l3Length = 0 }
            whenever(mockL3.analyze(any())).thenAnswer { invocation ->
                val text = invocation.getArgument<String>(0)
                l3Length += text.length
                defaultResult
            }
        }
    }

    @Test
    fun testAnalyzeIncremental_Windowing() = runBlocking {
        val text1 = "Đây là đoạn văn bản đầu tiên."
        coordinator.analyzeIncremental(text1, AnalysisMode.GDetection)
        assertEquals(text1.length, coordinator.getProcessedTextLength(AnalysisMode.GDetection))

        val text2 = text1 + " Đây là đoạn văn bản thứ hai."
        coordinator.analyzeIncremental(text2, AnalysisMode.GDetection)
        assertEquals(text2.length, coordinator.getProcessedTextLength(AnalysisMode.GDetection))
    }

    @Test
    fun testAnalyzeIncremental_L3_Threshold() = runBlocking {
        val textShort = "Đoạn ngắn."
        val result = coordinator.analyzeIncremental(textShort, AnalysisMode.GEMINI_API)

        assertEquals(0, coordinator.getProcessedTextLength(AnalysisMode.GEMINI_API))
        assertEquals(RiskLevel.GREEN, result.overallRiskLevel)

        val textLong = "Đây là một đoạn văn bản dài hơn 50 ký tự để kiểm tra threshold của L3........................................"
        coordinator.analyzeIncremental(textLong, AnalysisMode.GEMINI_API)
        assertEquals(textLong.length, coordinator.getProcessedTextLength(AnalysisMode.GEMINI_API))
    }

    @Test
    fun testReset() = runBlocking {
        coordinator.analyzeIncremental("Văn bản test", AnalysisMode.NORMAL)
        assertTrue(coordinator.getProcessedTextLength(AnalysisMode.NORMAL) > 0)

        coordinator.reset()
        assertEquals(0, coordinator.getProcessedTextLength(AnalysisMode.NORMAL))
    }
}
