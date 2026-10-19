# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.6.5] - 2026-07-23

### Added
- Threat model and architecture one-pager for client-only L3 (key-in-APK).
- `L3CredentialProvider` abstraction with env production path; backend stub **unused**.
- Adaptive timeout calculator wired into analysis coordinator.
- Type-safe native bridge method constants.
- Detection metrics schema (local only).
- English `app_en.arb` skeleton.
- Fusion matrix and circuit-breaker unit tests.
- Dormant L3 proxy OpenAPI + ADR-009 (not wired).

### Changed
- Analysis layer no longer imports `package:flutter`.
- Accessibility call-control defaults **off** (opt-in).
- Version `1.6.1+15` → `1.6.5+16`.
- Operating model docs lock: no server runtime for L3.

### Security
- Documented accepted risk of bundled Gemini keys for v1.6.5.
- Crashlytics custom keys limited to version/platform (no transcript fields).

## [1.6.1] - 2026-07-21

### Fixed
- Overlay monitoring now requests visibility above the keyguard on supported Android devices.
- FlutterEngine is warmed while the incoming-call consent notification is displayed.
- Repeated Google SpeechRecognizer busy errors now fall back to Vosk instead of repeatedly rebuilding the recognizer on the main thread.
- Added physical-device performance instrumentation and cold/warm startup regression tests.

## [1.6.0] - 2026-07-18

### Added
- **Three-tier analysis pipeline:**
  - L1: Aho-Corasick keyword matching with bigram corrections
  - L2: On-device AI (TFLite BERT intent classifier + GDetection)
  - L3: Cloud AI (Gemini API with PII stripping, circuit breaker, multi-key rotation)
- **Real-time call monitoring** via foreground microphone service
- **Scam alert system** with red/orange overlays and haptic feedback
- **Offline speech-to-text** using Vosk engine with Google STT fallback
- **Call screening** integration for blocking known scam numbers
- **Developer mode** with secret tap-to-activate (10 taps) and SHA-256 password hash
- **Cross-platform simulator** for iOS/Web/Desktop demo without real call interception
- **Privacy-first design:** PII stripping (11+ types), consent gate for cloud analysis, sensitive data reset service
- **Comprehensive test suite:** ~1,600 unit/widget tests, 5 integration tests, 300-case eval corpus
- **CI/CD pipeline:** GitHub Actions with quality gates, coverage tracking, secret scanning
- **Release automation:** PowerShell scripts for AAB/APK build, signing, zipalign verification

### Fixed
- Bug #22: MethodChannel timeout handling to prevent UI freezing
- Schema v6 migration for `recordingError` column idempotency
- Android 15+ 16KB ELF alignment for native libraries
- SQL injection prevention in database migrations via whitelist validation

### Security
- API key obfuscation with XOR encoding (16-byte key + legacy single-byte fallback)
- Circuit breaker for L3 cloud calls during failures
- Log scrubbing for sensitive data (API keys, phone numbers, emails, transcripts)
- Backup disabled (`android:allowBackup="false"`) with custom data extraction rules
- Pre-commit hook blocks staging of `env.json` and real Gemini API keys

### Changed
- Database schema version bumped to 6
- README documentation updated with platform honesty matrix
- Analysis engine separated into pure Dart (no Flutter dependencies) for testability

## [1.5.3] - 2026-07-16

### Added
- Crash hardening improvements
- Performance optimizations for analysis pipeline
- FTS5 search implementation (planned, not yet implemented in v1.6.0)

### Fixed
- Various bug fixes from Sprint 4.4

## [1.5.0] - Earlier Release

### Added
- Initial project setup
- Basic call monitoring framework
- First iteration of scam detection logic

---

## Version History Notes

- **v1.6.5+16** is the current engineering target (client-only L3)
- **v1.5.3** introduced crash hardening and performance work
- **FTS5 search** was planned in v1.5.3 but deferred to v1.6.0+; current implementation uses LIKE queries
- All releases maintain backward compatibility with Android 8.0 (API 26) minimum
