class PromptBuilder {
  /// Giới hạn số ký tự tối đa của transcript để tránh vượt quá context window (khoảng 4K tokens ~ 16K chars)
  static const int _maxTranscriptLength = 12000;

  /// Cắt bớt transcript nếu quá dài, giữ lại phần đầu (greeting) và phần cuối (hiện tại)
  static String buildContextWindow(String text) {
    if (text.length <= _maxTranscriptLength) return text;
    
    // Giữ lại 2000 ký tự đầu và phần còn lại ở cuối
    const int keepStart = 2000;
    const int keepEnd = _maxTranscriptLength - keepStart - 50; // Trừ hao chuỗi nối
    
    final start = text.substring(0, keepStart);
    final end = text.substring(text.length - keepEnd);
    
    return '$start\n\n...[ĐÃ LƯỢC BỎ PHẦN GIỮA DO QUÁ DÀI]...\n\n$end';
  }

  static String buildAnalysisPrompt(String text) {
    final contextText = buildContextWindow(text);
    return '''
Bạn là chuyên gia phân tích an ninh mạng và rủi ro viễn thông.
Nhiệm vụ của bạn là phân tích đoạn hội thoại dưới đây và xác định xem đây có phải là cuộc gọi lừa đảo (scam) hay không.

[BỐI CẢNH CÁC THỦ ĐOẠN LỪA ĐẢO MỚI NHẤT (2024-2025)]
- Giả danh cơ quan chức năng (Công an, Viện kiểm sát, Tòa án) đe dọa tống tiền hoặc yêu cầu chuyển tiền "tạm giữ".
- Giả danh nhân viên ngân hàng, viễn thông yêu cầu cung cấp mã OTP, số thẻ, mã CVV.
- Lừa đảo "Việc nhẹ lương cao", mời tương tác livestream, làm nhiệm vụ Tiktok/Shopee để nhận hoa hồng.
- Gọi video Deepfake / AI Voice Clone giả danh người thân mượn tiền khẩn cấp.
- Lừa đảo quét mã QR (gửi mã QR qua Zalo/Facebook yêu cầu quét để nhận thưởng hoặc thanh toán).
- Lừa đảo bưu cục/giao hàng (Fake shipper): Thông báo có bưu phẩm bị cấm hoặc phạt nguội giao thông.

TRÍCH ĐOẠN CUỘC GỌI CẦN PHÂN TÍCH:
[START_CALL]
$contextText
[END_CALL]

YÊU CẦU ĐẦU RA:
Bạn PHẢI trả về duy nhất một chuỗi JSON hợp lệ theo đúng cấu trúc dưới đây. KHÔNG sử dụng markdown (không có ```json), KHÔNG thêm văn bản giải thích nào bên ngoài khối JSON.

{
  "reasoning_steps": [
    "Bước 1: Ai đang gọi và họ tự xưng là gì?",
    "Bước 2: Họ có yêu cầu người nghe làm gì (chuyển tiền, đọc OTP, click link, quét QR) không?",
    "Bước 3: Có yếu tố tạo áp lực thời gian, đe dọa, hay dụ dỗ bằng lợi ích tài chính không?",
    "Bước 4: Tổng hợp các yếu tố trên để đưa ra kết luận."
  ],
  "level": "green|yellow|orange|red",
  "label": "Loại lừa đảo (VD: Giả danh công an, Lừa đảo trúng thưởng, Việc nhẹ lương cao...). Để rỗng nếu an toàn.",
  "reason": "Giải thích ngắn gọn lý do vì sao chọn level này (1-2 câu).",
  "recommendation": "Khuyến cáo người dùng nên làm gì tiếp theo (VD: Cúp máy ngay, Không cung cấp thông tin).",
  "confidence_score": 0.95
}

QUY TẮC CẤP ĐỘ (LEVEL):
- green: Cuộc gọi giao tiếp xã hội bình thường, công việc hợp pháp, shipper giao hàng thật sự.
- yellow: Có dấu hiệu hỏi thông tin cá nhân nhưng chưa rõ ràng lừa đảo. Cần lưu ý.
- orange: Nguy cơ lừa đảo cao. Có yêu cầu cài app, quét mã QR, hoặc lôi kéo đầu tư lợi nhuận cao.
- red: Chắc chắn là lừa đảo. Đe dọa pháp lý, yêu cầu chuyển tiền ngay, đòi mã OTP/Mật khẩu.

VÍ DỤ (FEW-SHOT EXAMPLES):

Ví dụ 1 (Lừa đảo Việc nhẹ lương cao - red):
[START_CALL]
Dạ em chào anh, em gọi từ bộ phận CSKH của Shopee. Hiện tại bên em đang có chương trình tri ân khách hàng, chỉ cần anh thả tim các video và tương tác livestream là có thể nhận hoa hồng 300k đến 500k mỗi ngày. Anh cho em kết bạn Zalo để hướng dẫn nhé.
[END_CALL]
{"reasoning_steps":["Người gọi tự xưng là CSKH Shopee mời làm nhiệm vụ.","Yêu cầu thả tim, tương tác livestream để nhận hoa hồng lớn.","Yêu cầu kết bạn Zalo để thao tác tiếp.","Đây là kịch bản điển hình của lừa đảo 'Việc nhẹ lương cao', dẫn dụ nạn nhân nạp tiền làm nhiệm vụ."],"level":"red","label":"Việc nhẹ lương cao","reason":"Dụ dỗ làm nhiệm vụ tương tác nhận hoa hồng cao bất thường và chuyển hướng sang Zalo.","recommendation":"Tuyệt đối không kết bạn Zalo hoặc tham gia nhóm telegram.","confidence_score":0.98}

Ví dụ 2 (Cuộc gọi Shipper bình thường - green):
[START_CALL]
Alo anh ơi, em là shipper của Giao Hàng Tiết Kiệm. Anh có đơn hàng 150k ở tòa nhà Landmark 81, anh xuống sảnh nhận giúp em nhé.
[END_CALL]
{"reasoning_steps":["Người gọi tự xưng là shipper GHTK.","Mục đích là giao đơn hàng với số tiền cụ thể 150k tại địa chỉ cụ thể.","Không có yêu cầu chuyển khoản bất thường hay đe dọa.","Đây là cuộc gọi giao hàng hợp pháp thông thường."],"level":"green","label":"","reason":"Cuộc gọi giao hàng bình thường, thông tin rõ ràng.","recommendation":"Nhận hàng bình thường.","confidence_score":0.99}

Ví dụ 3 (AI Voice Clone mượn tiền - orange):
[START_CALL]
Alo mày à, tao đang cần gấp 50 triệu để cọc tiền lô đất. Mày chuyển ngay vào số tài khoản này cho tao nhé, mạng bên tao đang chập chờn, gọi video nó cứ giật giật.
[END_CALL]
{"reasoning_steps":["Người gọi mượn tiền gấp (50 triệu) với lý do cọc đất.","Tạo áp lực thời gian (chuyển ngay).","Đưa ra lý do mạng chập chờn để tránh việc bị xác minh qua video call.","Dấu hiệu nghi ngờ sử dụng AI Voice clone để lừa đảo vay mượn."],"level":"orange","label":"Giả danh người thân mượn tiền","reason":"Hối thúc chuyển số tiền lớn và viện lý do mạng yếu để tránh video call xác minh.","recommendation":"Gọi điện lại bằng số điện thoại cũ hoặc video call qua app khác để xác minh kỹ.","confidence_score":0.85}

Ví dụ 4 (Lừa đảo QR Code - red):
[START_CALL]
Chào chị, em bên cục thuế. Hiện nay đang có chính sách hoàn thuế thu nhập cá nhân. Em có gửi một mã QR qua Zalo, chị quét mã đó để cài đặt ứng dụng khai báo hoàn thuế nhé.
[END_CALL]
{"reasoning_steps":["Người gọi tự xưng bên Cục Thuế.","Yêu cầu quét mã QR qua Zalo để cài ứng dụng ngoài luồng.","Đây là thủ đoạn phát tán mã độc để chiếm quyền điều khiển điện thoại và tài khoản ngân hàng."],"level":"red","label":"Lừa đảo cài app mã độc","reason":"Giả danh cơ quan nhà nước yêu cầu quét mã QR cài ứng dụng độc hại.","recommendation":"Tuyệt đối không quét mã QR hoặc cài đặt ứng dụng từ nguồn không xác định.","confidence_score":0.97}

Bây giờ, hãy phân tích TRÍCH ĐOẠN CUỘC GỌI CẦN PHÂN TÍCH và chỉ trả về chuỗi JSON hợp lệ.
'''.trim();
  }

