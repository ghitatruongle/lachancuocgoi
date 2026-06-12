package com.example.lachancuocgoi.data

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object TranscriptSaver {

    private const val TRANSCRIPT_DIRECTORY = "transcripts"

    /**
     * Local history phải giữ nguyên văn để người dùng xem lại đầy đủ.
     * Redaction chỉ áp dụng ở outbound Cloud AI, không áp dụng ở lưu cục bộ.
     */
    fun prepareTranscriptForLocalStorage(transcript: String): String {
        return transcript.trim()
    }

    fun saveTranscript(context: Context, transcript: String): String? {
        return try {
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val fileName = "transcript_$timestamp.txt"

            val directory = File(context.filesDir, TRANSCRIPT_DIRECTORY)
            if (!directory.exists()) {
                directory.mkdirs()
            }

            val file = File(directory, fileName)
            FileOutputStream(file).use {
                it.write(transcript.toByteArray())
            }

            file.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}
