# 📋 KẾ HOẠCH DỰ ÁN — Lạch Chắn Cuộc Gọi

> **Ứng dụng Flutter phát hiện lừa đảo qua cuộc gọi điện thoại**
> Phân tích giọng nói realtime bằng 3 lớp (L1 → L2 → L3), cảnh báo người dùng.
> Ban đầu xây trên Android/Kotlin, sau đó migrate sang Flutter.

---

## 🏗 Kiến trúc tổng thể

```
lib/
├── main.dart                          # Entry point
├── app/                               # App shell (router, settings, theme)
├── analysis/                          # Core analysis engine
│   ├── l1/                            # L1 — Phát hiện từ khóa cơ bản
│   ├── l2/                            # L2 — G-Phát hiện (Trie + Scoring + Topic)
│   │   ├── g_detection/               # G-Detection engine + refactored modules
│   │   ├── intent/                    # Phân loại ý định (TF-Lite / BERT)
│   │   ├── safety/                    # Bộ lọc an toàn
│   │   └── wfsa/                      # Weighted Finite State Automaton
│   └── l3/                            # L3 — Gemini AI phân tích sâu
│       ├── core/                       # Gemini client, API key, cache, PII...
│       └── prompt_builder.dart
├── core/                              # Shared models (risk_level)
├── data/                              # Database, DAO, repositories
├── services/                          # Native bridge, permissions, simulator
└── ui/                                # UI pages & components
    ├── home_page/
    ├── monitoring_page/
    ├── simulation_page/
    ├── history_page/
    ├── result_page/
    ├── onboarding/
    ├── tips_lesson_page/
    └── theme/
```

---

## 📜 Lịch sử Sprint / Milestone

### Phase 1 — Khởi tạo dự án Android/Kotlin
| Ngày       | Commit          | Mô tả |
|------------|-----------------|-------|
| 06/05/2026 | `c344256c`      | Initial commit |
| 06/05/2026 | `56660986`      | Thêm model files qua Git LFS |
| 06/05/2026 | `30cefe80`      | Track model ZIP qua Git LFS |

> 📌 Dự án bắt đầu dưới dạng **Android/Kotlin app**. Tải models Vosk STT, thiết lập cấu trúc cơ bản.

---

### Phase 2 — Flutter Migration (Migrate từ Android sang Flutter)
| Ngày       | Commit          | Mô tả |
|------------|-----------------|-------|
| 09/05/2026 | `e4ea5c25`      | Chuẩn bị migration |
| 09/05/2026 | `8c706a89`      | ✅ Phase 4+5: Implement L1/L2 modules |
| 13/05/2026 | `5205aa6b`      | ✅ Phase 7: L3 Gemini + fix analysis issues |
| 13/05/2026 | `27d0bddd`      | ✅ Phase 8: Port native Android services & bridge logic |

> 📌 **Migrate toàn bộ** từ Android/Kotlin sang Flutter. Giữ lại Kotlin native services (Vosk STT, Overlay) dùng MethodChannel.

---

### Phase 3 — Hoàn thiện features Flutter ban đầu
| Ngày       | Commit          | Mô tả |
|------------|-----------------|-------|
| 13/05/2026 | `4c01ee9d`      | Permission management + onboarding flow |
| 13/05/2026 | PR #1           | Merge kế hoạch dự án |
| 13/05/2026 | `e54dd1d5`      | PR #3: Fix bugs dự án Flutter |
| 13/05/2026 | `b54aebfe`      | Enhanced Audio Streaming + Transcription + Memory Management |
| 13/05/2026 | `4e1f821d`      | Update KEHOACH.md + onboarding |
| 14/05/2026 | `2288001c`      | ✅ Flutter migration hoàn tất |

> 📌 Hoàn thành chuyển đổi. App chạy trên Flutter với native bridge.

---

### Phase 4 — Stabilize & Cải thiện
| Ngày       | Commit          | Mô tả |
|------------|-----------------|-------|
| 17/05/2026 | `b83eb51c`      | Update |
| 17/05/2026 | `dbf0b04c`      | Update |
| 17/05/2026 | `3330fbb4`      | Update |
| 17/05/2026 | `36a978b1`      | ✅ Stabilize call shield services, tổ chức test suite, secure API keys |

> 📌 Ổn định services, bảo mật API keys, chuẩn hóa test suite.

---

