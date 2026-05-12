import '../../../core/risk_level.dart';

enum ScamIntent {
  authPoliceLawsuit,
  taxGovApp,
  telecomLock,
  techSupportHijack,
  hospitalEmergency,
  virtualKidnapping,
  ceoFraudB2b,
  socialDeepfakeLoan,
  romanceScam,
  sextortionBlackmail,
  charityDonation,
  investmentScam,
  jobTaskScam,
  giftLottery,
  gamblingPrediction,
  immigrationVisaScam,
  bankCardFraud,
  deliveryCod,
  fakeSubscription,
  blackCreditTerror,
  recoveryScam,
  genericScam,
  safe,
}

class IntentPrediction {
  const IntentPrediction({required this.intent, required this.confidence});

  final ScamIntent intent;
  final double confidence;
}

extension ScamIntentExtensions on ScamIntent {
  String get displayName {
    return switch (this) {
      ScamIntent.authPoliceLawsuit => 'Giả danh Công an/Tòa án',
      ScamIntent.taxGovApp => 'Lừa đảo Thuế/VNeID giả',
      ScamIntent.telecomLock => 'Dọa khóa SIM viễn thông',
      ScamIntent.techSupportHijack => 'Hỗ trợ kỹ thuật giả mạo',
      ScamIntent.hospitalEmergency => 'Cấp cứu/Tai nạn giả',
      ScamIntent.virtualKidnapping => 'Bắt cóc ảo/Tống tiền',
      ScamIntent.ceoFraudB2b => 'Giả danh Lãnh đạo/Đồng nghiệp',
      ScamIntent.socialDeepfakeLoan => 'Deepfake mượn tiền (Người quen)',
      ScamIntent.romanceScam => 'Lừa tình/Bưu kiện hải quan',
      ScamIntent.sextortionBlackmail => 'Tống tiền ảnh nhạy cảm',
      ScamIntent.charityDonation => 'Từ thiện ảo/Kêu góp giả',
      ScamIntent.investmentScam => 'Đầu tư tài chính/Sàn ảo',
      ScamIntent.jobTaskScam => 'Việc làm online/Chốt đơn',
      ScamIntent.giftLottery => 'Trúng thưởng/Quà tặng tri ân',
      ScamIntent.gamblingPrediction => 'Soi cầu/Lô đề',
      ScamIntent.immigrationVisaScam => 'Visa/Xuất khẩu lao động',
      ScamIntent.bankCardFraud => 'Ngân hàng giả mạo/Phishing',
      ScamIntent.deliveryCod => 'Shipper giả/Nợ tiền hàng',
      ScamIntent.fakeSubscription => 'Trừ tiền dịch vụ tự động',
      ScamIntent.blackCreditTerror => 'Tín dụng đen/Đòi nợ thuê',
      ScamIntent.recoveryScam => 'Dịch vụ lấy lại tiền bị lừa',
      ScamIntent.genericScam => 'Dấu hiệu lừa đảo chung',
      ScamIntent.safe => 'Giao tiếp bình thường',
    };
  }

