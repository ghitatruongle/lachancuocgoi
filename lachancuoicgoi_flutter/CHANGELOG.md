# Nhật Ký Thay Đổi (CHANGELOG)

Tất cả các thay đổi đáng chú ý của dự án **Lá Chắn Cuộc Gọi (anti-scam call shield)** sẽ được ghi nhận tại tài liệu này.

---

## [1.4.0+9] - 2026-06-25

### Security
- **Git history scrubbed**: Rotated all 21 Gemini API keys, used BFG Repo-Cleaner to delete `env.json` and replace all `AIza*` secrets across the entire git history. Force-pushed clean history to remote.
- **Pre-commit hook**: Added `.git/hooks/pre-commit` that blocks commits of `env.json` or staged `AIza*` key patterns. Installable via `bash tool/install-hooks.sh`.

### Dependencies Upgraded
- `flutter_riverpod` 2.6 → 3.3 (added `misc.dart` import for `Override`, `ref.mounted` checks in `DeveloperModeController`).
- `go_router` 14.8 → 17.3 (clean upgrade, no breakage).
- `permission_handler` 11.4 → 12.0 (clean upgrade, compileSdk already at 36).
- Dropped `path_provider_android` dependency override (tech debt cleared).

### Refactor — File Size Reduction
- `scam_graph_builder.dart` 1050 LOC → 4 part-files (118 + 232 + 396 + 347) by scenario category.
- `l1_analysis.dart` 786 LOC → 680 + 114 (extracted `FlatTrie` to `flat_trie.dart`).
- `native_call_shield_bridge.dart` 763 LOC → 575 + 36 + 166 (extracted `bridge_models.dart`, deduplicated ~200 LOC with `native_bridge_interface.dart`).
- `g_thinking.dart` 685 LOC → 638 + 50 (extracted `TierClassification` + `AggregatedRisk` value objects).

### Simulator Bridge Expansion
- **SimulatorScriptCatalog**: 3 selectable scam scenarios (tax authority, bank fraud, prize) replacing the single hard-coded script.
- **SimulatorCreatorMode**: Replay user-supplied transcript lines for custom testing on non-Android platforms.
- **SimulatorPermissionGate**: No-op gate returning `allGranted` to keep the UI contract consistent.
- **CI**: Added `verify-ios-config` job to catch iOS Xcode project config drift.

### Code Quality
- Reformatted 152 drifted files (`dart format`).
- Fixed 6 `curly_braces_in_flow_control_structures` info-level lints.
- Adopted Conventional Commits convention (documented in `CONTRIBUTING.md`).
- Tests: 1331 → **1342** (+11 new simulator tests).
- `dart analyze`: **0 issues** (0 errors, 0 warnings, 0 info).

---

## [1.3.0+8] - 2026-06-22

### Cải Tiến Kiến Trúc & Chất Lượng Mã Nguồn
- **Tách biệt Dependency Direction**: Định nghĩa `AssetLoader` và `AppLogger` interfaces trong `lib/core` giúp lớp phân tích logic (`analysis/`) độc lập hoàn toàn khỏi Flutter SDK.
- **Repository Pattern cho Data Layer**: Chuyển đổi toàn bộ việc truy xuất trực tiếp `CallHistoryDao` sang sử dụng `CallHistoryRepository` interface, đảm bảo decoupling giữa UI/Controller và DB.
- **Tái cấu trúc bộ điều khiển giám sát**: Chia nhỏ file `monitoring_controller.dart` quá lớn thành 3 module bổ trợ chuyên biệt:
  - `monitoring_session_manager.dart` (quản lý session/snapshot)
  - `monitoring_simulation_helper.dart` (giả lập)
  - `monitoring_stream_handler.dart` (lắng nghe stream)
- **Cải tiến thuật toán tính Độ tự tin (Confidence calculation)** của L3 Analyzer dựa trên sự đồng thuận giữa các tầng (L1, L2, L3) và độ dài transcript.

### Trải Nghiệm Người Dùng (UX/UI & a11y)
- **Rationale Permission Dialogs**: Thêm dialog giải thích chi tiết lý do xin từng quyền nhạy cảm bằng tiếng Việt trước khi hiển thị popup xin quyền hệ thống. Tích hợp trực tiếp vào quá trình Onboarding.
- **Rung phản hồi (Haptic Feedback)**: Thêm rung phản hồi khi phát hiện rủi ro mức độ Orange (vibrate) hoặc Red (heavyImpact) để cảnh báo tức thời cho người dùng.
- **Hỗ trợ Tiếp cận (a11y Semantics)**: Bổ sung các nhãn `Semantics` cho các widget chính ở màn hình chính và màn hình giám sát (waveform, risk level card, action buttons) hỗ trợ người khiếm thị sử dụng Screen Reader.
- **Dark Mode**: Toggle button chuyển đổi giao diện sáng/tối trong Settings Dialog và tự động lưu trạng thái qua SharedPreferences.

### Kiểm Thử (Testing) & DevOps
- **Sửa lỗi Stream Reactive của Lịch sử**: Sửa constructor `AppDatabase` dùng chung instance `CallHistoryDao` giúp cập nhật dữ liệu reactive lên UI hoạt động ổn định.
- **Bổ sung Fuzz Testing & Negative Path**:
  - `l1_fuzz_test.dart`: Fuzz test cho `FlatTrie` và `PIIStripper` với 1000+ vòng sinh ngẫu nhiên.
  - `pii_stripper_negative_test.dart`: Kiểm tra các giá trị biên, ký tự Unicode đặc biệt, các chuỗi số sai định dạng và giới hạn bộ nhớ map tokens ở mức tối đa 200.
- **Kiểm thử Golden (Galaxy J6+)**: Viết `monitoring_page_golden_test.dart` tương thích tỷ lệ màn hình Samsung Galaxy J6+ (360x740 logic).
- **CI Pipeline**: Tích hợp đo lường và tải lên Code Coverage (lcov.info) dạng workflow artifact; bổ sung job kiểm tra build debug APK Android tự động.
- **CD Pipeline**: Tự động build release unsigned APK và tạo GitHub Release chứa bản build này khi push git tag dạng `v*`.

---

## [1.2.0] - 2026-04-15
- **Tích hợp Gemini L3**: Hỗ trợ phân tích ngữ cảnh cuộc gọi thông qua Gemini Flash API.
- **Fallback Cơ Chế Phân Tích**: Tự động chuyển đổi sang L2 (Vosk/TFLite offline) khi mất kết nối mạng.
- **PII Stripper**: Loại bỏ thông tin cá nhân (SĐT, OTP, CCCD) trước khi gửi transcript lên API Gemini để bảo vệ quyền riêng tư của người dùng.

---

## [1.1.0] - 2026-02-10
- **Native Monitoring Service**: Xây dựng service nền Android nhận dạng trạng thái cuộc gọi và lấy RMS âm thanh.
- **Bảng lịch sử cuộc gọi**: Tích hợp database SQLite thông qua thư viện `sqflite` lưu trữ lịch sử các cuộc gọi đã được giám sát.

---

## [1.0.0] - 2025-12-01
- **Bản phát hành đầu tiên**:
  - Giao diện trang chủ và cấu hình quyền cơ bản.
  - Phân tích từ khóa L1 (offline qua trie).
