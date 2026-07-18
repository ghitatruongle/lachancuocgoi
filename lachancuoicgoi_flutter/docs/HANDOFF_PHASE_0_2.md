# Bàn giao lịch sử — Phase 0 đến Phase 2

Tài liệu này ghi lại giai đoạn tối ưu trước v1.6.0. Trạng thái phát hành hiện
hành nằm trong `RELEASE_NOTES_v1.6.0.md` và
`RELEASE_CHECKLIST_v1.6.0.md`; nếu có khác biệt, hai tài liệu v1.6.0 được ưu
tiên.

## Các cải tiến nền tảng đã có từ giai đoạn trước

- Pipeline L1/L2/L3 có fallback, circuit breaker và phân tích song song.
- Android bridge có timeout; monitoring hiển thị trạng thái STT không khả dụng.
- Màu rủi ro được chuẩn hóa theo `RiskLevel`.
- Các nền tảng ngoài Android hiển thị rõ chế độ demo.
- Cài đặt theme theo hệ thống và health summary cho pipeline đã được bổ sung.

## Quyết định đã thay đổi trong v1.6.0

- Chỉ đóng gói model Vosk đầy đủ tại `assets/model-vn`; không còn lựa chọn
  model rút gọn.
- Giữ nguyên toàn bộ JSON trong `assets/`, nhưng không tải cấu hình hoặc JSON
  mới từ Internet khi ứng dụng đang chạy.
- L3 gọi Gemini trực tiếp từ thiết bị qua `env.json`; không có đường gọi qua
  máy chủ trung gian.
- `env.json` không được đưa vào hệ thống quản lý mã nguồn. Key nằm trong APK/AAB
  có thể bị trích xuất, vì vậy phải giới hạn quota và có kế hoạch xoay key.
- Android là nền tảng production; iOS, Web và Desktop là bản demo.

## Cách xác minh hiện hành

```bash
flutter pub get --enforce-lockfile
dart run tool/verify_release_version.dart
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test --exclude-tags perf
flutter test test/smoke/platform_demo_smoke_test.dart
```

Kiểm tra Android lint, unit test Kotlin, APK/AAB, chữ ký và native page size
16 KB được mô tả trong `RELEASE_CHECKLIST_v1.6.0.md`.

## Giới hạn còn lại

- iOS/Web/Desktop không cung cấp STT cuộc gọi thật, overlay hoặc call screening.
- Gemini yêu cầu người dùng đồng ý gửi dữ liệu cloud và phụ thuộc quota/network.
- versionCode `14` phải được xác nhận chưa từng dùng trên Play Console trước khi
  upload; công cụ trong repo không thể tự truy vấn Play Console.