### Phase 5 — Tính năng nâng cao (May → June 2026)
| Ngày       | Commit          | Mô tả |
|------------|-----------------|-------|
| 12/06/2026 | `10a48724`      | Cập nhật analysis coordinator + native bridge (L2/L3) |
| 12/06/2026 | `95beab59`      | Cập nhật |
| 13/06/2026 | `9aae46c4`      | Cập nhật |
| 14/06/2026 | `6220f671`      | Cập nhật |
| 16/06/2026 | `014c5083`      | Cập nhật mới nhất |

> 📌 Giai đoạn phát triển features nâng cao: WFSA engine, BERT intent tokenizer, PII stripper, response cache, Gemini metrics, scenario matcher...

---

## 🔧 Refactoring Campaign — Architecture Cleanup

> Bắt đầu từ Sprint 2.5, tiến hành refactor kiến trúc để giảm coupling, tăng testability.

### ✅ Sprint 2.5 — Final Verify Baseline
- **Mục tiêu**: Đảm bảo analyze 0 issues, 1296 tests pass
- **Kết quả**: ✅ Hoàn thành

### ✅ Sprint 3.0 — Baseline Verify
- **Mục tiêu**: Xác nhận baseline (analyze 0 + 1296 tests)
- **Kết quả**: ✅ Hoàn thành

### ✅ Sprint 3.1 — Characterization Tests
- **Mục tiêu**: Viết characterization tests cho trie/scoring/topic clusters
- **Kết quả**: ✅ Hoàn thành
- **Chi tiết**: Tạo tests bao phủ logic của `RiskKeywordTrie`, `ContextScoreCalculator`, và topic matching

### ✅ Sprint 3.2 — Extract ContextScoreCalculator (Cluster D)
- **Mục tiêu**: Tách `ContextScoreCalculator` ra khỏi `g_detection_engine.dart`
- **Kết quả**: ✅ Hoàn thành
- **File mới**: `lib/analysis/l2/g_detection/context_score_calculator.dart`
- **Giảm**: Coupling trong G-Detection engine

### ✅ Sprint 3.3 — Extract RiskKeywordTrie (Cluster B+C)
- **Mục tiêu**: Tách `RiskKeywordTrie` và `SentenceMatcher` ra riêng
- **Kết quả**: ✅ Hoàn thành
- **File mới**: `lib/analysis/l2/g_detection/risk_keyword_trie.dart`, `sentence_matcher.dart`

### ✅ Sprint 3.4 — Extract GDetectionAssetLoader (Cluster A)
- **Mục tiêu**: Tách asset loading logic ra khỏi engine
- **Kết quả**: ✅ Hoàn thành
- **File mới**: `lib/analysis/l2/g_detection/g_detection_asset_loader.dart`

### ✅ Sprint 3.5 — Slim Engine to Orchestrator
- **Mục tiêu**: Trim G-Detection engine thành orchestrator mỏng, ủy quyền logic cho extracted modules
- **Kết quả**: ✅ Hoàn thành
- **Hiệu quả**: Engine giờ chỉ điều phối, logic nằm ở modules riêng biệt

---

## 🚀 Sprint hiện tại & Kế hoạch tiếp theo

### ✅ Sprint 4 — Coordinator + Services Refactor
- **Mục tiêu**: Refactor `analysis_coordinator.dart` và `services/`
- **Kết quả**: ✅ Hoàn thành
- **Công việc**:
  - Tách native bridge thành interface + implementations (Android, Simulator)
  - File mới: `native_bridge_interface.dart`, `android_call_shield_bridge.dart`, `simulator_call_shield_bridge.dart`
  - Refactor `OverlayManager` Kotlin thành các manager riêng (Alert, IncomingCall, Monitoring)
  - Refactor `VoskSttManager` Kotlin
  - Cập nhật `app_database.dart`, `call_history_dao.dart`
  - Cập nhật `gemini_client.dart`, `app_theme.dart`

### ✅ Sprint 5 — UI Refactor + Accessibility
- **Mục tiêu**:
  - Refactor UI components theo atomic design
  - Thêm accessibility (semantics, screen reader support)
  - Cải thiện theme system
