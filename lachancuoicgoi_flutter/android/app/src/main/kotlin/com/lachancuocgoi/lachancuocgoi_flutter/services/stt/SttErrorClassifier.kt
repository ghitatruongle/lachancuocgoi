package com.lachancuocgoi.lachancuocgoi_flutter.services.stt

import android.speech.SpeechRecognizer

object SttErrorClassifier {

    const val ERROR_LANGUAGE_UNAVAILABLE_COMPAT = 12

    fun isRetryable(errorCode: Int): Boolean {
        if (errorCode == ERROR_LANGUAGE_UNAVAILABLE_COMPAT) return true
        return when (errorCode) {
            SpeechRecognizer.ERROR_NETWORK,
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
            SpeechRecognizer.ERROR_AUDIO,
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
            SpeechRecognizer.ERROR_NO_MATCH,
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
            -> true
            else -> false
        }
    }

    fun isNetworkError(errorCode: Int): Boolean =
        errorCode == SpeechRecognizer.ERROR_NETWORK ||
            errorCode == SpeechRecognizer.ERROR_NETWORK_TIMEOUT

    fun isClientError(errorCode: Int): Boolean =
        errorCode == SpeechRecognizer.ERROR_CLIENT

    fun isAudioError(errorCode: Int): Boolean =
        errorCode == SpeechRecognizer.ERROR_AUDIO

    fun isBusyError(errorCode: Int): Boolean =
        errorCode == SpeechRecognizer.ERROR_RECOGNIZER_BUSY

    fun isError12(errorCode: Int): Boolean =
        errorCode == ERROR_LANGUAGE_UNAVAILABLE_COMPAT || errorCode == 12

    fun isFatalPermission(errorCode: Int): Boolean =
        errorCode == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS

    fun describe(errorCode: Int): String =
        when (errorCode) {
            SpeechRecognizer.ERROR_AUDIO ->
                "Audio recording error - may conflict with phone call audio"
            SpeechRecognizer.ERROR_CLIENT -> "Client side error"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
            SpeechRecognizer.ERROR_NETWORK -> "Network error"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "No speech match"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy"
            SpeechRecognizer.ERROR_SERVER -> "Server error"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
            else -> "Unknown error ($errorCode)"
        }
}

class SttRestartPolicy(
    private val networkFallbackThreshold: Int = 3,
    private val clientFallbackThreshold: Int = 3,
    private val audioFallbackThreshold: Int = 3,
    private val busyFallbackThreshold: Int = 2,
) {
    var consecutiveNetworkErrors: Int = 0
        private set
    var consecutiveClientErrors: Int = 0
        private set
    var consecutiveAudioErrors: Int = 0
        private set
    var consecutiveBusyErrors: Int = 0
        private set

    enum class Action {
        NONE,
        RETRY_DELAYED,
        FALLBACK_VOSK,
    }

    data class Decision(
        val action: Action,
        val retryDelayMs: Long = 0L,
        val reason: String = "",
    )

    fun onSuccess() {
        consecutiveNetworkErrors = 0
        consecutiveClientErrors = 0
        consecutiveAudioErrors = 0
        consecutiveBusyErrors = 0
    }

    fun onError(
        errorCode: Int,
        voskAlreadyActive: Boolean,
    ): Decision {
        if (!SttErrorClassifier.isBusyError(errorCode)) {
            consecutiveBusyErrors = 0
        }

        if (voskAlreadyActive) {
            if (SttErrorClassifier.isNetworkError(errorCode)) {
                consecutiveNetworkErrors++
            } else {
                consecutiveNetworkErrors = 0
            }
            return Decision(Action.NONE, reason = "vosk_active")
        }

        if (SttErrorClassifier.isClientError(errorCode)) {
            consecutiveClientErrors++
            if (consecutiveClientErrors >= clientFallbackThreshold) {
                return Decision(Action.FALLBACK_VOSK, reason = "google_client_error")
            }
            return Decision(Action.RETRY_DELAYED, retryDelayMs = 2000L, reason = "client_retry")
        }

        if (SttErrorClassifier.isNetworkError(errorCode)) {
            consecutiveNetworkErrors++
            if (consecutiveNetworkErrors >= networkFallbackThreshold) {
                return Decision(
                    Action.FALLBACK_VOSK,
                    reason = "network_errors_$consecutiveNetworkErrors",
                )
            }
            return Decision(Action.RETRY_DELAYED, retryDelayMs = 1000L, reason = "network_retry")
        } else {
            consecutiveNetworkErrors = 0
        }

        if (SttErrorClassifier.isError12(errorCode)) {
            return Decision(Action.NONE, reason = "error12_handled_elsewhere")
        }

        if (SttErrorClassifier.isAudioError(errorCode)) {
            consecutiveAudioErrors++
            if (consecutiveAudioErrors >= audioFallbackThreshold) {
                return Decision(
                    Action.FALLBACK_VOSK,
                    reason = "audio_error_$consecutiveAudioErrors",
                )
            }
            return Decision(Action.RETRY_DELAYED, retryDelayMs = 2000L, reason = "audio_retry")
        }

        if (SttErrorClassifier.isBusyError(errorCode)) {
            consecutiveBusyErrors++
            if (consecutiveBusyErrors >= busyFallbackThreshold) {
                return Decision(
                    Action.FALLBACK_VOSK,
                    reason = "recognizer_busy_$consecutiveBusyErrors",
                )
            }
            return Decision(Action.RETRY_DELAYED, retryDelayMs = 2000L, reason = "busy_retry")
        }

        if (SttErrorClassifier.isRetryable(errorCode) &&
            !SttErrorClassifier.isFatalPermission(errorCode)
        ) {
            consecutiveAudioErrors = 0
            consecutiveBusyErrors = 0
            return Decision(Action.RETRY_DELAYED, retryDelayMs = 1000L, reason = "recoverable")
        }

        return Decision(Action.NONE)
    }

    fun reset() = onSuccess()
}

