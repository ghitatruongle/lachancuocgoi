# Migration Baseline - Giai đoạn 0

Thư mục này dùng để đóng băng bằng chứng của app Kotlin gốc trước khi chuyển sang Flutter.

## Cách dùng

- `01_screenshots/kotlin_baseline`: ảnh chụp màn hình app Kotlin gốc.
- `01_screenshots/flutter_compare`: ảnh chụp Flutter sau này để đối chiếu.
- `02_videos`: video quay workflow Kotlin gốc.
- `03_transcripts/input_samples`: transcript mẫu để test L1/L2/L3.
- `03_transcripts/expected_kotlin_results`: kết quả phân tích mong đợi lấy từ app Kotlin.
- `04_test_logs/unit_tests`: log unit test Kotlin.
- `04_test_logs/instrumented_tests`: log Android instrumented test.
- `04_test_logs/manual_tests`: ghi chú test thủ công.
- `05_device_notes`: thông tin máy test, Android version, quyền đã cấp.
- `06_bug_reports`: bug phát hiện khi đối chiếu Kotlin/Flutter.
- `07_release_apk`: APK baseline nếu cần lưu lại.

## Checklist baseline cần thu thập

- [ ] HomePage sáng/tối.
- [ ] SettingsDialog.
- [ ] RightsDialog và trạng thái quyền.
- [ ] InstructDialog.
- [ ] Monitoring idle.
- [ ] Monitoring đang nghe mic.
- [ ] Monitoring có transcript.
- [ ] RedWarning.
- [ ] OrangeWarning.
- [ ] HistoryPage rỗng và có dữ liệu.
- [ ] ResultPage.
- [ ] SimulationPage list/search/category.
- [ ] TipsLessonPage.
- [ ] Workflow bật monitoring -> phân tích -> dừng -> lưu history -> mở result.
- [ ] Test L1 transcript mẫu.
- [ ] Test L2 transcript mẫu.
- [ ] Test L3 transcript mẫu nếu có API key.
- [ ] Test mất mạng L3 fallback L2.
- [ ] Test overlay permission.
- [ ] Test accessibility/call screening nếu có thiết bị thật.

## Quy ước đặt tên file

Dùng tên có thứ tự để dễ so sánh về sau:

- `01_home_light.png`
- `02_home_dark.png`
- `03_settings.png`
- `04_rights_permissions.png`
- `05_monitoring_idle.png`
- `06_monitoring_active.png`
- `07_red_warning.png`
- `08_orange_warning.png`
- `09_history.png`
- `10_result.png`
- `11_simulation.png`
- `12_tips.png`

Transcript mẫu nên đặt:

- `l1_safe.txt`, `l1_red.txt`
- `l2_safe.txt`, `l2_red.txt`
- `l3_safe.txt`, `l3_red.txt`

Kết quả mong đợi nên đặt cùng tên, dưới dạng `.json` hoặc `.md`.