  String get description {
    return switch (this) {
      ScamIntent.authPoliceLawsuit =>
        'Đối tượng giả danh cơ quan pháp luật để đe dọa và yêu cầu chuyển tiền điều tra.',
      ScamIntent.taxGovApp =>
        'Yêu cầu cài đặt ứng dụng giả mạo (VNeID, Thuế) để chiếm quyền điều khiển điện thoại.',
      ScamIntent.telecomLock =>
        'Dọa khóa SIM để ép buộc cung cấp thông tin cá nhân hoặc làm theo hướng dẫn.',
      ScamIntent.techSupportHijack =>
        'Giả danh nhân viên hỗ trợ Zalo/FB để lừa lấy mã OTP hoặc quyền truy cập tài khoản.',
      ScamIntent.hospitalEmergency =>
        'Đánh vào tâm lý lo lắng cho người thân gặp nạn để yêu cầu chuyển tiền viện phí gấp.',
      ScamIntent.virtualKidnapping =>
        'Tạo hiện trường bắt cóc giả để tống tiền người thân trong tình trạng hoảng loạn.',
      ScamIntent.ceoFraudB2b =>
        'Mạo danh cấp trên yêu cầu chuyển khoản khẩn cấp cho đối tác hoặc công việc.',
      ScamIntent.socialDeepfakeLoan =>
        'Sử dụng công nghệ AI giả giọng nói/hình ảnh người quen để vay tiền kẹt.',
      ScamIntent.romanceScam =>
        'Tán tỉnh qua mạng rồi nhờ thanh toán phí vận chuyển quà tặng giá trị cao bị kẹt.',
      ScamIntent.sextortionBlackmail =>
        'Sử dụng hình ảnh nhạy cảm (cắt ghép hoặc thật) để uy hiếp đòi tiền.',
      ScamIntent.charityDonation =>
        'Lợi dụng lòng tốt để kêu gọi ủng hộ các hoàn cảnh khó khăn không có thật.',
      ScamIntent.investmentScam =>
        'Hứa hẹn lợi nhuận cực cao từ sàn chứng khoán, tiền ảo nhằm chiếm đoạt vốn nạp.',
      ScamIntent.jobTaskScam =>
        'Mồi chài việc nhẹ lương cao, yêu cầu nạp tiền chốt đơn để nhận hoa hồng ảo.',
      ScamIntent.giftLottery =>
        'Thông báo trúng thưởng lớn và yêu cầu đóng phí trước khi nhận giải.',
      ScamIntent.gamblingPrediction =>
        "Gạ gẫm mua số lô đề 'chuẩn' hoặc tham gia đánh bạc trực tuyến.",
      ScamIntent.immigrationVisaScam =>
        'Cam kết bao đậu visa hoặc đi lao động nước ngoài với chi phí rẻ bất ngờ.',
      ScamIntent.bankCardFraud =>
        'Gửi link giả mạo ngân hàng yêu cầu nhập mật khẩu và OTP để đánh cắp tiền.',
      ScamIntent.deliveryCod =>
        'Giả shipper giao hàng chưa đặt hoặc yêu cầu thanh toán lại đơn đã trả tiền.',
      ScamIntent.fakeSubscription =>
        'Thông báo bạn đang bị trừ tiền dịch vụ lạ và dụ dỗ click link để hủy.',
      ScamIntent.blackCreditTerror =>
        'Đòi nợ với thái độ hung hãn, đe dọa khủng bố tinh thần bạn và người thân.',
      ScamIntent.recoveryScam =>
        'Giả danh luật sư/công an hứa hẹn lấy lại tiền đã bị lừa để lừa thêm lần nữa.',
      ScamIntent.genericScam =>
        'Sử dụng các thủ đoạn kịch bản chưa rõ ràng nhưng có dấu hiệu lừa đảo cao.',
      ScamIntent.safe =>
        'Nội dung cuộc trò chuyện bình thường, không thấy dấu hiệu rủi ro.',
    };
  }

  RiskLevel get baseRiskLevel {
    return switch (this) {
      ScamIntent.safe => RiskLevel.green,
      ScamIntent.charityDonation ||
      ScamIntent.giftLottery ||
      ScamIntent.fakeSubscription ||
      ScamIntent.genericScam => RiskLevel.yellow,
      ScamIntent.investmentScam ||
      ScamIntent.jobTaskScam ||
      ScamIntent.romanceScam ||
      ScamIntent.immigrationVisaScam ||
      ScamIntent.deliveryCod ||
      ScamIntent.recoveryScam ||
      ScamIntent.gamblingPrediction ||
      ScamIntent.ceoFraudB2b ||
      ScamIntent.socialDeepfakeLoan => RiskLevel.orange,
      ScamIntent.authPoliceLawsuit ||
      ScamIntent.taxGovApp ||
      ScamIntent.telecomLock ||
      ScamIntent.techSupportHijack ||
      ScamIntent.hospitalEmergency ||
      ScamIntent.virtualKidnapping ||
      ScamIntent.sextortionBlackmail ||
      ScamIntent.bankCardFraud ||
      ScamIntent.blackCreditTerror => RiskLevel.red,
    };
  }

  RiskLevel riskLevelForConfidence(double confidence) {
    final base = baseRiskLevel;
    if (this == ScamIntent.safe || confidence >= 0.85) return base;
    if (confidence >= 0.70) return base;
    if (confidence >= 0.50) return base.deescalate();
    final twiceDeescalated = base.deescalate().deescalate();
    return twiceDeescalated.index < RiskLevel.yellow.index
        ? RiskLevel.yellow
        : twiceDeescalated;
  }
}

const intentLabels = <ScamIntent>[
  ScamIntent.authPoliceLawsuit,
  ScamIntent.taxGovApp,
  ScamIntent.telecomLock,
  ScamIntent.techSupportHijack,
  ScamIntent.hospitalEmergency,
  ScamIntent.virtualKidnapping,
  ScamIntent.ceoFraudB2b,
  ScamIntent.socialDeepfakeLoan,
  ScamIntent.romanceScam,
  ScamIntent.sextortionBlackmail,
  ScamIntent.charityDonation,
  ScamIntent.investmentScam,
  ScamIntent.jobTaskScam,
  ScamIntent.giftLottery,
  ScamIntent.gamblingPrediction,
  ScamIntent.immigrationVisaScam,
  ScamIntent.bankCardFraud,
  ScamIntent.deliveryCod,
  ScamIntent.fakeSubscription,
  ScamIntent.blackCreditTerror,
  ScamIntent.recoveryScam,
  ScamIntent.genericScam,
  ScamIntent.safe,
];
