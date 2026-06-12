# Debug Session: kotlin-build-check

**Status:** [RESOLVED — Build PASS, hardcode 1.12.0 confirmed cố ý]
**Date:** 2026-06-12
**Project:** lachancuocgoi (Android Kotlin - Call Screening App)
**Working dir:** `e:\lachancuocgoi\lachancuocgoi_kotline`

## Yêu cầu
- Phạm vi: Toàn bộ project Kotlin
- Loại bug: UI/Build/Lỗi compile
- Phương pháp: Tự build check, thu thập evidence từ Gradle output

## Lệnh đã chạy
```
cd "e:\lachancuocgoi\lachancuocgoi_kotline"
.\gradlew.bat assembleDebug --no-daemon
```

## Evidence timeline (3 lần build)

### Build v1 — core-ktx 1.12.0 (nguyên trạng)
- Thời gian: 8m 25s
- Kết quả: **BUILD SUCCESSFUL** — 39/39 tasks executed
- APK: `app-debug.apk` 184 MB ✓
- Không có compile error

### Build v2 — thử đổi sang `libs.androidx.core.ktx` (catalog 1.17.0)
- Thời gian: 1m 39s
- Kết quả: **BUILD FAILED** ở `:app:checkDebugAarMetadata`
- Lỗi (trích):
  ```
  1. Dependency 'androidx.core:core:1.17.0' requires compile against version 36+
     :app is currently compiled against android-34.
     Maximum recommended compile SDK version for AGP 8.4.1 is 34.
  2. Dependency 'androidx.core:core:1.17.0' requires AGP 8.9.1 or higher.
     This build currently uses AGP 8.4.1.
  3. Dependency 'androidx.core:core-ktx:1.17.0' requires compile against 36+
  4. Dependency 'androidx.core:core-ktx:1.17.0' requires AGP 8.9.1 or higher.
  ```
- Kết luận: **1.17.0 không tương thích với compileSdk 34 + AGP 8.4.1.**

### Build v3 — revert về 1.12.0
- Thời gian: 1m 20s
- Kết quả: **BUILD SUCCESSFUL** — tất cả tasks `UP-TO-DATE`
- APK vẫn còn nguyên (cached)

## Đối chiếu Hypotheses
| # | Hypothesis | Kết luận |
|---|------------|----------|
| H1 | JDK 17 / Android SDK thiếu | ❌ BÁC BỎ |
| H2 | compose-bom không chứa `material-icons-extended-android:1.6.7` | ❌ BÁC BỎ |
| H3 | Plugin `org.jetbrains.kotlin.plugin.compose` không resolve | ❌ BÁC BỎ |
| H4 | Room KSP fail vì schema/KSP version | ❌ BÁC BỎ |
| H5 | Lỗi compile Kotlin do Compose API | ❌ BÁC BỎ |
| H6 | `local.properties` thiếu | ❌ BÁC BỎ |

## Root cause analysis cho inconsistency core-ktx
- Lúc đầu tôi giả định hardcode 1.12.0 là "inconsistency" do dev quên đồng bộ.
- **Evidence Build v2 cho thấy:** hardcode 1.12.0 là quyết định **có chủ đích** — version này tương thích với AGP 8.4.1 + compileSdk 34.
- Để nâng lên 1.17.0, cần upgrade compileSdk → 36 và AGP → 8.9.1+ (công việc migration lớn, ngoài phạm vi debug build).
- Kết luận: **không sửa** — để nguyên hardcode 1.12.0.

## Kết luận cuối
✅ **Project build sạch 100% với core-ktx 1.12.0.** Không có lỗi compile, dependency, resource. APK debug đã sinh ra thành công (175.8 MB).

### Cấu hình thực tế đang dùng
| Thành phần | Version |
|---|---|
| AGP | 8.4.1 |
| Kotlin | 2.0.20 |
| KSP | 2.0.20-1.0.24 |
| Gradle | 8.6 |
| compileSdk / targetSdk / minSdk | 34 / 34 / 26 |
| JVM target | 17 |
| compose-bom | 2024.09.02 |
| Room | 2.6.1 |
| core-ktx | 1.12.0 (hardcode, cố ý) |
| Vosk | 0.3.38 |

## Artifacts hiện có trong repo (user chọn giữ lại)
- [debug-kotlin-build-check.md](file:///e:/lachancuocgoi/lachancuocgoi_kotline/debug-kotlin-build-check.md) — file này
- [build-output.log](file:///e:/lachancuocgoi/lachancuocgoi_kotline/build-output.log) — log build v1
- [build-output-v2.log](file:///e:/lachancuocgoi/lachancuocgoi_kotline/build-output-v2.log) — log build v2 (failed)
- [build-output-v3.log](file:///e:/lachancuocgoi/lachancuocgoi_kotline/build-output-v3.log) — log build v3
- `app/build/` — toàn bộ intermediates + APK
- [app/build.gradle.kts](file:///e:/lachancuocgoi/lachancuocgoi_kotline/app/build.gradle.kts) — đã revert, không thay đổi gì so với ban đầu
