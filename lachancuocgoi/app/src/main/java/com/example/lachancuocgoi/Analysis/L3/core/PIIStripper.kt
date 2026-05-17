package com.example.lachancuocgoi.Analysis.L3.core

/**
 * PIIStripper dùng riêng cho luồng outbound lên Cloud AI.
 *
 * Mục tiêu:
 * - Chỉ thay thế đúng phần dữ liệu định danh/nhạy cảm.
 * - Giữ nguyên cấu trúc câu để AI vẫn hiểu đúng ngữ cảnh lừa đảo.
 * - Không đụng vào transcript local/history; local engines dùng text gốc.
 */
object PIIStripper {

    private enum class PiiType(val tokenPrefix: String) {
        PERSON_NAME("TEN_NGUOI"),
        PHONE_NUMBER("SO_DIEN_THOAI"),
        BANK_ACCOUNT("SO_TAI_KHOAN"),
        OTP("MA_OTP"),
        NATIONAL_ID("CCCD"),
        EMAIL("EMAIL"),
        ADDRESS("DIA_CHI"),
        CARD_NUMBER("SO_THE")
    }

    private data class Replacement(
        val start: Int,
        val end: Int,
        val token: String,
        val originalValue: String
    )

    private val counters = mutableMapOf<PiiType, Int>()
    private val roleKeywords = listOf(
        "công an",
        "cong an",
        "kiểm sát",
        "kiem sat",
        "toà án",
        "toa an",
        "ngân hàng",
        "ngan hang",
        "bưu điện",
        "buu dien",
        "nhân viên",
        "nhan vien",
        "hỗ trợ",
        "ho tro"
    )

    suspend fun redactPII(originalText: String): Pair<String, Map<String, String>> {
        if (originalText.isBlank()) {
            return originalText to emptyMap()
        }

        counters.clear()
        val replacements = mutableListOf<Replacement>()
        val tokenByValue = mutableMapOf<Pair<PiiType, String>, String>()

        collectContextualNumberReplacements(
            text = originalText,
            replacements = replacements,
            tokenByValue = tokenByValue,
            type = PiiType.OTP,
            regex = Regex("""(?i)\b(?:mã|ma)\s*(?:otp|xác minh|xac minh|bảo mật|bao mat|kích hoạt|kich hoat)\b(?:[^\d\n]{0,20})((?:\d[\s.-]?){3,7}\d)"""),
            groupIndex = 1
        )
        collectContextualNumberReplacements(
            text = originalText,
            replacements = replacements,
            tokenByValue = tokenByValue,
            type = PiiType.BANK_ACCOUNT,
            regex = Regex("""(?i)\b(?:số tài khoản|so tai khoan|số tk|so tk|stk|tài khoản|tai khoan)\b(?:[^\d\n]{0,20})((?:\d[\s.-]?){5,17}\d)"""),
            groupIndex = 1
        )
        collectContextualNumberReplacements(
            text = originalText,
            replacements = replacements,
            tokenByValue = tokenByValue,
            type = PiiType.NATIONAL_ID,
            regex = Regex("""(?i)\b(?:cccd|cmnd|căn cước|can cuoc|chứng minh nhân dân|chung minh nhan dan)\b(?:[^\d\n]{0,20})((?:\d[\s.-]?){8,11}\d)"""),
            groupIndex = 1
        )
        collectContextualNumberReplacements(
            text = originalText,
            replacements = replacements,
            tokenByValue = tokenByValue,
            type = PiiType.CARD_NUMBER,
            regex = Regex("""(?i)\b(?:số thẻ|so the|thẻ ngân hàng|the ngan hang|thẻ tín dụng|the tin dung)\b(?:[^\d\n]{0,20})((?:\d[\s-]?){12,18}\d)"""),
            groupIndex = 1
        )

        collectDirectReplacements(
            text = originalText,
            replacements = replacements,
            tokenByValue = tokenByValue,
            type = PiiType.EMAIL,
            regex = Regex("""\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b""", RegexOption.IGNORE_CASE)
        ) { true }
        collectDirectReplacements(
            text = originalText,
            replacements = replacements,
            tokenByValue = tokenByValue,
            type = PiiType.PHONE_NUMBER,
            regex = Regex("""(?<!\w)(?:\+84|84|0)(?:[\s.-]?\d){8,10}\b""")
        ) { candidate ->
            candidate.filter(Char::isDigit).length in 9..11
        }
        collectContextualTextReplacements(
            text = originalText,
            replacements = replacements,
            tokenByValue = tokenByValue,
            type = PiiType.PERSON_NAME,
            regex = Regex(
                """(?i)\b(?:tôi tên là|toi ten la|em tên là|em ten la|anh tên là|anh ten la|chị tên là|chi ten la|cháu tên là|chau ten la|tên tôi là|ten toi la|tên em là|ten em la|người nhận là|nguoi nhan la|tôi là|toi la|em là|em la|anh là|anh la|chị là|chi la|cháu là|chau la)\s+([a-zà-ỹ]{2,}(?:\s+[a-zà-ỹ]{2,}){0,4})"""
            )
        ) { candidate ->
            val normalized = candidate.normalizedVietnamese()
            normalized.length >= 5 &&
                normalized.split(' ').size in 2..5 &&
                roleKeywords.none { normalized.contains(it) }
        }
        collectContextualTextReplacements(
            text = originalText,
            replacements = replacements,
            tokenByValue = tokenByValue,
            type = PiiType.ADDRESS,
            regex = Regex(
                """(?i)\b(?:địa chỉ|dia chi|nhà ở|nha o|gửi về|gui ve|giao tới|giao toi)\b(?:\s*(?:là|la|:))?\s+([^,.!?;\n]{6,80})"""
            )
        ) { candidate ->
            candidate.length >= 6
        }

        if (replacements.isEmpty()) {
            return originalText to emptyMap()
        }

        val redacted = StringBuilder(originalText)
        val tokensMap = linkedMapOf<String, String>()
        replacements.sortedByDescending { it.start }.forEach { replacement ->
            redacted.replace(replacement.start, replacement.end, replacement.token)
            tokensMap.putIfAbsent(replacement.token, replacement.originalValue)
        }
        return redacted.toString() to tokensMap
    }

