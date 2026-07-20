package com.lachancuocgoi.lachancuocgoi_flutter.audio

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow

object CreatorAudioCaptureManager {
    private const val TAG = "CreatorAudioCapture"

    const val SAMPLE_RATE = 16000
    const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
    const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

    val BUFFER_SIZE: Int =
        AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            .coerceAtLeast(SAMPLE_RATE * 2 * 320 / 1000)

    private val _state = MutableStateFlow(CaptureState.IDLE)
    val state = _state.asStateFlow()

    private val _amplitudeFlow = MutableSharedFlow<Float>(extraBufferCapacity = 100)
    val amplitudeFlow = _amplitudeFlow.asSharedFlow()

    private val _creatorTranscriptFlow = MutableStateFlow("")
    val creatorTranscriptFlow = _creatorTranscriptFlow.asStateFlow()

    @Volatile
    private var audioRecord: AudioRecord? = null

    fun emitAmplitude(amp: Float) {
        _amplitudeFlow.tryEmit(amp)
    }

    fun updateTranscript(text: String) {
        _creatorTranscriptFlow.value = text
    }

    fun startCapture(context: Context, projection: MediaProjection): AudioRecord? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            Log.w(TAG, "AudioPlaybackCapture requires Android 10+")
            _state.value = CaptureState.ERROR
            return null
        }

        if (_state.value == CaptureState.CAPTURING) {
            return audioRecord
        }
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "RECORD_AUDIO permission is required for playback capture")
            _state.value = CaptureState.ERROR
            return null
        }

        return try {
            startCaptureInternal(projection)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start capture", e)
            _state.value = CaptureState.ERROR
            null
        }
    }

    fun stopCapture() {
        try {
            audioRecord?.let { record ->
                if (record.state == AudioRecord.STATE_INITIALIZED) {
                    record.stop()
                }
                record.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping AudioRecord", e)
        } finally {
            audioRecord = null
            _state.value = CaptureState.IDLE
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    @SuppressLint("MissingPermission") // Checked by startCapture before entering this method.
    private fun startCaptureInternal(projection: MediaProjection): AudioRecord? {
        val captureConfig = try {
            val builder = AudioPlaybackCaptureConfiguration.Builder(projection)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            try {
                builder.addMatchingUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
            } catch (_: Exception) {
                // Android can reject VOICE_COMMUNICATION on some devices; other usages still work.
            }
            builder.build()
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException when creating capture config", e)
            _state.value = CaptureState.ERROR
            return null
        }

        val record = AudioRecord.Builder()
            .setAudioPlaybackCaptureConfig(captureConfig)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AUDIO_FORMAT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(CHANNEL_CONFIG)
                    .build()
            )
            .setBufferSizeInBytes(BUFFER_SIZE)
            .build()

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            Log.e(TAG, "AudioRecord failed to initialize. state=${record.state}")
            record.release()
            _state.value = CaptureState.ERROR
            return null
        }

        record.startRecording()
        audioRecord = record
        _state.value = CaptureState.CAPTURING
        return record
    }

    enum class CaptureState {
        IDLE,
        CAPTURING,
        ERROR,
    }
}
