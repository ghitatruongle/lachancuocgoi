# Bảo mật Gemini API key — v1.6.0

## Kiến trúc đã chọn

Phiên bản `1.6.0+14` gọi Gemini trực tiếp từ thiết bị bằng
`google_generative_ai`. `EnvironmentApiKeyProvider` đọc và xoay nhiều key từ
`env.json`; one-shot, incremental chat và summarizer phải dùng chung provider.

Không có backend proxy và không còn biến `L3_BACKEND_URL`.

## Giới hạn cần chấp nhận

`env.json` được bundle vào APK/AAB. Obfuscation chỉ làm chậm việc đọc key và
không phải mã hóa bí mật: người có artifact vẫn có thể trích xuất key.

Biện pháp vận hành bắt buộc:

- Không đưa `env.json` vào hệ thống quản lý mã nguồn.
- Giới hạn API/quota của key trong Google Cloud ở mức thấp nhất có thể.
- Theo dõi quota và cảnh báo bất thường.
- Xoay hoặc thu hồi key ngay khi nghi ngờ bị lộ.
- Không ghi key, prompt, transcript hoặc response body vào log.
- Release build phải chạy `dart run tool/validate_release_env.dart env.json`;
  công cụ chỉ báo số key hợp lệ và không in giá trị.

## Consent dữ liệu cloud

Offline L1+L2 là mặc định. Trước lần đầu chạy Gemini/Parallel có L3, ứng dụng
phải giải thích dữ liệu được gửi và lưu `CLOUD_ANALYSIS_CONSENT_V1` sau khi
người dùng đồng ý. Khi chưa đồng ý, đã thu hồi, mất mạng hoặc key lỗi, ứng dụng
fallback về L1+L2 và không coi toàn phiên là thất bại.

## Quy trình build local

1. Tạo `env.json` từ file mẫu và điền key hợp lệ.
2. Chạy `dart run tool/validate_release_env.dart env.json`.
3. Chạy `powershell -ExecutionPolicy Bypass -File tool/build_release.ps1`.
4. Không chia sẻ `env.json` hoặc log build có dữ liệu nhạy cảm.
