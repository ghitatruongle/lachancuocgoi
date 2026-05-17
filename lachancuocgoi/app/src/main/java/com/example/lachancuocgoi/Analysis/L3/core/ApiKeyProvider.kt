package com.example.lachancuocgoi.Analysis.L3.core

import com.example.lachancuocgoi.BuildConfig

/**
 * Interface để quản lý Gemini API keys.
 * Cho phép dễ dàng chuyển đổi giữa BuildConfig, encrypted storage, hoặc backend proxy.
 */
interface ApiKeyProvider {
    /**
     * Lấy danh sách API keys có sẵn.
     * @return List of API keys (non-empty)
     */
    fun getApiKeys(): List<String>
    
    /**
     * Số lượng API keys.
     * @return Number of available keys
     */
    fun getKeyCount(): Int
}

/**
 * Implementation mặc định: Đọc keys từ BuildConfig.
 * 
 * TODO Phase 2: Migrate sang secure storage hoặc backend proxy để bảo vệ API keys.
 */
class BuildConfigApiKeyProvider : ApiKeyProvider {
    
    // Đổi tên từ apiKeys thành keys để tránh xung đột với getter của interface
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
