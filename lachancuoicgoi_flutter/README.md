# lachancuocgoi_flutter

A new Flutter project.

## Cấu hình API key (bắt buộc trước khi build)

File `` chứa Gemini API keys và **không được commit** vào repo (đã bị `.gitignore` loại bỏ).
Vì `pubspec.yaml` khai báo `` là asset, bạn **phải tự tạo file này** trước khi chạy
`flutter run` / `flutter build`, nếu không build sẽ báo lỗi thiếu asset.

Các bước:

1. Copy file mẫu thành ``:
   - macOS/Linux: `cp env.example.json `
   - Windows: `copy env.example.json `
2. Mở `` và thay các giá trị placeholder bằng Gemini API key thật của bạn
   (key hợp lệ bắt đầu bằng `AIza...`). Lấy key tại [Google AI Studio](https://aistudio.google.com/apikey).
3. Chạy `flutter pub get` rồi build/run như bình thường.

> ⚠️ **Bảo mật**: không commit `` lên git. Lưu ý rằng key trong `` sẽ bị bundle
> vào APK — xem `SECURITY.md` để biết khuyến nghị rotate key và phương án an toàn hơn.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