- **Kết quả**: ✅ Hoàn thành (analyze 0 issues, 1311 tests pass)
- **Chi tiết**:
  - **5.1** — Survey UI: xác định 12+ mẫu trùng lặp, lỗi màu RiskLevel, thiếu a11y
  - **5.2a** — Fix `RiskLevel.color` thành single source of truth; tạo `lib/ui/widgets/` foundation (8 shared widgets)
  - **5.2b** — Refactor 8 call sites (history_item_card, result_page, simulation_page, history_page, monitoring_page, home_page, rights_dialog, onboarding_page) dùng shared widgets
  - **5.2c** — Accessibility pass:
    - `RiskLevelIndicator`: `SemanticsService.sendAnnouncement` khi risk thay đổi + live region
    - `RiskBadge`: `Semantics(label)` cho screen readers
    - `LoadingElevatedButton`: announce "Đang xử lý…" khi loading
    - Home page: `Semantics(button: true)` trên QuickActionCard và tips button
    - Home page: `Semantics(liveRegion: true)` trên cảnh báo quyền
    - Monitoring: `Semantics(label)` trên keyword chips (phụng bậc severity)
  - **5.2d** — Verify: `flutter analyze` 0 issues, `flutter test` 1311 pass
  - **Widgets được tạo**: `SectionCard`, `InfoLine`, `RiskBadge`, `RiskAccentCard`, `LoadingElevatedButton`, `SettingsActionButton`, `HomeBackButton`, `AppSearchField`, `showConfirmDialog`

### ✅ Sprint 6 — Test Coverage + Polish
- **Mục tiêu**:
  - Tăng test coverage lên target (≥80%)
  - Bao phủ UI widgets & pages còn thiếu
  - Polish UI/UX, sửa test failures tiền tồn
  - Clean lint (analyze 0 issues)
- **Kết quả**: ✅ Hoàn thành (analyze 0 issues, 1454 tests pass)
- **Chi tiết**:
  - **6.1** — Survey test coverage: xác định các gap trong shared widgets, onboarding page, monitoring page, rights dialog
  - **6.2** — Viết tests cho 8 shared widgets (`SectionCard`, `RiskAccentCard`, `RiskBadge`, `InfoLine`, `AppActionButtons`, `LoadingElevatedButton`, `AppSearchField`, `SettingsActionButton`)
  - **6.3** — Tạo `onboarding_page_test.dart`: navigation, route guards, permission gating
  - **6.4a** — Mở rộng `risk_level_indicator_test.dart`: live region semantics, color binding per level
  - **6.4b** — Mở rộng `monitoring_page_test.dart`: STT fallback banner, network badge, keyword chip capping (5), analysis result rendering, creator mode, dismissing state
  - **6.4c** — Mở rộng `rights_dialog_test.dart`: "Cấp tất cả" loading state, permission descriptions, manual setup hint
  - **6.4d** — Sửa failures tiền tồn: `enabled=false` trong home_page_phase3 nav tests, bỏ throwaway `_diag_test`; thêm logo fallback + button styling detail tests
  - **6.5** — Final verify: `flutter analyze` **0 issues**, `flutter test` **1454 pass**; dọn sạch toàn bộ lint warnings/info trong test files (unused vars, const constructors, naming)

---

## 📊 Thống kê dự án

| Metric | Giá trị |
|--------|---------|
| Tổng commits | ~35+ |
| Dart files | ~90+ |
| Tests | 1454 |
| Analysis issues | 0 |
| Ngày phát triển | ~46 ngày (06/05 → 20/06/2026) |
| Kiến trúc | 3-tier analysis (L1/L2/L3) + Native bridge |
| Platform | Flutter (Android/iOS) + Kotlin native overlay |
| Shared UI widgets | 9 (`lib/ui/widgets/`) |
| A11y surfaces | RiskLevelIndicator (live region), RiskBadge, keyword chips, LoadingElevatedButton, QuickActionCard, tips button, permission warning |

---

## 🎯 Roadmap tổng quát

```
[05/05]──────[09/05]──────[13/05]──────[17/05]──────────[12/06]──────[20/06]──────> Tương lai
  │            │             │             │               │             │
  Khởi tạo   Phase 4+5     Phase 7+8    Stabilize     Features      Refactoring
  Android/KT  (L1/L2)      (L3/Port)    Services      nâng cao      Campaign
             Flutter      Flutter      + Tests
             Migration    Migration

                                                    ┌──────────────────────────────────┐
                                                    │ ✅ Sprint 4: Coordinator         │
                                                    │ ✅ Sprint 5: UI + A11y           │
                                                    │ ✅ Sprint 6: Coverage + Polish   │
                                                    └──────────────────────────────────┘
```

---

> **Cập nhật lần cuối**: 20/06/2026
> **Trạng thái**: ✅ Sprint 6 hoàn thành — analyze 0 issues, 1454 tests pass
