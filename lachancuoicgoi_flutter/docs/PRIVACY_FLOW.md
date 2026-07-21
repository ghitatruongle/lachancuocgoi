# Privacy Flow — La Chan Cuoc Goi

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      USER PHONE CALL                           │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Android Audio Capture (RECORD_AUDIO)               │
│         BackgroundMonitoringService + Foreground Service        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Vosk STT Engine (LOCAL)                       │
│          Speech-to-Text: Audio → Transcript (Vietnamese)        │
│         Runs on-device, no network required                     │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Transcript Processing Pipeline                     │
│                                                                   │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐                     │
│  │   L1    │    │   L2    │    │   L3    │                     │
│  │ Keyword │ +  │ On-Device│ +  │  Cloud  │                    │
│  │ Matching│    │   AI    │    │ Gemini  │                     │
│  │ <1ms    │    │ 50-200ms│    │ 1-5s    │                     │
│  └─────────┘    └─────────┘    └─────────┘                     │
│       │              │              │                            │
│       └──────────────┴──────────────┘                            │
│                          │                                      │
│                          ▼                                      │
│              ┌─────────────────────┐                            │
│              │   RESULT + ALERT    │                            │
│              │   RED / ORANGE /   │                             │
│              │   GREEN            │                              │
│              └─────────────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LOCAL STORAGE                                │
│  SQLite Database (call_history)                                 │
│  - Transcript, summary, riskLevel, duration, analysisResult     │
│  - Retention: 30 days default (configurable)                    │
│  - NO cloud backup                                              │
└─────────────────────────────────────────────────────────────────┘
```

## Cloud Analysis Path (Optional, Requires Consent)

```
Transcript (full)
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│                   PII STRIPPING                                 │
│  Removes 11+ types of personally identifiable information:      │
│  - Phone numbers, OTP codes, bank account numbers               │
│  - National ID (CCCD/CMND), credit card numbers                 │
│  - Email, social media handles, URLs                            │
│  - Dates of birth, addresses, person names                      │
│                                                                 │
│  Replaces with tokens: [SO_DIEN_THOAI_1], [MA_OTP_1], etc.      │
│  Maintains token map for restoration after analysis.             │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│              GEMINI API (Google Cloud)                          │
│  - Only sends PII-stripped transcript                          │
│  - No phone numbers, names, or identifying info                │
│  - Circuit breaker prevents runaway calls                      │
│  - Rate limiting: minimum 1s between requests                  │
│  - Multi-key rotation for availability                         │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│              ANALYSIS RESULT + SUMMARY                          │
│  Restores PII tokens back to original values for display        │
│  User sees full context but Gemini never received PII           │
└─────────────────────────────────────────────────────────────────┘
```

## Consent Flow

1. **First time cloud analysis requested:**
   - App shows consent dialog explaining what data will be sent
   - User must explicitly opt-in
   - Consent stored in SharedPreferences (`CLOUD_ANALYSIS_CONSENT_V1`)

2. **If user denies or revokes consent:**
   - App falls back to L1 + L2 only (offline)
   - Cloud analysis is NEVER attempted
   - User can change setting anytime in Settings → Privacy

3. **If network unavailable:**
   - L3 fails gracefully
   - App continues with L1 + L2 results
   - No crash, no data loss

## Data Retention

| Data Type | Storage | Retention | Deletion |
|-----------|---------|-----------|----------|
| Transcript | SQLite | 30 days (default) | Auto-delete or manual |
| Analysis result | SQLite | Same as transcript | Same |
| Session snapshot | SharedPreferences | 30 minutes | Auto-expire |
| System logs | Internal storage | 500 entries max | Manual clear |
| Cloud API prompts | NOT stored | N/A | Never persisted |
| Gemini responses | NOT stored | N/A | Never persisted |

## Sensitive Data Reset

User can trigger complete data wipe via:
- Settings → Privacy → Reset sensitive data
- Clears: call history, transcripts, session snapshots, system logs, blocked numbers
- Preserves: theme preference, accessibility permission state

## Third-Party Services

| Service | Used For | Data Shared | Consent Required |
|---------|----------|-------------|------------------|
| **Vosk** | Offline speech-to-text | None (runs locally) | No |
| **Google Gemini** | Cloud AI analysis (optional) | PII-stripped transcript | Yes |
| **Firebase Crashlytics** | Error reporting (Android only) | Stack traces, custom keys | No (opt-out in settings) |
| **Android System** | Call screening, overlays | Permission-granted data | Yes (system permissions) |

## Accessibility Service Disclosure

The Accessibility service is required for the consented OTT-call workflow and
is used only for supported call surfaces (system dialer, Zalo, Messenger,
WhatsApp, Telegram, Viber, LINE, Signal, Skype, and visible live-caption
surfaces):

- detect an incoming or ongoing call;
- read captions that are visibly rendered during that call;
- activate Answer or End only after the user explicitly chooses the matching
  action in the notification or monitoring overlay.

The service does not process chats, contacts, passwords, payment screens, or
unrelated app content. Accessibility-derived transcript text follows the same
local retention and optional, PII-stripped Gemini consent flow described above.

## What We DO NOT Collect

- ❌ Contact list / address book
- ❌ Location / GPS data
- ❌ Device identifiers (IMEI, Android ID)
- ❌ Usage analytics (except optional Firebase crash reports)
- ❌ Messages (SMS, WhatsApp, etc.)
- ❌ Other app data
- ❌ Biometric data

## User Rights

1. **Right to know:** View exactly what data is stored (Settings → About)
2. **Right to access:** Export scrubbed system logs (max 500 entries)
3. **Right to deletion:** Delete all data via Sensitive Data Reset
4. **Right to consent withdrawal:** Turn off cloud analysis anytime
5. **Right to portability:** Export call history (future feature)

## Security Measures

- **Encryption at rest:** Android Keystore for sensitive SharedPreferences when available
- **Log scrubbing:** All logs pass through `SystemLogger.scrubForLogging()` before persistence
- **API key obfuscation:** XOR encoding (not encryption — see ADR-004)
- **PII stripping:** Before any cloud transmission
- **Backup disabled:** `android:allowBackup="false"` prevents data extraction via Android backup
- **No telemetry:** No usage tracking SDKs installed

## Children's Privacy

This app is not intended for children under 13 years of age. We do not knowingly collect personal information from children.

## Policy Updates

This privacy flow document is maintained alongside `PRIVACY_POLICY.md`. Any changes will be reflected in both files and documented in `CHANGELOG.md`.

---

**Last updated:** 18/07/2026  
**Version:** 1.6.1
