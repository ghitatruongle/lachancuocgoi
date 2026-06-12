package com.lachancuocgoi.lachancuocgoi_flutter.services

import android.Manifest
import android.app.Application
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import kotlinx.coroutines.flow.StateFlow
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Contract test: verifies that [SpeechToTextManager] correctly
 * implements the [SttEngine] interface and its lifecycle is sane.
 *
 * The test does NOT exercise the SpeechRecognizer pipeline (which
 * needs a real device / Google SpeechService). It only checks:
 *  - Interface surface
 *  - Idempotent start/stop/destroy
 *  - StateFlow types
 *  - `name` and `isReady` semantics
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SttEngineContractTest {

    private lateinit var engine: SpeechToTextManager

    @Before
    fun setUp() {
        // Grant the RECORD_AUDIO permission so startListening() doesn't
        // short-circuit on the permission check.
        val app = ApplicationProvider.getApplicationContext<Application>()
        shadowOf(app).grantPermissions(Manifest.permission.RECORD_AUDIO)

        engine = SpeechToTextManager(app)
        // Pretend Google STT is unavailable so startListening() returns
        // early without trying to use a real SpeechRecognizer. This is
        // the safer path for a contract test.
        mockkStatic(android.speech.SpeechRecognizer::class)
        every {
            android.speech.SpeechRecognizer.isRecognitionAvailable(any())
        } returns false
    }

    @After
    fun tearDown() {
        // Drain any pending handler callbacks from the engine
        shadowOf(Looper.getMainLooper()).idle()
        try {
            engine.destroy()
        } catch (_: Throwable) {
            // ignore — destroy may have already been called
        }
        unmockkAll()
    }

    private fun idle() {
        shadowOf(Looper.getMainLooper()).idle()
    }

    // ─── 1. implements SttEngine interface ──────────────────────────────

    @Test
    fun `engine is an instance of SttEngine`() {
        val asInterface: SttEngine = engine
        assertNotNull(asInterface)
    }

    // ─── 2. name == "Google" ─────────────────────────────────────────────

    @Test
    fun `engine name is Google`() {
        assertEquals("Google", engine.name)
    }

    // ─── 3. flows are StateFlows ────────────────────────────────────────

    @Test
    fun `fullTranscriptFlow is a StateFlow`() {
        assertTrue(engine.fullTranscriptFlow is StateFlow<*>)
        assertEquals("", engine.fullTranscriptFlow.value)
    }

    @Test
    fun `textResults is a StateFlow`() {
        assertTrue(engine.textResults is StateFlow<*>)
        assertEquals("", engine.textResults.value)
    }

    @Test
    fun `isListening is a StateFlow starting as false`() {
        assertTrue(engine.isListening is StateFlow<*>)
        assertEquals(false, engine.isListening.value)
    }

    @Test
    fun `rmsDbFlow is a StateFlow starting at 0`() {
        assertTrue(engine.rmsDbFlow is StateFlow<*>)
        assertEquals(0f, engine.rmsDbFlow.value)
    }

    // ─── 4. isReady reflects current engine state ──────────────────────

    @Test
    fun `isReady is true when no fallback is active`() {
        // In a freshly constructed manager with no Vosk preload,
        // isVoskFallbackActive == false → isReady == true
        assertTrue(engine.isReady)
    }

    // ─── 5. start/stop/destroy are idempotent ──────────────────────────

    @Test
    fun `start is safe to call when Google STT unavailable`() {
        // Should not throw; on a device without Google STT, start
        // returns early after setting the sttState to Error.
        engine.start()
        idle()
        // isListening should NOT be true (we never made it past the
        // availability check).
        assertEquals(false, engine.isListening.value)
    }

    @Test
    fun `stop is safe to call without a prior start`() {
        // Should not throw
        engine.stop()
        idle()
        engine.stop()
        idle()
        assertEquals(false, engine.isListening.value)
    }

    @Test
    fun `destroy is idempotent`() {
        engine.destroy()
        idle()
        // Calling again should not throw
        engine.destroy()
        idle()
    }

    @Test
    fun `clearTranscript resets flows to empty strings`() {
        // Even without an actual transcript, clearTranscript should
        // be safe and set everything to "".
        engine.clearTranscript()
        assertEquals("", engine.fullTranscriptFlow.value)
        assertEquals("", engine.textResults.value)
    }
}
