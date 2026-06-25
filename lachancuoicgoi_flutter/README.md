# Lá Chắn Cuộc Gọi — Flutter

Ứng dụng chống lừa đảo qua cuộc gọi (anti-scam call shield) cho Android, sử dụng
pipeline phân tích 3 tầng: từ khóa → AI on-device (TFLite BERT) → AI đám mây (Gemini).

## Kiến trúc tổng quan

```
lib/
├── analysis/          # Pipeline phân tích đa tầng
│   ├── l1/            # L1: Keyword matching (Aho-Corasick, bigram correction, risk density)
│   ├── l2/            # L2: AI on-device
│   │   ├── g_detection/  # GDetection (trie + scenario + sentence + WFSA state machine)
│   │   ├── intent/         # BERT intent classifier (TFLite, chạy trong Isolate)
│   │   ├── safety/         # Safety filter (negation, context)
│   │   └── wfsa/           # Weighted Finite-State Automaton
│   ├── l3/            # L3: Gemini AI analysis (PII stripping, circuit breaker, multi-key rotation)
│   └── common/        # Fuzzy matcher, text normalizer (slang/ASR correction)
├── app/                # Composition root (router, theme, DI providers, settings)
├── core/               # Domain types (RiskLevel enum)
├── data/               # SQLite DB (v7, FTS5 full-text search), DAO, session recovery
├── services/           # Native bridge (Android overlay/STT), permission controller, simulator
└── ui/                 # Pages (home, monitoring, history, simulation, result, onboarding, tips)
```

### Pipeline phân tích

| Tầng | Kỹ thuật | Mục đích | Latency |
|------|-----------|----------|---------|
| **L1** | Aho-Corasick (flat-array trie), bigram correction, 6-rule negative-lookahead, risk density | Phát hiện từ khóa lừa đảo tức thì | <1ms |
| **L2** | TFLite BERT intent classifier (Isolate) + GDetection (scenario/sentence/WFSA) + SafetyFilter | Phân loại intent + kịch bản lừa đảo | 50-200ms |
| **L3** | Gemini AI + PII stripping (11 loại) + circuit breaker + multi-key rotation | Phân tích ngữ cảnh sâu, tóm tắt | 1-5s |

- **Parallel mode**: L1+L2 song song, L3 có timeout 800ms. Fast-track khi L1/L2 đạt orange+.
- **Graceful degradation**: Mỗi tầng có fallback — L1 fallback trie, L2 intent-disabled mode, L3 circuit breaker.
- **Cascading**: L3→L2→default khi tầng trên chưa ready hoặc lỗi.

## Cấu hình API key (bắt buộc trước khi build)

File `env.json` chứa Gemini API keys và **không được commit** vào repo (đã bị `.gitignore` loại bỏ).
Vì `pubspec.yaml` khai báo `env.json` là asset, bạn **phải tự tạo file này** trước khi chạy
`flutter run` / `flutter build`, nếu không build sẽ báo lỗi thiếu asset.

Các bước:

1. Copy file mẫu thành `env.json`:
   - macOS/Linux: `cp env.example.json env.json`
   - Windows: `copy env.example.json env.json`
2. Mở `env.json` và thay các giá trị placeholder bằng Gemini API key thật của bạn
   (key hợp lệ bắt đầu bằng `AIza...`). Lấy key tại [Google AI Studio](https://aistudio.google.com/apikey).
3. Chạy `flutter pub get` rồi build/run như bình thường.

> ⚠️ **Bảo mật**: không commit `env.json` lên git. Lưu ý rằng key trong `env.json` sẽ bị bundle
> vào APK — xem `SECURITY.md` để biết khuyến nghị rotate key và phương án an toàn hơn.

## Chạy test

```bash
# Fast suite (PR check — ~1.600 test case, loại trừ perf benchmarks)
flutter test --exclude-tags perf

# Hoặc dùng script sẵn có (khuyên dùng):
# macOS/Linux:
./tool/run_tests.sh
# Windows:
powershell -ExecutionPolicy Bypass -File tool/run_tests.ps1

# Perf suite (chậm, cần tag):
flutter test --tags perf
# hoặc:
RUN_PERF=1 ./tool/run_tests.sh

# Static analysis:
dart analyze lib/ test/
```

## Cấu trúc thư mục

Đây là Flutter project trong monorepo `lachancuocgoi` (cùng thư mục với Kotlin project,
model files, v.v.). Repo root là `lachancuocgoi/`, workspace Flutter nằm ở `lachancuocgoi_flutter/`.

```
lachancuocgoi/                    # Repo root (monorepo)
├── .github/
│   ├── workflows/ci.yml          # CI: analyze + test trên push/PR
│   └── dependabot.yml            # Auto dependency updates
├── lachancuocgoi_flutter/         # ← Workspace Flutter chính
│   ├── lib/                      # Dart source code
│   ├── test/                     # Unit + widget tests (~1.600 test cases)
│   ├── integration_test/          # End-to-end flow tests
│   ├── assets/                   # Models (TFLite, Vosk, JSON configs)
│   ├── tool/                     # Test runner scripts
│   └── android/                  # Native Android (overlay, STT, Vosk)
├── lachancuocgoi_kotline/        # Kotlin companion project
└── SECURITY.md                   # API key security guide
```

## Phiên bản

- **SDK**: Dart `>=3.9.0 <4.0.0` (Flutter stable)
- **Version**: 1.4.0+9
- **Platform chính**: Android (nhờ native overlay + Vosk STT)
- **Platform phụ trợ**: iOS/Web/Desktop (qua simulator bridge với multi-scenario catalog + creator mode)
