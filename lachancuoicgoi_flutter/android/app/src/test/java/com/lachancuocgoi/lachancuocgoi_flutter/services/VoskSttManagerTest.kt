package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.content.Context
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import io.mockk.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.StorageService
import java.io.IOException

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VoskSttManagerTest {

    private lateinit var context: Context
    private val mockModel = mockk<Model>(relaxed = true)
    private val mockRecognizer = mockk<Recognizer>(relaxed = true)

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        mockkStatic(StorageService::class)
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    private fun waitForModelReady(manager: VoskSttManager, timeoutMs: Long = 2000) {
        val start = System.currentTimeMillis()
        while (System.currentTimeMillis() - start < timeoutMs) {
            shadowOf(Looper.getMainLooper()).idle()
            if (manager.isModelReady) return
            Thread.sleep(10)
        }
        fail("Model did not become ready within ${timeoutMs}ms")
    }

    private fun waitForModelFailed(
        manager: VoskSttManager,
        timeoutMs: Long = 2000
    ): ModelLoadState.Failed {
        val start = System.currentTimeMillis()
        while (System.currentTimeMillis() - start < timeoutMs) {
            shadowOf(Looper.getMainLooper()).idle()
            val state = manager.modelLoadState.value
            if (state is ModelLoadState.Failed) return state
            Thread.sleep(10)
        }
        fail("Model did not fail within ${timeoutMs}ms")
        throw AssertionError("unreachable")
    }

    @Test
    fun `initialization success transitions state to Ready`() {
        val successSlot = slot<StorageService.Callback<Model>>()
        every {
            StorageService.unpack(
                any<Context>(),
                any<String>(),
                any<String>(),
                capture(successSlot),
                any<StorageService.Callback<IOException>>()
            )
        } answers {
            successSlot.captured.onComplete(mockModel)
        }

        val manager = VoskSttManager(context, { _, _ -> mockRecognizer })
        waitForModelReady(manager)

        assertTrue(manager.isModelReady)
        assertTrue(manager.modelLoadState.value is ModelLoadState.Ready)
        manager.destroy()
    }

    @Test
    fun `initialization failure transitions state to Failed and retries`() {
        val failureSlot = slot<StorageService.Callback<IOException>>()
        every {
            StorageService.unpack(
                any<Context>(),
                any<String>(),
                any<String>(),
                any<StorageService.Callback<Model>>(),
                capture(failureSlot)
            )
        } answers {
            failureSlot.captured.onComplete(IOException("Failed to unpack"))
        }

        val manager = VoskSttManager(context, { _, _ -> mockRecognizer })

        val state = waitForModelFailed(manager)

        assertFalse(manager.isModelReady)
        assertEquals("Failed to unpack", state.error)
        manager.destroy()
    }

    @Test
    fun `processAudioBuffer with final result updates full transcript`() {
        val successSlot = slot<StorageService.Callback<Model>>()
        every {
            StorageService.unpack(
                any<Context>(),
                any<String>(),
                any<String>(),
                capture(successSlot),
                any<StorageService.Callback<IOException>>()
            )
        } answers {
            successSlot.captured.onComplete(mockModel)
        }

        every { mockRecognizer.acceptWaveForm(any<ByteArray>(), any<Int>()) } returns true
        every { mockRecognizer.result } returns """{"text": "xin chào"}"""

        val manager = VoskSttManager(context, { _, _ -> mockRecognizer })
        waitForModelReady(manager)

        val buffer = ByteArray(1024)
        manager.processAudioBuffer(buffer, 1024)

        assertEquals("xin chào", manager.voskFullTranscript.value)
        assertEquals("", manager.voskTextResults.value)
        manager.destroy()
    }

    @Test
    fun `processAudioBuffer with partial result updates text results`() {
        val successSlot = slot<StorageService.Callback<Model>>()
        every {
            StorageService.unpack(
                any<Context>(),
                any<String>(),
                any<String>(),
                capture(successSlot),
                any<StorageService.Callback<IOException>>()
            )
        } answers {
            successSlot.captured.onComplete(mockModel)
        }

        every { mockRecognizer.acceptWaveForm(any<ByteArray>(), any<Int>()) } returns false
        every { mockRecognizer.partialResult } returns """{"partial": "xin"}"""

        val manager = VoskSttManager(context, { _, _ -> mockRecognizer })
        waitForModelReady(manager)

        val buffer = ByteArray(1024)
        manager.processAudioBuffer(buffer, 1024)

        assertEquals("", manager.voskFullTranscript.value)
        assertEquals("xin", manager.voskTextResults.value)
        manager.destroy()
    }

    @Test
    fun `resetTranscript clears all flows`() {
        val successSlot = slot<StorageService.Callback<Model>>()
        every {
            StorageService.unpack(
                any<Context>(),
                any<String>(),
                any<String>(),
                capture(successSlot),
                any<StorageService.Callback<IOException>>()
            )
        } answers {
            successSlot.captured.onComplete(mockModel)
        }

        every { mockRecognizer.acceptWaveForm(any<ByteArray>(), any<Int>()) } returns true
        every { mockRecognizer.result } returns """{"text": "xin chào"}"""

        val manager = VoskSttManager(context, { _, _ -> mockRecognizer })
        waitForModelReady(manager)

        manager.processAudioBuffer(ByteArray(1024), 1024)
        
        manager.resetTranscript()
        assertEquals("", manager.voskFullTranscript.value)
        assertEquals("", manager.voskTextResults.value)
        assertEquals("", manager.creatorTranscriptFlow.value)
        manager.destroy()
    }
}
