# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure with 3-tier scam detection pipeline
- Android native integration (foreground service, CallScreeningService, AccessibilityService)
- PII stripping before cloud analysis
- 16KB alignment verification for Android 15+ submissions
- Secret scanner and coverage regression gates in CI

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

- **v1.6.0+14** is the current production-ready version
- **v1.5.3** introduced crash hardening and performance work
- **FTS5 search** was planned in v1.5.3 but deferred to v1.6.0+; current implementation uses LIKE queries
- All releases maintain backward compatibility with Android 8.0 (API 26) minimum
