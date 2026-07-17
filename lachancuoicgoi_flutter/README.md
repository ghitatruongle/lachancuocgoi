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
- **Version**: 1.6.0+12
- **Platform chính**: Android (nhờ native overlay + Vosk STT)
- **Platform phụ trợ**: iOS/Web/Desktop (qua simulator bridge với multi-scenario catalog + creator mode)

## Tính năng theo nền tảng (Platform Honesty)

| Nền tảng | STT (Vosk) | Overlay cảnh báo | Call Screening | Phiên đầy đủ |
|----------|:----------:|:----------------:|:--------------:|:------------:|
| **Android** | ✅ Thật | ✅ Thật | ✅ Thật | ✅ |
| **iOS** | ❌ Mô phỏng | ❌ Mô phỏng | ❌ Không | ❌ |
| **Web/Desktop** | ❌ Mô phỏng | ❌ Mô phỏng | ❌ Không | ❌ |

> **⚠️ Quan trọng (iOS):** iOS là **bản xem trước AI** (AI preview). Bản đầy đủ
> (STT thực, overlay cảnh báo, call screening) chỉ có trên **Android**. Trên iOS,
> app chạy kịch bản giả lập để thử nghiệm AI. Không sử dụng app iOS để bảo vệ
> cuộc gọi thật. Apple không cho phép ứng dụng bên thứ ba nghe nội dung cuộc
> gọi hoặc chặn số như Android CallScreeningService.

> **App Store / Google Play:** mô tả cửa hàng phải nêu rõ giới hạn iOS. Không
> claim "chặn cuộc gọi lừa đảo" trên metadata iOS. Xem `fastlane/metadata/` cho
> listing template.

## Phase 2 — Hoàn thành

| Mục | Trạng thái | Mô tả |
|-----|-----------|-------|
| **P2-1** Eval harness | ✅ | Corpus JSONL + precision/recall/F1 regression gate (`flutter test --tags eval`) |
| **P2-2** L2 early-exit | ✅ | Incremental cache cho green results — bỏ re-run GDetection khi delta không chứa risk token |
| **P2-3** OTA vocab/scenario | ✅ | `RemoteConfigStore` + `DiskAssetLoader` + `CompositeAssetLoader` (disk-first) + Settings UI |
| **P2-4** Call screening opt-in | ✅ | Block/reject known scam numbers — default OFF, consent UI bắt buộc |
| **P2-5** model-vn-small | ✅ (infra) | Pubspec entry + `useSmallSttModel` setting toggle + docs (cần file model thật) |
| **P2-6** i18n / gen-l10n | ✅ | `app_vi.arb` + `AppLocalizations` + Home/Monitoring migrated |
| **P2-7** Haptics/motion | ✅ | Yellow=light, orange=medium, red=heavy + `MediaQuery.disableAnimations` respect |
| **P2-8** Simulator bridge | ✅ | Factory `NativeBridgeInterface.create()` — single `SimulatorCallShieldBridge` cho non-Android |
| **P2-9** iOS honesty | ✅ (Branch A) | README + store listing metadata (`fastlane/metadata/`) |
| **P2-SEC** API key proxy | ✅ | `ProxyL3Client` abstraction + `docs/API_KEY_SECURITY.md` |

Chi tiết eval: `docs/eval_corpus_readme.md`
Chi tiết security: `docs/API_KEY_SECURITY.md`
Chi tiết model: `docs/MODEL_VN_SMALL.md`
