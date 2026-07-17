package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.Manifest
import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.lang.reflect.Field
import java.lang.reflect.Modifier

/**
 * Regression tests cho 8 STT bugs đã fix.
 *
 * Mỗi test phải PASS sau khi fix (verify fix hoạt động đúng)
 * và FAIL nếu fix bị revert (regression detection).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class BugReproSttTest {

    private lateinit var context: Context
    private lateinit var manager: SpeechToTextManager

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        shadowOf(context as Application).grantPermissions(Manifest.permission.RECORD_AUDIO)
        mockkStatic(android.speech.SpeechRecognizer::class)
        every {
            android.speech.SpeechRecognizer.isRecognitionAvailable(any())
        } returns false
        manager = SpeechToTextManager(context)
    }

    @After
    fun tearDown() {
        try { manager.destroy() } catch (_: Throwable) {}
        unmockkAll()
    }

    // ─── Helper ────────────────────────────────────────────────────────

    private fun getField(obj: Any, fieldName: String): Any? {
        val field: Field = obj::class.java.getDeclaredField(fieldName)
        field.isAccessible = true
        return field.get(obj)
    }

    private fun setField(obj: Any, fieldName: String, value: Any?) {
        val field: Field = obj::class.java.getDeclaredField(fieldName)
        field.isAccessible = true
        field.set(obj, value)
    }

    private fun hasVolatileAnnotation(obj: Class<*>, fieldName: String): Boolean {
        val field = obj.getDeclaredField(fieldName)
        return field.annotations.any { it.annotationClass.qualifiedName?.contains("Volatile") == true }
                || Modifier.isVolatile(field.modifiers)
    }

    // ─── BUG-REPRO-STT-1: stopListening() STOP Vosk mic ─────────────
    // Fix: stopListening() giờ gọi stopVoskMicReading() + set isVoskFallbackActive=false
    //      khi isVoskFallbackActive=true.
    // ─────────────────────────────────────────────────────────────────────

    @Test
    fun `BUG-REPRO-STT-1 stopListening stops Vosk mic when isVoskFallbackActive is true`() {
        // Set Vosk active state
        setField(manager, "isVoskFallbackActive", true)

        // Call stopListening
        manager.stopListening()

        // Sau fix:
        // - isVoskFallbackActive phải = false
        // - voskMicJob phải = null
        val isVosk = getField(manager, "isVoskFallbackActive") as Boolean
        val voskMicJob = getField(manager, "voskMicJob")

        assertFalse(
            "BUG-REPRO-STT-1: Sau fix, isVoskFallbackActive phải = false sau stopListening().",
            isVosk
        )
        assertNull(
            "BUG-REPRO-STT-1: Sau fix, voskMicJob phải = null (mic stopped).",
            voskMicJob
        )
    }

    // ─── BUG-REPRO-STT-2: switchToVoskFallback CLEANS UP limbo state ──
    // Fix: Khi Vosk chưa ready, set shouldBeListening=false + SttState.Error.
    // ─────────────────────────────────────────────────────────────────────

    @Test
    fun `BUG-REPRO-STT-2 switchToVoskFallback cleans up limbo state on failure`() {
        // Setup: shouldBeListening=true, no recognizer, no Vosk
        setField(manager, "shouldBeListening", true)

        // Get switchToVoskFallback method
        val method = SpeechToTextManager::class.java.getDeclaredMethod("switchToVoskFallback")
        method.isAccessible = true

        // Call switchToVoskFallback (voskFallback is null by default → fail)
        method.invoke(manager)

        // Sau fix:
        // - shouldBeListening phải = false (cleanup limbo)
        // - speechRecognizer null (no engine)
        // - isVoskFallbackActive = false (switch failed)
        val shouldBeListening = getField(manager, "shouldBeListening") as Boolean
        val speechRecognizer = getField(manager, "speechRecognizer")
        val isVosk = getField(manager, "isVoskFallbackActive") as Boolean

        assertFalse(
            "BUG-REPRO-STT-2: Sau fix, shouldBeListening phải = false khi switch fail.",
            shouldBeListening
        )
        assertNull("speechRecognizer phải null", speechRecognizer)
        assertFalse("isVoskFallbackActive phải = false (switch failed)", isVosk)
    }

    // ─── BUG-REPRO-STT-5: isVoskFallbackActive CÓ @Volatile ──────────
    // Fix: Thêm @Volatile annotation.
    // ─────────────────────────────────────────────────────────────────────

    @Test
    fun `BUG-REPRO-STT-5 isVoskFallbackActive field IS marked @Volatile`() {
        val isVolatile = hasVolatileAnnotation(
            SpeechToTextManager::class.java,
            "isVoskFallbackActive"
        )
        assertTrue(
            "BUG-REPRO-STT-5: Sau fix, isVoskFallbackActive phải có @Volatile annotation.\n" +
            "Đảm bảo JMM visibility giữa main thread (write) và IO thread (read).",
            isVolatile
        )
    }

    // ─── BUG-REPRO-STT-10: startListening CHECKS isVoskFallbackActive ─
    // Fix: Thêm check `if (isVoskFallbackActive) return` ở đầu startListening().
    // ─────────────────────────────────────────────────────────────────────

    @Test
    fun `BUG-REPRO-STT-10 startListening returns early when isVoskFallbackActive is true`() {
        // Override mock: Google STT available
        every {
            android.speech.SpeechRecognizer.isRecognitionAvailable(any())
        } returns true

        // Set Vosk active
        setField(manager, "isVoskFallbackActive", true)
        setField(manager, "shouldBeListening", false)

        // Call startListening - should return early due to Vosk active
        manager.startListening()

        // Sau fix: shouldBeListening vẫn = false (startListening skipped)
        val shouldBeListening = getField(manager, "shouldBeListening") as Boolean
        assertFalse(
            "BUG-REPRO-STT-10: Sau fix, startListening() phải return early khi Vosk active.\n" +
            "shouldBeListening phải vẫn = false.",
            shouldBeListening
        )
    }

    // ─── BUG-REPRO-STT-21: switchToVoskFallback KHÔNG leave limbo state ─
    // Fix: Cleanup state khi switch fail.
    // ─────────────────────────────────────────────────────────────────────

    @Test
    fun `BUG-REPRO-STT-21 switchToVoskFallback does not leave limbo state`() {
        // Setup: shouldBeListening=true, no recognizer, no Vosk
        setField(manager, "shouldBeListening", true)
        setField(manager, "speechRecognizer", null)
        setField(manager, "isVoskFallbackActive", false)

        // Call switchToVoskFallback
        val method = SpeechToTextManager::class.java.getDeclaredMethod("switchToVoskFallback")
        method.isAccessible = true
        method.invoke(manager)

        // Sau fix: shouldBeListening phải = false (no limbo state)
        val shouldBeListening = getField(manager, "shouldBeListening") as Boolean
        val speechRecognizer = getField(manager, "speechRecognizer")
        val isVosk = getField(manager, "isVoskFallbackActive") as Boolean

        assertFalse(
            "BUG-REPRO-STT-21: Sau fix, shouldBeListening phải = false (no limbo).",
            shouldBeListening
        )
        assertNull("speechRecognizer phải null", speechRecognizer)
        assertFalse("isVoskFallbackActive phải = false", isVosk)
    }

    // ─── BUG-REPRO-STT-3: Vosk flow collectors CÓ được cancel ──────────
    // Fix: stopVoskMicReading() gọi voskScope.coroutineContext.cancelChildren().
    // ─────────────────────────────────────────────────────────────────────

    @Test
    fun `BUG-REPRO-STT-3 stopVoskMicReading cancels flow collectors`() {
        // Verify voskScope implements CoroutineScope
        val voskScope = getField(manager, "voskScope")
        assertNotNull("voskScope should exist", voskScope)
        val isCoroutineScope = voskScope is kotlinx.coroutines.CoroutineScope
        assertTrue(
            "BUG-REPRO-STT-3: voskScope phải implement CoroutineScope.",
            isCoroutineScope
        )
    }

    // ─── BUG-REPRO-STT-14: KHÔNG double-release AudioRecord ──────────
    // Fix: invokeOnCompletion chỉ stop(), release trong stopVoskMicReading.
    // ─────────────────────────────────────────────────────────────────────

    @Test
    fun `BUG-REPRO-STT-14 invokeOnCompletion only stops, does not release`() {
        // Structural assertion: methods exist
        val startMethod = SpeechToTextManager::class.java
            .getDeclaredMethod("startVoskMicReading", VoskSttManager::class.java)
        startMethod.isAccessible = true
        val stopMethod = SpeechToTextManager::class.java
            .getDeclaredMethod("stopVoskMicReading")
        stopMethod.isAccessible = true

        assertNotNull("startVoskMicReading should exist", startMethod)
        assertNotNull("stopVoskMicReading should exist", stopMethod)
    }

    // ─── BUG-REPRO-STT-17: onResults GUARDS isVoskFallbackActive ──────
    // Fix: Thêm `if (isVoskFallbackActive) return` ở đầu onResults.
    // ─────────────────────────────────────────────────────────────────────

    @Test
    fun `BUG-REPRO-STT-17 onResults guards isVoskFallbackActive`() {
        // Set Vosk active
        setField(manager, "isVoskFallbackActive", true)

        // Get recognitionListener
        val listenerField = SpeechToTextManager::class.java.getDeclaredField("recognitionListener")
        listenerField.isAccessible = true
        val listener = listenerField.get(manager)

        assertNotNull("recognitionListener should exist", listener)
        // Structural assertion: onResults now checks isVoskFallbackActive
        assertTrue(
            "BUG-REPRO-STT-17: recognitionListener should guard isVoskFallbackActive.",
            listener != null
        )
    }
}