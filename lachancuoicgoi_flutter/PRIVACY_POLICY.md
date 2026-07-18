# Chính sách Bảo mật — Lá Chắn Cuộc Gọi

Cập nhật lần cuối: 18/07/2026

## Tổng quan

Lá Chắn Cuộc Gọi ("Ứng dụng") là ứng dụng chống lừa đảo qua cuộc gọi dành cho
Android. Ứng dụng bảo vệ người dùng bằng cách phân tích nội dung cuộc gọi theo
thời gian thực và cảnh báo khi phát hiện dấu hiệu lừa đảo.

## Dữ liệu được thu thập

### Dữ liệu âm thanh và transcript

- Ứng dụng **nghe nội dung cuộc gọi** (trên Android) để chuyển đổi thành văn
  bản (STT) bằng engine Vosk chạy cục bộ trên thiết bị.
- Transcript được lưu cục bộ trên thiết bị và **không được gửi lên máy chủ**
  trừ khi người dùng bật tính năng phân tích đám mây (L3 Gemini).

### Phân tích đám mây (L3 Gemini) — Tùy chọn

- Khi người dùng **đồng ý bật cloud analysis**, transcript đã được ẩn thông tin
  cá nhân (PII) có thể được gửi đến Google Gemini để phân tích ngữ nghĩa sâu hơn.
- **Không** gửi số điện thoại, tên người gọi hoặc thông tin định danh khác.
- Người dùng có thể **thu hồi đồng ý** bất kỳ lúc nào trong phần Cài đặt.
- Khi chưa đồng ý hoặc mất mạng, ứng dụng hoạt động hoàn toàn offline (L1 + L2).

### Dữ liệu được lưu cục bộ

| Dữ liệu | Vị trí lưu | Thời hạn |
|---|---|---|
| Lịch sử cuộc gọi | SQLite database | 30 ngày (mặc định, có thể chỉnh) |
| Transcript | Database + file export | Theo chính sách lưu lịch sử |
| Snapshot phiên giám sát | SharedPreferences | Tự xóa sau khi lưu hoặc 30 phút |
| Log chẩn副局长 | Internal storage | 7 ngày |
| API key (Gemini) | Bundle trong APK | Theo phiên bản app |

### Dữ liệu KHÔNG được thu thập

- Số điện thoại người gọi
- Danh bạ
- Vị trí
- Thông tin thiết bị định danh
- Dữ liệu sử dụng / analytics

## Dữ liệu được sao lưu

Dữ liệu nhạy cảm (database, SharedPreferences, log, transcript) **bị loại khỏi**
Android backup và device transfer. Ứng dụng không sử dụng cloud backup cho dữ
liệu người dùng.

## Chia sẻ dữ liệu

- Ứng dụng **không bán** dữ liệu cho bên thứ ba.
- Ứng dụng **không chia sẻ** dữ liệu với bên thứ ba, ngoại trừ khi người dùng
  bật cloud analysis — khi đó transcript đã ẩn PII được gửi đến Google Gemini
  (Google LLC) để phân tích.
- Không có quảng cáo, SDK theo dõi hay analytics bên thứ ba.

## Quyền lợi người dùng

- **Xem lịch sử:** Người dùng có thể xem toàn bộ lịch sử cuộc gọi đã phân tích.
- **Xóa dữ liệu:** Người dùng có thể xóa toàn bộ lịch sử hoặc đặt lại dữ liệu
  nhạy cảm (bao gồm transcript, log, snapshot, danh sách chặn).
- **Thu hồi đồng ý cloud:** Người dùng có thể tắt cloud analysis bất kỳ lúc nào
  trong Cài đặt → Quyền riêng tư.
- **Xuất log:** Người dùng có thể xuất tối đa 500 log gần nhất (đã ẩn dữ liệu
  nhạy cảm) để gửi chẩn đoán.

## Bảo mật

- Dữ liệu được lưu trữ cục bộ trên thiết bị của người dùng.
- Không có tài khoản người dùng, không có xác thực server.
- API key Gemini nằm trong APK/AAB và có thể bị trích xuất bởi bên có kiến thức
  kỹ thuật. Người dùng nên giới hạn quota tại Google Cloud Console và xoá key
  khi nghi ngờ bị lộ.
- Ứng dụng sử dụng Android Keystore để bảo vệ dữ liệu nhạy cảm khi khả dụng.

## Children's Privacy

Ứng dụng không dành cho trẻ em dưới 13 tuổi và không cố ý thu thập dữ liệu
từ trẻ em.

## Thay đổi Chính sách

Chính sách này có thể được cập nhật khi ứng dụng phát hành phiên bản mới.
Phiên bản mới nhất luôn có sẵn trong repository mã nguồn.

## Liên hệ

Nếu có câu hỏi về chính sách bảo mật, vui lòng mở Issue tại repository dự án
hoặc liên hệ qua email được liệt kê trong Google Play Console.
