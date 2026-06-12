package com.example.lachancuocgoi.Analysis.L3.core

import android.util.Base64

/**
 * Tiện ích đơn giản để làm xáo trộn (obfuscate) API keys, 
 * giúp tránh việc bị quét chuỗi thô (static analysis) một cách dễ dàng.
 * 
 * Lưu ý: Đây không phải là mã hóa (encryption) thực sự, nhưng tốt hơn là để text thô.
 */
object ApiKeyObfuscator {
    
    // Một XOR key đơn giản để tăng độ khó
    private const val SALT = 0x42
    
    /**
     * Giải mã một chuỗi đã được obfuscate.
     */
    fun decode(obfuscated: String): String {
        return try {
            val decodedBytes = Base64.decode(obfuscated, Base64.DEFAULT)
            val result = ByteArray(decodedBytes.size)
            for (i in decodedBytes.indices) {
                result[i] = (decodedBytes[i].toInt() xor SALT).toByte()
            }
            String(result)
        } catch (e: Exception) {
            // Fallback: Nếu không phải base64 hoặc lỗi, trả về chuỗi gốc (để tương thích ngược)
            obfuscated
        }
    }
    
    /**
     * Có ích cho developer để tạo ra chuỗi đã xáo trộn.
     */
    fun encode(raw: String): String {
        val rawBytes = raw.toByteArray()
        val result = ByteArray(rawBytes.size)
        for (i in rawBytes.indices) {
            result[i] = (rawBytes[i].toInt() xor SALT).toByte()
        }
        return Base64.encodeToString(result, Base64.NO_WRAP)
    }
}