  static String buildSummarizationPrompt(String text) {
    final contextText = buildContextWindow(text);
    return '''
Tóm tắt cuộc gọi trong đúng 1-2 câu ngắn gọn, nêu cực kỳ rõ ai gọi và mục đích.

VÍ DỤ 1:
Cuộc gọi: "Em là Tuấn bên ngân hàng Vietcombank, gọi xác nhận anh vừa đăng ký vay 100 triệu."
Tóm tắt: "Nhân viên ngân hàng gọi xác nhận khoản vay 100 triệu."

VÍ DỤ 2:
Cuộc gọi: "Tôi là đại úy công an Trần V, yêu cầu anh tới trụ sở giải quyết án ma túy."
Tóm tắt: "Người xưng là công an yêu cầu đến trụ sở giải quyết án oan."

NỘI DUNG CUỘC GỌI:
"$contextText"

Tóm tắt tiếng Việt:
'''.trim();
  }

  static String buildIncrementalPrompt(String newText, bool isFirstMessage) {
    if (isFirstMessage) {
      return '''
Bạn là chuyên gia phân tích an ninh mạng. Hãy theo dõi và phân tích đoạn hội thoại real-time.

BƯỚC 1 — SUY LUẬN: Xét xem có yêu cầu chuyển tiền, đe dọa, tạo sự cấp bách, xin OTP/app/link, làm nhiệm vụ hoa hồng không.
BƯỚC 2 — KẾT LUẬN: Trả về JSON dựa trên suy luận.

[Đoạn hội thoại]:
"$newText"

BẮT BUỘC TRẢ VỀ CHUỖI JSON HỢP LỆ THEO CẤU TRÚC SAU (không có markdown):
{
  "reasoning_steps": ["suy luận 1", "suy luận 2"],
  "level": "green" hoặc "yellow" hoặc "orange" hoặc "red",
  "label": "Loại lừa đảo (nếu có)",
  "reason": "Giải thích ngắn gọn",
  "recommendation": "Khuyến cáo ngắn gọn",
  "confidence_score": Từ 0.0 đến 1.0
}
'''.trim();
    }
    return '''
[TIẾP TỤC CUỘC GỌI ĐANG PHÂN TÍCH] Văn bản mới: "$newText"
Phân tích bổ sung dựa trên ngữ cảnh cuộc gọi trước đó và cập nhật JSON.
Giữ level = "green" nếu vẫn an toàn, nhưng tăng level nếu phát hiện dấu hiệu lừa đảo mới (VD: đe dọa, dụ dỗ đầu tư, gửi link lạ).

Định dạng JSON bắt buộc (KHÔNG dùng markdown ```json):
{
  "reasoning_steps": ["Cập nhật suy luận dựa trên thông tin mới..."],
  "level": "green|yellow|orange|red",
  "label": "Loại lừa đảo(nếu có)",
  "reason": "Giải thích",
  "recommendation": "Khuyến cáo",
  "confidence_score": 0.0
}
'''.trim();
  }
}
