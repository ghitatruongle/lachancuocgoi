package com.lachancuocgoi.lachancuocgoi_flutter.services.stt

import android.speech.SpeechRecognizer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SttErrorClassifierTest {
    @Test
    fun networkAndBusyAreRetryable() {
        assertTrue(SttErrorClassifier.isRetryable(SpeechRecognizer.ERROR_NETWORK))
        assertTrue(SttErrorClassifier.isRetryable(SpeechRecognizer.ERROR_RECOGNIZER_BUSY))
        assertTrue(
            SttErrorClassifier.isRetryable(SttErrorClassifier.ERROR_LANGUAGE_UNAVAILABLE_COMPAT),
        )
        assertFalse(
            SttErrorClassifier.isRetryable(SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS),
        )
    }

    @Test
    fun describeKnownCodes() {
        assertTrue(SttErrorClassifier.describe(SpeechRecognizer.ERROR_NETWORK).contains("Network"))
        assertTrue(SttErrorClassifier.describe(99).contains("Unknown"))
    }
}

class SttRestartPolicyTest {
    @Test
    fun networkThresholdTriggersVosk() {
        val p = SttRestartPolicy(networkFallbackThreshold = 3)
        p.onError(SpeechRecognizer.ERROR_NETWORK, false)
        p.onError(SpeechRecognizer.ERROR_NETWORK, false)
        val third = p.onError(SpeechRecognizer.ERROR_NETWORK, false)
        assertEquals(SttRestartPolicy.Action.FALLBACK_VOSK, third.action)
    }

    @Test
    fun clientErrorsFallbackAfterThreshold() {
        val p = SttRestartPolicy(clientFallbackThreshold = 2)
        p.onError(SpeechRecognizer.ERROR_CLIENT, false)
        val second = p.onError(SpeechRecognizer.ERROR_CLIENT, false)
        assertEquals(SttRestartPolicy.Action.FALLBACK_VOSK, second.action)
    }

    @Test
    fun successResetsCounters() {
        val p = SttRestartPolicy(networkFallbackThreshold = 2)
        p.onError(SpeechRecognizer.ERROR_NETWORK, false)
        p.onSuccess()
        val after = p.onError(SpeechRecognizer.ERROR_NETWORK, false)
        assertTrue(after.action != SttRestartPolicy.Action.FALLBACK_VOSK)
    }

    @Test
    fun noFallbackWhenVoskAlreadyActive() {
        val p = SttRestartPolicy(networkFallbackThreshold = 1)
        val d = p.onError(SpeechRecognizer.ERROR_NETWORK, voskAlreadyActive = true)
        assertEquals(SttRestartPolicy.Action.NONE, d.action)
    }
}
