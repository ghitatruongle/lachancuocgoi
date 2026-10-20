package com.example.lachancuocgoi.Analysis.L3.core

import com.example.lachancuocgoi.BuildConfig

interface ApiKeyProvider {

    fun getApiKeys(): List<String>

    fun getKeyCount(): Int
}

class BuildConfigApiKeyProvider : ApiKeyProvider {

    private val keys: List<String> by lazy {
        BuildConfig.GEMINI_API_KEYS
            .split(",")
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .map { key ->
                if (key.startsWith("AIza")) key
                else ApiKeyObfuscator.decode(key)
            }
    }

    override fun getApiKeys(): List<String> = keys

    override fun getKeyCount(): Int = keys.size
}
