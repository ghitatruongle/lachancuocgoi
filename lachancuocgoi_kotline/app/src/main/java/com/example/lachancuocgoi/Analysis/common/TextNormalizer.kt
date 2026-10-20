package com.example.lachancuocgoi.Analysis.common

import java.text.Normalizer
import java.util.regex.Pattern

object TextNormalizer {

    private val diacritics = Pattern.compile("\\p{InCombiningDiacriticalMarks}+")
    private val noiseChars = Pattern.compile("[^\\p{L}\\p{N}\\s]")

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

    private var slangEntries = listOf<Pair<String, String>>()

    fun loadSlangConfig(config: Map<String, String>) {
        slangEntries = config.map { (key, value) ->
            normalize(key, applySlang = false) to normalize(value, applySlang = false)
        }.sortedByDescending { it.first.length }
    }

    fun normalize(
        text: String,
        applySlang: Boolean = true,
        noiseMode: NoiseMode = NoiseMode.REMOVE
    ): String {

        var result = text.lowercase()

        val sb = StringBuilder()
        for (char in result) {
            sb.append(phoneticMap[char] ?: char)
        }
        result = sb.toString()

        val decomposed = Normalizer.normalize(result, Normalizer.Form.NFD)
        result = diacritics.matcher(decomposed).replaceAll("")

        result = when (noiseMode) {
            NoiseMode.REMOVE -> noiseChars.matcher(result).replaceAll("")
            NoiseMode.SPACE -> noiseChars.matcher(result).replaceAll(" ")
        }

        result = result.trim().replace("\\s+".toRegex(), " ")

        if (applySlang && slangEntries.isNotEmpty()) {
            slangEntries.forEach { (slang, replacement) ->
                if (result.contains(slang)) {
                    result = " $result ".replace(" $slang ", " $replacement ").trim()
                }
            }
        }

        return result
    }

    fun tokenize(
        text: String,
        applySlang: Boolean = true,
        noiseMode: NoiseMode = NoiseMode.REMOVE
    ): List<String> {
        return normalize(text, applySlang, noiseMode)
            .split("\\s+".toRegex())
            .filter { it.isNotBlank() }
    }

    enum class NoiseMode {
        REMOVE,
        SPACE
    }
}
