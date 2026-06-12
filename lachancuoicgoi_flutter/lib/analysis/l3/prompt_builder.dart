class PromptBuilder {
  static String buildAnalysisPrompt(String text) {
    return '''
Bạn là người phân tích chuyên nghiệp, khách quan về cuộc gọi điện thoại.
Hãy phân tích đoạn hội thoại dưới đây và xác định xem đây có phải là cuộc gọi lừa đảo không.

TRÍCH ĐOẠN CUỘC GỌI CẦN PHÂN TÍCH:
[START_CALL]
$text
[END_CALL]

BƯỚC 1 — SUY LUẬN (nghĩ thầm):
- Ai gọi? Mục đích thực sự là gì?
- Có yêu cầu chuyển tiền, cung cấp OTP, tải app, hay đe dọa pháp lý không?
- Có tạo sự cấp bách giả tạo không?
- Có yêu cầu thông tin cá nhân nhạy cảm như CCCD, mật khẩu, số tài khoản không?

BƯỚC 2 — KẾT LUẬN:
Dựa trên suy luận ở Bước 1, trả về JSON.

TRẢ VỀ ĐÚNG JSON, KHÔNG markdown:
{
  "level": "green" hoặc "yellow" hoặc "orange" hoặc "red",
  "label": "Loại lừa đảo (nếu có, để trống nếu không phải lừa đảo)",
  "reason": "Giải thích ngắn gọn lý do",
  "recommendation": "Khuyến cáo ngắn gọn cho người dùng"
}

Quy tắc cấp độ:
- green: Cuộc gọi bình thường, an toàn
- yellow: Có dấu hiệu đáng ngờ, cần chú ý
- orange: Có nguy cơ lừa đảo
- red: Nguy hiểm, rõ ràng là lừa đảo
'''.trim();
  }

  static String buildSummarizationPrompt(String text) {
    return '''
Tóm tắt cuộc gọi trong đúng 1-2 câu ngắn gọn, nêu cực kỳ rõ ai gọi và mục đích.

VÍ DỤ 1:
Cuộc gọi: "Em là Tuấn bên ngân hàng Vietcombank, gọi xác nhận anh vừa đăng ký vay 100 triệu."
Tóm tắt: "Nhân viên ngân hàng gọi xác nhận khoản vay 100 triệu."

VÍ DỤ 2:
Cuộc gọi: "Tôi là đại úy công an Trần V, yêu cầu anh tới trụ sở giải quyết án ma túy."
Tóm tắt: "Người xưng là công an yêu cầu đến trụ sở giải quyết án oan."

NỘI DUNG CUỘC GỌI:
"$text"

Tóm tắt tiếng Việt:
'''.trim();
  }

  static String buildIncrementalPrompt(String newText, bool isFirstMessage) {
    if (isFirstMessage) {
      return '''
Bạn là người phân tích chuyên nghiệp, khách quan về cuộc gọi điện thoại.
Hãy theo dõi và phân tích đoạn hội thoại real-time.

BƯỚC 1 — SUY LUẬN: Xét xem có yêu cầu chuyển tiền, đe dọa, tạo sự cấp bách, hay xin OTP/app/link không.
BƯỚC 2 — KẾT LUẬN: Trả về JSON dựa trên suy luận.

Ví dụ CUỘC GỌI BÌNH THƯỜNG:
- "Anh ơi, mấy giờ đi ăn cơm?" -> green, label="", reason="Cuộc gọi xã hội bình thường"
- "Em chuyển khoản tiền trọ tháng 4 nhé, 3 triệu" -> green, label="", reason="Giao dịch tiền trọ quen thuộc"

Ví dụ CUỘC GỌI LỪA ĐẢO:
- "Tôi là trung tá công an, anh đang bị khởi tố, chuyển 5 triệu vào stk này để tạm giữ" -> red, label="Giả danh công an", reason="Xưng danh công an + đe dọa khởi tố + yêu cầu chuyển tiền"

[Đoạn hội thoại]:
"$newText"

TRẢ VỀ JSON, KHÔNG markdown:
{
  "level": "green" hoặc "yellow" hoặc "orange" hoặc "red",
  "label": "Loại lừa đảo (nếu có)",
  "reason": "Giải thích ngắn gọn",
  "recommendation": "Khuyến cáo ngắn gọn"
}
'''.trim();
    }
    return '''
[TIẾP TỤC] Văn bản mới: "$newText"
Phân tích bổ sung và cập nhật JSON. Giữ level = "green" nếu vẫn an toàn.

Ví dụ các phản hồi JSON hợp lệ:
{"level": "green", "label": "", "reason": "Cuộc gọi xã hội thông thường", "recommendation": "Tiếp tục bình thường"}
{"level": "yellow", "label": "Đáng ngờ", "reason": "Người gọi hỏi thông tin tài khoản", "recommendation": "Cẩn trọng, không cung cấp thông tin"}
{"level": "orange", "label": "Có nguy cơ", "reason": "Yêu cầu xác minh danh tính với lý do khẩn", "recommendation": "Không làm theo, xác minh nguồn gốc"}
{"level": "red", "label": "Giả danh công an", "reason": "Xưng danh cơ quan pháp luật + đe dọa + yêu cầu chuyển tiền", "recommendation": "Cúp máy ngay, báo công an"}

Định dạng JSON bắt buộc:
{"level": "green|yellow|orange|red", "label": "Loại lừa đảo(nếu có)", "reason": "Giải thích", "recommendation": "Khuyến cáo"}

Chỉ trả về JSON hợp lệ, không markdown, không giải thích.
'''.trim();
  }
}
