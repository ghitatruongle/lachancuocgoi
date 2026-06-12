package com.example.lachancuocgoi.Analysis.common

import java.text.Normalizer
import java.util.regex.Pattern

/**
 * Bộ chuẩn hóa văn bản thống nhất — dùng chung cho L1, L2, L3.
 *
 * Pipeline: lowercase → phonetic mapping → bỏ dấu NFD → bỏ noise chars → (tùy chọn) slang replacement
 */
object TextNormalizer {

    private val diacritics = Pattern.compile("\\p{InCombiningDiacriticalMarks}+")
    private val noiseChars = Pattern.compile("[^\\p{L}\\p{N}\\s]")

    // Bảng ánh xạ ký tự tương đồng (chống t1ền, c0ng an, l0 đề...)
    private val phoneticMap = mapOf<Char, Char>(
        '0' to 'o', '1' to 'i', '3' to 'e', '4' to 'a', '5' to 's', '7' to 't', '8' to 'b',
        'ô' to 'o', 'ơ' to 'o', 'ó' to 'o', 'ò' to 'o', 'ỏ' to 'o', 'õ' to 'o', 'ọ' to 'o',
        'â' to 'a', 'ă' to 'a', 'á' to 'a', 'à' to 'a', 'ả' to 'a', 'ã' to 'a', 'ạ' to 'a',
        'ê' to 'e', 'ế' to 'e', 'ề' to 'e', 'ể' to 'e', 'ễ' to 'e', 'ệ' to 'e',
        'í' to 'i', 'ì' to 'i', 'ỉ' to 'i', 'ĩ' to 'i', 'ị' to 'i',
        'ú' to 'u', 'ù' to 'u', 'ủ' to 'u', 'ũ' to 'u', 'ụ' to 'u', 'ư' to 'u',
        'ý' to 'y', 'ỳ' to 'y', 'ỷ' to 'y', 'ỹ' to 'y', 'ỵ' to 'y',
        'đ' to 'd'
    )

    // Slang entries: Key = từ gốc đã normalize, Value = từ đích đã normalize
    private var slangEntries = listOf<Pair<String, String>>()

    /**
     * Nạp bản đồ từ lóng. Sắp xếp theo độ dài giảm dần để ưu tiên cụm từ dài.
     */
    fun loadSlangConfig(config: Map<String, String>) {
        slangEntries = config.map { (key, value) ->
            normalize(key, applySlang = false) to normalize(value, applySlang = false)
        }.sortedByDescending { it.first.length }
    }

    /**
     * Chuẩn hóa văn bản đầy đủ.
     *
     * @param text Văn bản gốc
     * @param applySlang Có áp dụng thay thế từ lóng không (mặc định true)
     * @param noiseMode Cách xử lý noise chars: REMOVE (xóa, nối liền) hoặc SPACE (thay bằng khoảng trắng)
     * @return Văn bản đã chuẩn hóa
     */
    fun normalize(
        text: String,
        applySlang: Boolean = true,
        noiseMode: NoiseMode = NoiseMode.REMOVE
    ): String {
        // 1. Lowercase
        var result = text.lowercase()

        // 2. Phonetic mapping (0→o, 1→i, đ→d...)
        val sb = StringBuilder()
        for (char in result) {
            sb.append(phoneticMap[char] ?: char)
        }
        result = sb.toString()

        // 3. Bỏ dấu Tiếng Việt (NFD decomposition)
        val decomposed = Normalizer.normalize(result, Normalizer.Form.NFD)
        result = diacritics.matcher(decomposed).replaceAll("")

        // 4. Xử lý noise chars
        result = when (noiseMode) {
            NoiseMode.REMOVE -> noiseChars.matcher(result).replaceAll("")  // L1: nối liền (c.ông → cong)
            NoiseMode.SPACE -> noiseChars.matcher(result).replaceAll(" ")  // L2: giữ khoảng trắng
        }

        result = result.trim().replace("\\s+".toRegex(), " ")

        // 5. Slang replacement (tùy chọn)
        if (applySlang && slangEntries.isNotEmpty()) {
            slangEntries.forEach { (slang, replacement) ->
                if (result.contains(slang)) {
                    result = " $result ".replace(" $slang ", " $replacement ").trim()
                }
            }
        }

        return result
    }

    /**
     * Tokenize: chuẩn hóa rồi split theo khoảng trắng.
     */
    fun tokenize(
        text: String,
        applySlang: Boolean = true,
        noiseMode: NoiseMode = NoiseMode.REMOVE
    ): List<String> {
        return normalize(text, applySlang, noiseMode)
            .split("\\s+".toRegex())
            .filter { it.isNotBlank() }
    }

    /**
     * Chế độ xử lý noise chars.
     */
    enum class NoiseMode {
        REMOVE,  // Xóa hoàn toàn (L1: c.ông → cong)
        SPACE    // Thay bằng khoảng trắng (L2: c.ông → c ong)
    }
}
