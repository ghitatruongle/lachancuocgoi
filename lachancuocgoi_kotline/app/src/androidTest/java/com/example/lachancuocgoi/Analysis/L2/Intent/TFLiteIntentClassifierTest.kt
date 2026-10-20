package com.example.lachancuocgoi.Analysis.L2.Intent

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class TFLiteIntentClassifierTest {

    private lateinit var classifier: TFLiteIntentClassifier

    @Before
    fun setUp() {
        val appContext = InstrumentationRegistry.getInstrumentation().targetContext
        classifier = TFLiteIntentClassifier(appContext)
    }

    @After
    fun tearDown() {
        classifier.close()
    }

    @Test
    fun testClassifierInitialization() {

        val predictions = classifier.predictIntent("xin chào bạn")
        assertTrue("Predictions should not be empty", predictions.isNotEmpty())

        val topPrediction = predictions.first()
        assertTrue("Confidence should be >= 0", topPrediction.confidence >= 0f)
        assertTrue("Confidence should be <= 1", topPrediction.confidence <= 1f)
    }

    @Test
    fun testScamIntentDetection() {

        val predictions = classifier.predictIntent("bạn cần chuyển tiền ngay lập tức vào tài khoản này")
        assertTrue(predictions.isNotEmpty())
    }
}
