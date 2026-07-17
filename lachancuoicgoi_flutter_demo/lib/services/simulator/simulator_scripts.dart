/// Catalog kịch bản giả lập cho simulator bridge (iOS/Desktop/Web).
///
/// Mỗi kịch bản là một chuỗi câu thoại để feed vào analysis pipeline,
/// thay thế cho STT thật (không có trên non-Android). Các kịch bản được
/// mô phỏng theo các dạng lừa đảo phổ biến tại Việt Nam.
class SimulatorScript {
  const SimulatorScript({
    required this.id,
    required this.title,
    required this.lines,
  });

  /// Unique identifier for this scenario.
  final String id;

  /// Human-readable title (Vietnamese) for UI display.
  final String title;

  /// Ordered list of scam dialogue lines fed to the analysis engine.
  final List<String> lines;
}

class SimulatorScriptCatalog {
  const SimulatorScriptCatalog._();

  static const taxAuthority = SimulatorScript(
    id: 'tax_authority',
    title: 'Giả mạo cơ quan thuế',
    lines: [
      'Xin chào ông, tôi là cán bộ thuế thuộc cơ quan thuế quận.',
      'Theo hệ thống, ông đang nợ thuế 50 triệu đồng từ năm ngoái.',
      'Nếu không nộp ngay trong 10 phút, tài khoản ngân hàng sẽ bị phong tỏa.',
      'Hãy chuyển số tiền nợ về tài khoản tạm giữ của cơ quan thuế ngay.',
    ],
  );

  static const bankFraud = SimulatorScript(
    id: 'bank_fraud',
    title: 'Lừa đảo ngân hàng',
    lines: [
      'Xin chào ông, tôi là nhân viên ngân hàng.',
      'Tài khoản ngân hàng của ông đang bị nghi ngờ liên quan rửa tiền.',
      'Ông cần chuyển toàn bộ số dư sang tài khoản an toàn của chúng tôi.',
      'Hãy đọc mã OTP vừa gửi đến điện thoại để hoàn tất xác minh.',
    ],
  );

  static const prize = SimulatorScript(
    id: 'prize',
    title: 'Trúng thưởng ảo',
    lines: [
      'Chúc mừng ông đã trúng thưởng 200 triệu đồng từ chương trình tri ân.',
      'Ông chỉ cần đóng phí xử lý 2 triệu để nhận giải.',
      'Đưa tôi mã thẻ cào điện thoại để tôi nạp phí giúp ông.',
      'Nếu không đóng phí trong 5 phút, giải thưởng sẽ chuyển cho người khác.',
    ],
  );

  /// All available scenarios in display order.
  static const List<SimulatorScript> all = [taxAuthority, bankFraud, prize];

  /// Look up a script by [id]. Returns `null` if not found.
  static SimulatorScript? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
