# Hướng Dẫn Đóng Góp (Contributing Guide)

Chào mừng bạn đến với dự án **Lá Chắn Cuộc Gọi (anti-scam call shield)**! Chúng tôi rất trân trọng mọi sự đóng góp của bạn để cùng xây dựng một cộng đồng an toàn và bảo mật trước nạn lừa đảo viễn thông.

Dưới đây là tài liệu hướng dẫn chi tiết cách thiết lập dự án, quy tắc phát triển và quy trình gửi đóng góp của bạn.

---

## 1. Thiết Lập Môi Trường Phát Triển

Để bắt đầu làm việc với mã nguồn Flutter của dự án, vui lòng thực hiện các bước sau:

1. **Cài đặt Flutter SDK:**
   - Yêu cầu phiên bản SDK tối thiểu: `>=3.9.0`.
   - Vui lòng chạy lệnh sau để kiểm tra: `flutter --version`.

2. **Cài đặt SQLite cho môi trường Desktop/FFI (nếu phát triển trên macOS/Windows/Linux):**
   - Dự án sử dụng `sqflite_common_ffi` để chạy các bài test trên máy tính cá nhân.
   - Trên Windows, bạn cần cài đặt SQLite FFI (nếu chưa có sẵn). Cách đơn giản nhất là chạy `sqfliteFfiInit()` trong setup của các test case.

3. **Cấu hình file môi trường `env.json`:**
   - Tạo file `env.json` ở thư mục gốc của dự án (nếu chưa có).
   - Nội dung mẫu:
     ```json
     {
       "gemini_api_keys": [],
       "model": "gemini-1.5-flash"
     }
     ```
   - *Lưu ý:* File `env.json` đã được đưa vào danh sách `.gitignore` để tránh rò rỉ mã bảo mật API Key của bạn.

4. **Tải các thư viện phụ thuộc:**
   - Chạy lệnh: `flutter pub get`.

---

## 2. Quy Tắc Viết Code (Coding & Linting Rules)

Chúng tôi áp dụng các tiêu chuẩn viết code nghiêm ngặt để đảm bảo chất lượng và khả năng bảo trì:

1. **Định dạng code:**
   - Luôn chạy định dạng code trước khi tạo commit:
     ```bash
     dart format lib/ test/
     ```

2. **Phân tích tĩnh (Static Analysis):**
   - Dự án sử dụng gói cấu hình lints tiêu chuẩn `flutter_lints`.
   - Vui lòng đảm bảo không có bất kỳ cảnh báo phân tích nào bằng cách chạy:
     ```bash
     flutter analyze
     ```

3. **Nguyên tắc thiết kế hệ thống:**
   - **Tách biệt Dependency Direction**: Các phân tích thuần Dart (như phân tích từ khóa L1, các thuật toán logic) không được phụ thuộc trực tiếp vào Flutter SDK hay các API nền tảng. Thay vào đó hãy sử dụng interfaces.
   - **Repository Pattern ở Data Layer**: Tuyệt đối không gọi trực tiếp các lớp DAO (`CallHistoryDao`) từ UI hay Controller. Mọi tương tác dữ liệu phải thông qua `CallHistoryRepository`.

---

## 3. Chạy Kiểm Thử (Testing)

Chúng tôi đòi hỏi tỷ lệ bao phủ kiểm thử cao để duy trì sự ổn định của hệ thống.

1. **Chạy bộ kiểm thử nhanh (Fast Test Suite - Exclude Perf):**
   - Đây là câu lệnh chạy kiểm thử bắt buộc đối với mọi pull request:
     ```bash
     flutter test --exclude-tags perf
     ```

2. **Chạy kiểm thử hiệu năng (Perf Benchmarks):**
   - Chạy các test đo lường hiệu năng và xử lý dữ liệu nặng:
     ```bash
     ./tool/run_tests.sh
     ```

3. **Chạy kiểm thử Golden (Golden UI Tests):**
   - Sinh lại các hình ảnh giao diện mẫu để so sánh:
     ```bash
     flutter test test/UI/monitoring_page_golden_test.dart --update-goldens
     ```

4. **Kiểm tra độ bao phủ (Code Coverage):**
   - Để đo lường test coverage:
     ```bash
     flutter test --coverage --exclude-tags perf
     ```

---

## 4. Quy Trình Đóng Góp (Git & PR Process)

1. **Fork** kho lưu trữ này về tài khoản cá nhân của bạn.
2. Tạo một **nhánh mới (branch)** chứa tính năng hoặc bản sửa lỗi của bạn:
   ```bash
   git checkout -b feature/ten-tinh-nang-moi
   # Hoặc
   git checkout -b fix/ten-loi-can-sua
   ```
3. Thực hiện sửa đổi và **viết test tương ứng** cho tính năng/bug sửa đổi đó.
4. Chạy `flutter analyze` và `flutter test --exclude-tags perf` tại máy local để kiểm tra.
5. Thực hiện commit code với thông điệp rõ ràng:
   ```bash
   git commit -m "feat: thêm tính năng X và viết unit test"
   ```
6. **Push** nhánh code của bạn lên GitHub và gửi **Pull Request (PR)** đến nhánh `main` của dự án gốc.
7. Đội ngũ phát triển chính sẽ kiểm tra, chạy CI Pipeline và phê duyệt PR của bạn!
