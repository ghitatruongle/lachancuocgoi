# Hướng Dẫn Lập Kế Hoạch (Plan Prompt)

**VUI LÒNG ĐỌC VÀ TUÂN THỦ FILE NÀY MỖI KHI NGƯỜI DÙNG YÊU CẦU TẠO MỘT KẾ HOẠCH MỚI.**

---

## 1. Yêu Cầu Về Tệp (File)
- Kế hoạch **KHÔNG** được viết dưới dạng Markdown thông thường mà phải được viết vào một file `.html`.
- Tên file bắt buộc tuân theo định dạng: `DD_MM_YY.html` (ví dụ: `17_05_26.html`).

## 2. Cấu Trúc Bắt Buộc Của Kế Hoạch (HTML)

Nội dung bên trong file HTML phải bao gồm các phần sau:

### Tiêu đề chính
- Tiêu đề của kế hoạch (BẮT BUỘC phải kèm theo Tháng và Năm hiện tại).
- Ví dụ: `<h1>Kế Hoạch Nâng Cấp Ứng Dụng - Tháng 05/2026</h1>`

### 3 Mục Nội Dung Cốt Lõi:

#### Mục 1: Khái quát kế hoạch
- Trình bày tổng quan mục tiêu: Kế hoạch này dùng để làm gì?
- Mục đích cuối cùng đạt được là gì.

#### Mục 2: Phân tích chi tiết
- Ghi rõ các phân tích về các điểm cần sửa chữa hoặc xây dựng.
- Trình bày cách thức/phương án sửa chữa, triển khai.
- Chỉ ra ưu điểm và nhược điểm của các cách thức trên.
- (Lưu ý: Dành không gian hợp lý, bố cục rõ ràng để trình bày các phân tích này).

#### Mục 3: Bảng tiến độ chi tiết (Giai đoạn & Công việc)
- Dựa trên các vấn đề đã phân tích ở Mục 2, lập một **Bảng chi tiết (Table)**.
- Chia bảng thành các giai đoạn (Phases) phù hợp để giải quyết lần lượt các vấn đề.
- **YÊU CẦU QUAN TRỌNG:** Mỗi đầu việc trong bảng phải có kèm theo một ô đánh dấu (Checkbox - `<input type="checkbox">`).

## 3. Lưu Ý Dành Cho AI Trong Quá Trình Làm Việc
- Trong quá trình thực hiện kế hoạch, mỗi khi AI (bạn) hoàn thành xong một hạng mục công việc trong bảng ở Mục 3, AI **phải chủ động mở file HTML này lên** và cập nhật mã nguồn để đánh dấu tích (`checked="checked"`) vào ô checkbox của hạng mục tương ứng vừa làm xong.
