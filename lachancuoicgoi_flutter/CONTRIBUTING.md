# Contributing to La Chan Cuoc Goi

Thank you for your interest in contributing to **La Chan Cuoc Goi** — an anti-scam call shield application built with Flutter and Kotlin.

## Table of Contents

- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Running Tests](#running-tests)
- [Code Style](#code-style)
- [Pull Request Process](#pull-request-process)
- [Security Reporting](#security-reporting)
- [Documentation](#documentation)

---

## Development Setup

### Prerequisites

- **Flutter SDK:** 3.44.2 or later (Dart >=3.9.0 <4.0.0)
- **Android SDK:** API 26+ (minSdk), API 36 (targetSdk)
- **Kotlin:** 2.2.20+
- **Java:** 17 (Temurin recommended)
- **Android Studio:** For emulator and native debugging
- **Git:** With pre-commit hooks installed

### Initial Setup

```bash
# 1. Clone the monorepo
git clone https://github.com/your-org/lachancuocgoi.git
cd lachancuocgoi/lachancuoicgoi_flutter

# 2. Install dependencies
flutter pub get --enforce-lockfile

# 3. Configure API keys
cp env.example.json env.json
# Edit env.json with your Gemini API keys (start with 'AIza')
# NEVER commit env.json

# 4. Install pre-commit hooks (blocks secret commits)
./tool/install-hooks.sh
# Or on Windows:
powershell -ExecutionPolicy Bypass -File tool/install-hooks.ps1

# 5. Verify setup
flutter analyze
dart run tool/verify_release_version.dart
```

### Android Native Setup

The project includes a Kotlin native layer at `android/app/src/main/kotlin/com/lachancuocgoi/lachancuoicgoi_flutter/`:

- `BackgroundMonitoringService.kt` — Foreground service for microphone monitoring
- `UnifiedAccessibilityService.kt` — Accessibility service for auto-answer/end-call
- `CallScreeningServiceImpl.kt` — System call screening integration
- `VoskSttManager.kt` — Offline speech-to-text engine

To build native components:

```bash
cd android
./gradlew assembleDebug
```

---

## Project Structure

```
lachancuoicgoi_flutter/
├── lib/                      # Dart source code
│   ├── analysis/             # Scam detection pipeline (L1/L2/L3)
│   ├── app/                  # Composition root (router, DI, settings)
│   ├── core/                 # Domain types and utilities
│   ├── data/                 # SQLite database, DAOs, repositories
│   ├── l10n/                 # Generated Vietnamese localizations
│   ├── services/             # Native bridges, permissions, STT
│   └── ui/                   # Pages and widgets
├── test/                     # Unit and widget tests (~1,600 tests)
├── integration_test/         # End-to-end flow tests
├── android/                  # Native Android (Kotlin)
├── assets/                   # Models (TFLite, Vosk), configs
├── tool/                     # Build and CI scripts
└── docs/                     # Architecture docs, ADRs, security guides
```

### Key Directories

- **`lib/analysis/`** — Core scam detection engine (pure Dart, no Flutter dependencies)
- **`lib/services/`** — Platform abstraction layer (Android bridge vs simulator)
- **`lib/data/`** — SQLite persistence with DAO and repository patterns
- **`test/`** — Organized by domain: `analysis/`, `services/`, `UI/`, `Perf/`

---

## Running Tests

### Fast Suite (Recommended for PRs)

Runs ~1,600 unit/widget tests excluding performance benchmarks.

```bash
# Using script (cross-platform):
./tool/run_tests.sh                    # macOS/Linux
powershell -ExecutionPolicy Bypass -File tool/run_tests.ps1  # Windows

# Or directly:
flutter test --exclude-tags perf
```

### Performance Suite

Slow benchmarks tagged with `perf`. Run selectively.

```bash
RUN_PERF=1 ./tool/run_tests.sh
# Or:
flutter test --tags perf
```

### Integration Tests

End-to-end tests requiring Android emulator.

```bash
# macOS/Linux:
./tool/run_integration_tests.sh

# Windows:
powershell -ExecutionPolicy Bypass -File tool/run_integration_tests.ps1
```

### Eval Corpus Regression

Tests against 300-case scam detection corpus (precision/recall gates).

```bash
flutter test test/analysis/eval/corpus_regression_test.dart
```

### Coverage

```bash
flutter test --coverage --exclude-tags perf
dart run tool/check_coverage.dart
```

Coverage baseline: **76.62%** (minimum acceptable: 75.62%)

---

## Code Style

### Linting Rules

This project uses strict linting via `analysis_options.yaml`:

- `strict-casts: true` — Prevents unsafe type casts
- `strict-inference: true` — Requires explicit types where needed
- `prefer_single_quotes: true` — Consistent string quoting
- `require_trailing_commas: true` — Multi-line structures use trailing commas
- `cancel_subscriptions: true` — Prevents memory leaks
- `close_sinks: true` — Ensures streams/controllers are disposed
- `avoid_catches_without_on_clauses` — Typed exception handling required

### Formatting

```bash
# Check formatting
dart format --output=none --set-exit-if-changed lib test integration_test tool

# Auto-format
dart format lib test integration_test tool
```

### Naming Conventions

- **Classes/Enums:** PascalCase (`AnalysisCoordinator`, `RiskLevel`)
- **Variables/Methods:** camelCase (`processedTextLength`, `scheduleRealTimeAnalysis()`)
- **Private members:** Underscore prefix (`_defaultTimeout`)
- **Constants:** `const` or UPPER_SNAKE_CASE (`_allowedTables`)
- **Files:** snake_case (`api_key_obfuscator.dart`)
- **Providers:** `<name>Provider` (`settingsControllerProvider`)

### Comment Guidelines

- Use `///` for public API documentation
- Use `//` for inline explanations of **why**, not **what**
- Avoid phase/bug references in production code (use CHANGELOG or ADRs instead)
- Aim for 5-10% comment density in complex files
- Explain security rationale and performance tradeoffs

Example:

```dart
// GOOD: Explains why
// Bug #22 fix: timeout wrapper prevents UI freeze when platform thread is blocked
final Duration _defaultTimeout = const Duration(seconds: 5);

// BAD: States what is obvious
// Set default timeout to 5 seconds
final Duration _defaultTimeout = const Duration(seconds: 5);
```

### Error Handling

- Use typed catches (`on PlatformException`, `on TimeoutException`)
- Log errors via `SystemLogger` with appropriate category and level
- Return safe defaults rather than crashing
- No broad `catch (e)` without `on` clause

---

## Pull Request Process

### Before Submitting

1. **Create a feature branch** from `main`:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feat/your-feature-name
   ```

2. **Run full test suite**:
   ```bash
   ./tool/run_tests.sh
   ```

3. **Update documentation** if user-facing:
   - Update `CHANGELOG.md` under `[Unreleased]`
   - Update README if architecture changed
   - Add ADR if making significant design decision

4. **Verify formatting and analysis**:
   ```bash
   dart format --output=none --set-exit-if-changed lib test integration_test tool
   flutter analyze
   ```

5. **Check for secrets**:
   ```bash
   dart run tool/check_no_secrets.dart
   ```

### PR Checklist

- [ ] Tests pass locally (`flutter test --exclude-tags perf`)
- [ ] Code follows style guidelines
- [ ] CHANGELOG.md updated (if applicable)
- [ ] Documentation updated (if applicable)
- [ ] No secrets or API keys committed
- [ ] CI pipeline passes
- [ ] Requested review from at least one maintainer

### PR Title Format

Use conventional commits:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `refactor:` Code change without functionality
- `test:` Adding or updating tests
- `chore:` Build/CI/tooling changes

Example: `feat: add PII stripping for bank account numbers`

### Review Process

1. Automated checks run on PR (CI/CD)
2. At least one maintainer reviews
3. Address feedback and push updates
4. Squash merge to `main` after approval

---

## Security Reporting

If you discover a security vulnerability:

1. **DO NOT** create a public GitHub issue
2. Email security@lachancuocgoi.com (or maintainers)
3. Include:
   - Description of vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (optional)

We follow responsible disclosure practices. See `docs/API_KEY_SECURITY.md` for key management policies.

### Sensitive Data Guidelines

- Never commit `env.json` or real API keys
- Never log transcripts, prompts, or PII
- Use `SystemLogger.scrubForLogging()` for all debug output
- PII stripping must happen before any cloud API call
- SharedPreferences should not store sensitive data in plaintext

---

## Documentation

### Architecture Decision Records (ADRs)

Significant technical decisions are documented in `docs/adr/`:

- `001-riverpod-state-management.md` — Why Riverpod for state management
- `002-three-tier-analysis-pipeline.md` — L1/L2/L3 architecture
- `003-android-native-integration.md` — Native service design
- `004-api-key-obfuscation-tradeoff.md` — API key storage strategy

When making a new architectural decision, create an ADR following the template in `docs/adr/TEMPLATE.md`.

### Privacy Documentation

- `PRIVACY_POLICY.md` — User-facing privacy policy
- `docs/API_KEY_SECURITY.md` — API key handling and rotation
- `docs/PRIVACY_FLOW.md` — Data flow diagram and processing explanation

---

## Getting Help

- **Questions?** Open a GitHub Discussion
- **Bugs?** Create an issue with reproduction steps
- **Features?** Propose in issues or discussions first
- **Urgent?** Contact maintainers directly

---

## Recognition

Contributors are recognized in:

- `CHANGELOG.md` under each release
- GitHub repository contributors page
- In-app "About" section (optional)

Thank you for helping make phone calls safer! 🛡️
