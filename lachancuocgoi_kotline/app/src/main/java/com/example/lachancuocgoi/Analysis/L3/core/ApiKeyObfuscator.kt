package com.example.lachancuocgoi.Analysis.L3.core

import android.util.Base64

object ApiKeyObfuscator {

    private const val SALT = 0x42

    fun decode(obfuscated: String): String {
        return try {
            val decodedBytes = Base64.decode(obfuscated, Base64.DEFAULT)
            val result = ByteArray(decodedBytes.size)
            for (i in decodedBytes.indices) {
                result[i] = (decodedBytes[i].toInt() xor SALT).toByte()
            }
            String(result)
        } catch (e: Exception) {

            obfuscated
        }
    }

    fun encode(raw: String): String {
        val rawBytes = raw.toByteArray()
        val result = ByteArray(rawBytes.size)
        for (i in rawBytes.indices) {
            result[i] = (rawBytes[i].toInt() xor SALT).toByte()
        }
        return Base64.encodeToString(result, Base64.NO_WRAP)
    }
}
