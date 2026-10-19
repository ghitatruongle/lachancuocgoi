# Architecture — Lá Chắn Cuộc Gọi (v1.6.5)

One-page map for the **client-only** production path.

## Runtime data flow

```text
Phone call audio
    → Android FGS + STT (Vosk / Google fallback)
    → Transcript stream (MethodChannel)
    → AnalysisCoordinator
         ├─ L1 keywords (<1ms)
         ├─ L2 on-device (TFLite + GDetection + WFSA)
         └─ L3 Gemini (optional, consent + PII strip)
              keys: env.json in APK  →  Google Gemini (no app server)
    → Risk fusion → overlay / history (SQLite)
```

## Layers

| Path | Role |
|------|------|
| `lib/ui/` | Pages, Riverpod controllers |
| `lib/app/` | Router, settings, composition root |
| `lib/services/` | Native bridge + simulator |
| `lib/analysis/` | Pure Dart pipeline L1/L2/L3 (**no** `package:flutter` imports) |
| `lib/data/` | SQLite history, consent, session recovery |
| `android/.../services/` | FGS, STT, CallScreening, Accessibility |

## Operating constraints (v1.6.5)

- **API keys stay in APK** (`env.json`); no runtime backend proxy.
- Future proxy: dormant docs only — `docs/adr/009-l3-backend-proxy-FUTURE.md`.
- Accessibility **call control** default **off**.
- Threat model: `docs/THREAT_MODEL.md`.

## ADRs

- 001 Riverpod state
- 002 Three-tier pipeline
- 003 Android native integration
- 004 API key obfuscation tradeoff
- 005 Adaptive timeout
- 006 Type-safe native bridge
- 009 L3 proxy **FUTURE / unused**
