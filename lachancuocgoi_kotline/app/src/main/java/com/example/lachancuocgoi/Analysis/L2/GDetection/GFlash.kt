package com.example.lachancuocgoi.Analysis.L2.GDetection

import com.example.lachancuocgoi.Analysis.common.TextNormalizer

object GFlash {

    fun loadSlangConfig(config: Map<String, String>) {
        TextNormalizer.loadSlangConfig(config)
    }

    fun tokenize(text: String): List<String> {
        return TextNormalizer.tokenize(text, applySlang = true, noiseMode = TextNormalizer.NoiseMode.SPACE)
    }
}
