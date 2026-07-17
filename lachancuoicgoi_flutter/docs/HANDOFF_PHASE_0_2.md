# Bàn giao — Phase 0 → Phase 2 (cải thiện điểm số)

**Ngày:** 2026-07-11  
**Phạm vi:** Pipeline AI · Native Android · UX/UI · Cross-platform

---

## Đã hoàn thành

### Phase 0 — Quick wins
| ID | Việc | Trạng thái |
|----|------|------------|
| Q1 | Offline `parallel` → skip L3 (`AnalysisModePolicy.shouldSkipCloudTier`) | Done |
| Q2 | `speechRate` từ delta transcript → `setSpeechRate` | Done |
| Q3 | Parallel cursor = max(L1,L2,L3 processed length) | Done |
| Q4 | L2 degraded log khi `!isFullyReady` | Done |
| Q5 | Vosk path ưu tiên `model-vn` trước `model-vn-small` | Done |
| Q6 | MethodChannel timeout 5s trên `NativeCallShieldBridge` | Done |
| Q7 | `STT_UNAVAILABLE` + banner Mic/STT lỗi | Done |
| Q8 | Risk colors qua `RiskLevel.color` (result/history/simulation) | Done |
| Q9 | `ThemeMode.system` + toggle “Theo hệ thống” | Done |
| Q10 | Banner **Chế độ demo** + feature matrix non-Android | Done |

### Phase 1 — Core
| ID | Việc | Trạng thái |
|----|------|------------|
| A1 | Soft fusion (L1-only orange → yellow; L1 red hard path) | Done |
| A2 | Fast-track: L1 red **hoặc** L2 ≥ orange (không skip L3 vì L1 orange) | Done |
| A3 | L3 timeout 1.8s (0.8s khi local elevated) | Done |
| A4 | Session de-escalation trên parallel fuse | Done |
| A5 | `healthSummary()` + card “Trạng thái hệ thống AI” trong Settings | Done |
| B1 | Watchdog restart try/catch + `WATCHDOG_RESTART_FAILED` | Done |
| B2 | Banner `DEGRADED_NO_NOTIFICATION` | Done |
| B3–B4 | STT unavailable event; transcript history 12k chars | Done |
| D1–D3 | Demo honesty permissions; platform capabilities | Done |

### Phase 2 — một phần
| Việc | Trạng thái |
|------|------------|
| `PlatformCapabilities` + feature matrix | Done |
| Eval / OTA vocab / model-vn-small / full l10n / real iOS | **Chưa** (optional, không chặn bàn giao) |

---

## File chính đã đụng

**AI / core**
- `lib/analysis/analysis_coordinator.dart`
- `lib/analysis/analysis_fusion.dart`
- `lib/analysis/analysis_mode_policy.dart`
- `lib/core/platform_capabilities.dart`

**Android**
- `.../VoskSttManager.kt` — path model
- `.../BackgroundMonitoringService.kt` — `STT_UNAVAILABLE`
- `.../ServiceWatchdogReceiver.kt` — safe restart event
- `.../TranscriptionHub.kt` — `MAX_HISTORY_RETAIN = 12000`

**Bridge / UI**
- `lib/services/bridge_models.dart`, `native_call_shield_bridge.dart`
- `lib/ui/monitoring_page/*` (state, event router, page banners, controller)
- `lib/ui/home_page/home_page.dart`, `settings_dialog.dart`
- `lib/app/settings_controller.dart`, `lachancuocgoi_app.dart`
- `lib/ui/theme/app_theme.dart`, risk color consumers

**Tests mới/cập nhật**
- `test/analysis/analysis_coordinator_fusion_test.dart`
- `test/analysis/analysis_mode_policy_test.dart`
- `test/analysis/soft_fusion_and_offline_parallel_test.dart`
- `test/services/monitoring_state_parse_phase0_test.dart`
- `test/core/platform_capabilities_test.dart`
- SettingsState + `followSystemTheme` trong test helpers

---

## Cách verify

```bash
# Unit / widget (exclude perf)
flutter test --exclude-tags perf

# Tập trung thay đổi AI + bridge
flutter test test/analysis test/core test/services/monitoring_state_parse_phase0_test.dart test/services/settings_controller_test.dart

# Static analysis
dart analyze lib/ test/
```

**Manual Android**
1. Cold start monitoring — log Vosk load `model-vn` trước (không fail `model-vn-small` trước).
2. Tắt quyền thông báo (API 33+) → banner “Bật thông báo…”.
3. (Thiết bị không STT) → banner Mic/STT lỗi.
4. Settings → “Theo hệ thống” + “Trạng thái hệ thống AI”.

**Manual non-Android / Web**
1. Home hiện **Chế độ demo** + ma trận tính năng.
2. Bắt đầu giám sát chạy script giả; không claim quyền call screening/overlay.

---

## Hành vi cần nhớ (breaking soft)

1. **Fusion:** L1 orange một mình **không** còn alert orange; hạ **yellow**. L1 **red** vẫn hard path.
2. **Fast-track parallel:** L1 orange **không** skip L3; chỉ L1 red hoặc L2 ≥ orange.
3. **Offline parallel:** mode vẫn `parallel`, L3 bị skip; `isFallbackActive = true`.
4. **Demo permissions:** non-Android không còn `true` giả cho phone/overlay/accessibility/screening.

---

## Việc còn lại (nếu sprint sau)

1. Corpus eval precision/recall + CI gate  
2. Ship `model-vn-small` thật (quantize) nếu cần giảm APK  
3. ARB / gen-l10n  
4. Gộp sim bridge (`SimulatorCallShieldBridge` only)  
5. Overlay native a11y / theme parity  
6. Proxy API key (security — ngoài 4 hạng mục này nhưng critical production)

---

## Điểm kỳ vọng (ước lượng)

| Hạng mục | Trước | Sau Phase 0–1 |
|----------|-------|----------------|
| Pipeline AI | 132k | ~142k |
| Native Android | 102k | ~112–114k |
| UX/UI | 52k | ~62–64k |
| Cross-platform | 18k | ~24–26k |
