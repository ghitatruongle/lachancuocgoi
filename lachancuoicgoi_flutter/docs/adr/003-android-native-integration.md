# ADR-003: Android Native Integration Architecture

## Status

Accepted

## Context

La Chan Cuoc Goi requires deep Android system integration to monitor phone calls in real-time. Constraints:
- **Android 8.0+ (API 26)** minimum, target API 36
- Must work without root access
- Must comply with Google Play policies for sensitive permissions
- Must handle background execution limits (Android 8.0+, 12+)
- Must support overlay windows, accessibility services, and call screening

Key challenges:
- Android restricts third-party apps from accessing call audio directly
- Background services are killed by Doze mode and app standby
- Overlay windows require `SYSTEM_ALERT_WINDOW` permission
- AccessibilityService can read subtitles but has security implications
- CallScreeningService requires user to set as default phone app

## Decision

Implement a **multi-component native architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    MainActivity.kt                          │
│              (Entry point, permission requests)              │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐   ┌────────────────┐   ┌──────────────────┐
│Background     │   │Unified         │   │CallScreening     │
│Monitoring     │   │Accessibility   │   │ServiceImpl       │
│Service        │   │Service         │   │                  │
│(Foreground    │   │(Auto-answer,  │   │(Block known      │
│ microphone    │   │ end-call,     │   │ scam numbers)     │
│ STT)          │   │ subtitle read)│   │                  │
└───────┬───────┘   └───────┬────────┘   └────────┬─────────┘
        │                   │                     │
        ▼                   ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│              MethodChannel + EventChannel                   │
│              (Flutter ↔ Kotlin communication)               │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

**BackgroundMonitoringService**
- Foreground service with microphone permission
- Runs Vosk STT engine for offline speech-to-text
- Captures audio stream during calls
- Falls back to Google STT if Vosk unavailable
- Maintains wake lock during monitoring

**UnifiedAccessibilityService**
- Reads system subtitles (live captions) as alternative audio source
- Provides auto-answer and end-call capabilities
- Used when microphone permission denied or not available
- Requires `ACCESSIBILITY_SERVICE` permission

**CallScreeningServiceImpl**
- Implements `CallScreeningService` API
- Blocks known scam numbers before ringing
- Uses local blacklist from SharedPreferences
- Requires user to set as default phone app

**TranscriptionHub**
- Aggregates transcripts from multiple sources (Vosk, Google STT, Accessibility)
- Handles transcript overlap and deduplication
- Emits events to Flutter via EventChannel

**OverlayManager**
- Draws alert overlays (incoming call, monitoring, full-screen warning)
- Uses `TYPE_APPLICATION_OVERLAY` for non-fullscreen
- Uses `FLAG_FULLSCREEN` for red warnings
- Haptic feedback integration

### Communication Pattern

```kotlin
// Native → Flutter via EventChannel
private val eventSink = NativeBridgeEventSink()

fun sendTranscript(text: String) {
  eventSink.success(mapOf("text" to text, "timestamp" to System.currentTimeMillis()))
}

// Flutter → Native via MethodChannel
val result = methodChannel.invokeMethod("startMonitoring", args)
```

Flutter side uses `NativeBridgeInterface` abstraction:
- `AndroidCallShieldBridge` — Production Android implementation
- `SimulatorCallShieldBridge` — iOS/Desktop/Web fallback
- `NativeCallShieldBridge` — Legacy backward compatibility

## Rationale

This architecture was chosen because:
1. **Foreground service** survives background execution limits
2. **Multiple STT sources** ensure reliability (Vosk offline + Google fallback)
3. **AccessibilityService** provides alternative when microphone restricted
4. **CallScreeningService** enables pre-ringing blocking (best UX)
5. **MethodChannel abstraction** keeps Flutter code platform-agnostic

## Consequences

**Positive:**
- Works on non-rooted devices
- Graceful degradation if individual components fail
- Clear separation: STT, screening, overlay are independent
- Testable via `SimulatorCallShieldBridge` on non-Android platforms
- Foreground notification satisfies Android 8.0+ requirements

**Negative:**
- Large attack surface (many sensitive permissions)
- Complex lifecycle management (service binding, foreground notifications)
- Android 12+ requires `FOREGROUND_SERVICE_MICROPHONE` separate permission
- Android 15+ requires 16KB alignment for native libraries
- AccessibilityService can be disabled by user at any time

**Mitigations:**
- Comprehensive permission rationales in UI
- Privacy policy explains each permission
- Secret scanner prevents key leaks
- 16KB alignment verification in CI (`tool/verify_16kb_alignment.dart`)
- Circuit breaker for native bridge timeouts (5s default)

## References

- `android/app/src/main/kotlin/com/lachancuocgoi/lachancuoicgoi_flutter/services/BackgroundMonitoringService.kt`
- `android/app/src/main/kotlin/com/lachancuocgoi/lachancuoicgoi_flutter/services/UnifiedAccessibilityService.kt`
- `android/app/src/main/kotlin/com/lachancuocgoi/lachancuoicgoi_flutter/services/CallScreeningServiceImpl.kt`
- `lib/services/android_call_shield_bridge.dart`
- `lib/services/native_bridge_interface.dart`
- `android/app/src/main/AndroidManifest.xml`