    fun restorePII(redactedText: String, tokensMap: Map<String, String>): String {
        var restoredText = redactedText
        tokensMap.entries
            .sortedByDescending { it.key.length }
            .forEach { (token, originalValue) ->
                restoredText = restoredText.replace(token, originalValue)
            }
        return restoredText
    }

    private fun collectContextualNumberReplacements(
        text: String,
        replacements: MutableList<Replacement>,
        tokenByValue: MutableMap<Pair<PiiType, String>, String>,
        type: PiiType,
        regex: Regex,
        groupIndex: Int
    ) {
        regex.findAll(text).forEach { match ->
            val group = match.groups[groupIndex] ?: return@forEach
            addReplacementIfValid(
                text = text,
                replacements = replacements,
                tokenByValue = tokenByValue,
                type = type,
                start = group.range.first,
                end = group.range.last + 1
            ) { candidate ->
                candidate.filter(Char::isDigit).isNotEmpty()
            }
        }
    }

    private fun collectContextualTextReplacements(
        text: String,
        replacements: MutableList<Replacement>,
        tokenByValue: MutableMap<Pair<PiiType, String>, String>,
        type: PiiType,
        regex: Regex,
        validator: (String) -> Boolean
    ) {
        regex.findAll(text).forEach { match ->
            val group = match.groups[1] ?: return@forEach
            addReplacementIfValid(
                text = text,
                replacements = replacements,
                tokenByValue = tokenByValue,
                type = type,
                start = group.range.first,
                end = group.range.last + 1,
                validator = validator
            )
        }
    }

    private fun collectDirectReplacements(
        text: String,
        replacements: MutableList<Replacement>,
        tokenByValue: MutableMap<Pair<PiiType, String>, String>,
        type: PiiType,
        regex: Regex,
        validator: (String) -> Boolean
    ) {
        regex.findAll(text).forEach { match ->
            addReplacementIfValid(
                text = text,
                replacements = replacements,
                tokenByValue = tokenByValue,
                type = type,
                start = match.range.first,
                end = match.range.last + 1,
                validator = validator
            )
        }
    }

    private fun addReplacementIfValid(
        text: String,
        replacements: MutableList<Replacement>,
        tokenByValue: MutableMap<Pair<PiiType, String>, String>,
        type: PiiType,
        start: Int,
        end: Int,
        validator: (String) -> Boolean
    ) {
        if (start < 0 || end > text.length || start >= end || replacements.hasOverlap(start, end)) {
            return
        }

        val originalValue = text.substring(start, end).trim()
        if (!validator(originalValue)) {
            return
        }

        val tokenKey = type to originalValue.normalizedVietnamese()
        val token = tokenByValue.getOrPut(tokenKey) {
            val nextIndex = (counters[type] ?: 0) + 1
            counters[type] = nextIndex
            "[${type.tokenPrefix}_$nextIndex]"
        }

        replacements += Replacement(
            start = start,
            end = end,
            token = token,
            originalValue = originalValue
        )
    }

    private fun MutableList<Replacement>.hasOverlap(start: Int, end: Int): Boolean {
        return any { start < it.end && end > it.start }
    }

    private fun String.normalizedVietnamese(): String {
        return trim().lowercase().replace(Regex("""\s+"""), " ")
    }
}
