# Threat Model — Lá Chắn Cuộc Gọi (v1.6.5)

**Status:** Accepted for **v1.6.5** (client-only / key-in-APK operating model)  
**Related:** `docs/API_KEY_SECURITY.md`, plan `docs/superpowers/plans/2026-07-22-score-improvement-no-server.md`

## Scope

In-scope for this model:

- Android production path: mic → on-device STT → L1/L2 → optional L3 (Gemini from device)
- Local SQLite history, overlays, call screening, optional accessibility call control
- Bundled Gemini API keys in `env.json` asset

Out of scope (deferred):

- Server-side API key custody / L3 reverse proxy (**not used in v1.6.5**)
- Formal third-party pen-test report

## Assets

| Asset | Sensitivity | Location |
|-------|-------------|----------|
| Call audio / mic stream | Critical | Device memory / STT engines |
| Transcript text | Critical | Memory, SQLite, optional L3 payload (after PII strip) |
| Gemini API keys | High | `env.json` inside APK/AAB |
| Call log / phone numbers | High | OS permissions + app DB |
| Accessibility click capability | High | `UnifiedAccessibilityService` (user-gated) |
| Analysis results / risk level | Medium | Local DB, UI |

## Actors

- Curious reverse engineer of APK
- Quota thief (extract key, burn Gemini quota)
- Network observer on L3 HTTPS (metadata; TLS to Google)
- Malicious overlay / accessibility abuse (if user grants a11y)
- Benign user on untrusted network

## Trust boundaries

```text
[User + Android OS]
        |
        v
[Flutter UI + Analysis L1/L2]  -- local only --
        |
        | (consent + PII strip)
        v
[L3 Gemini client] ---- HTTPS ----> [Google Gemini]
        ^
        |
 [env.json keys in APK]   ← accepted risk for v1.6.5
```

No app-operated backend sits between device and Gemini in v1.6.5.

## STRIDE summary

| Category | Example | Mitigation (v1.6.5) | Residual risk |
|----------|---------|---------------------|---------------|
| **S**poofing | Fake Gemini endpoint | Official SDK + HTTPS to Google | Low |
| **T**ampering | Modified APK injects logic | Play integrity not required; user trust | Medium |
| **R**epudiation | Disputed cloud analysis | Local history + consent flag | Medium |
| **I**nfo disclosure | Key extract from APK | XOR obfuscation (delay only), secret scan, gitignore, log scrub | **High — accepted** |
| **I**nfo disclosure | Transcript to cloud | Consent gate, PII strip 11+ types, offline L1+L2 default | Medium (regex PII imperfect) |
| **D**oS | Stolen key burns quota | Multi-key rotation, low quota ops, circuit breaker | Medium |
| **E**levation | A11y auto-click | Feature default **off**; user opt-in | Medium if enabled |

## Accepted risk: bundled Gemini keys

**Decision for v1.6.5:** API keys remain loadable from bundled `env.json` and ship inside the APK/AAB.

Reasons:

- No production server dependency
- Offline-first L1/L2 still works without any cloud credential path complexity
- Matches product constraint: *build APK with keys, do not use a server*

Operational mitigations (mandatory):

1. Never commit `env.json` with real keys
2. Prefer XOR-obfuscated values in release `env.json`
3. Cap Gemini quota / API restrictions in Google Cloud
4. Rotate keys on suspected leak
5. Run `dart run tool/validate_release_env.dart env.json` before release build
6. Never log raw keys, prompts, or full transcripts (`SystemLogger.scrubForLogging`)

## Non-goals for v1.6.5

- Requiring `L3_BACKEND_URL` at release
- Removing client keys from the release path
- Awarding “key leaves the device” security posture in scorecards

Future proxy design may exist as **dormant** docs/stubs only (`docs/adr/009-l3-backend-proxy-FUTURE.md`).

## Accessibility

Call-control actions (answer/end via accessibility) must be **opt-in**. Monitoring core loop (mic + STT + overlay + L1/L2) must work without accessibility enabled.

## Review cadence

Revisit this model when:

- Shipping any HTTP path to a first-party backend for L3
- Expanding accessibility automation
- Changing PII stripper coverage or consent UX
