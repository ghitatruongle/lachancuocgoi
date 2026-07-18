package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.content.Intent

/**
 * Privacy-safe call event sent over the Flutter event channel.
 *
 * Raw phone numbers may be used transiently by native call-screening code, but
 * they must never cross this boundary. Only a masked suffix is exposed.
 */
data class NativeCallEvent(
    val type: String,
    val timestampMs: Long = System.currentTimeMillis(),
    val reason: String,
    val numberAvailable: Boolean = false,
    val maskedNumber: String? = null,
    val extras: Map<String, Any?> = emptyMap(),
) {
    fun toMap(): Map<String, Any?> =
        LinkedHashMap<String, Any?>(extras.size + 5).apply {
            putAll(extras)
            put("type", type)
            put("timestampMs", timestampMs)
            put("reason", reason)
            put("numberAvailable", numberAvailable)
            put("maskedNumber", maskedNumber)
        }

    companion object {
        private const val EXTRA_NAVIGATE_TO_MONITORING = "NAVIGATE_TO_MONITORING"
        private const val EXTRA_PHONE_NUMBER = "PHONE_NUMBER"
        private const val EXTRA_EVENT_TYPE = "CALL_EVENT_TYPE"
        private const val EXTRA_EVENT_REASON = "CALL_EVENT_REASON"
        private const val EXTRA_EVENT_TIMESTAMP_MS = "CALL_EVENT_TIMESTAMP_MS"

        /** Parse both cold-start and warm-start Activity intents identically. */
        fun fromActivityIntent(intent: Intent?): NativeCallEvent? {
            if (intent?.getBooleanExtra(EXTRA_NAVIGATE_TO_MONITORING, false) != true) {
                return null
            }

            val rawNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER)
            val timestamp = intent.getLongExtra(EXTRA_EVENT_TIMESTAMP_MS, 0L)
                .takeIf { it > 0L } ?: System.currentTimeMillis()
            return NativeCallEvent(
                type = intent.getStringExtra(EXTRA_EVENT_TYPE)
                    ?.takeIf { it.isNotBlank() }
                    ?: "NAVIGATE_TO_MONITORING",
                timestampMs = timestamp,
                reason = intent.getStringExtra(EXTRA_EVENT_REASON)
                    ?.takeIf { it.isNotBlank() }
                    ?: "notification_navigation",
                numberAvailable = !rawNumber.isNullOrBlank(),
                maskedNumber = maskPhoneNumber(rawNumber),
            )
        }

        fun create(
            type: String,
            reason: String,
            rawNumber: String? = null,
            numberAvailable: Boolean = !rawNumber.isNullOrBlank(),
            timestampMs: Long = System.currentTimeMillis(),
            extras: Map<String, Any?> = emptyMap(),
        ): NativeCallEvent = NativeCallEvent(
            type = type,
            timestampMs = timestampMs,
            reason = reason,
            numberAvailable = numberAvailable,
            maskedNumber = if (numberAvailable) maskPhoneNumber(rawNumber) else null,
            extras = extras,
        )

        /** Return only the final four digits, prefixed with a masking marker. */
        fun maskPhoneNumber(rawNumber: String?): String? {
            val digits = rawNumber.orEmpty().filter(Char::isDigit)
            if (digits.isEmpty()) return null
            return "••••${digits.takeLast(4)}"
        }
    }
}
