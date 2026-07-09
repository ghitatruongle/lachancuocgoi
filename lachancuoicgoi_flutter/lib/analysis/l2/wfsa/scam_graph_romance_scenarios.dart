part of 'scam_graph_builder.dart';

/// Romance scam scenarios: dating app, gift card, "đầu tư cùng nhau",
/// "khẩn cấp gửi tiền", "passport bị giữ", hải quan (6 scenarios).
///
/// Wave 6 addition: 2026-06-30. Feature-flagged in analysis_config.
/// Conservative threshold: ≥3 keyword + WFSA terminal required.
List<ScenarioGraph> _romanceScenarios() {
  return <ScenarioGraph>[
    ScamGraphBuilder._linear(
      id: 'ROM_DATING_01',
      name: 'Lừa tình qua mạng xã hội',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'FLIRT_START',
          'Tán tỉnh làm quen',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'TRUST_BUILD',
          'Xây dựng lòng tin',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'MONEY_ASK',
          'Yêu cầu chuyển tiền',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'anh yêu em',
          'mình cưới nhau nhé',
          'em là người đặc biệt',
          'tương lai chúng ta',
          'anh muốn gặp em',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'hoàn cảnh khó khăn',
          'cần tiền chữa bệnh',
          'mẹ ốm nặng',
          'tai nạn giao thông',
          'thiếu tiền trả nợ',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'chuyển khoản giúp anh',
          'gửi tiền qua western union',
          'mua thẻ cào gửi',
          'nạp tiền vào tài khoản',
          'cho anh vay',
        ], ScamIntent.romanceScam),
      ],
    ),

    ScamGraphBuilder._linear(
      id: 'ROM_GIFT_01',
      name: 'Quà tặng kẹt hải quan',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'GIFT_ANNOUNCE',
          'Thông báo gửi quà',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'CUSTOMS_BLOCK',
          'Hải quan giữ hàng',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'FEE_DEMAND',
          'Yêu cầu đóng phí hải quan',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'gửi quà cho em',
          'bưu kiện quốc tế',
          'hàng hóa giá trị cao',
          'quà tặng bất ngờ',
          'món quà đặc biệt',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'hải quan giữ',
          'bưu điện yêu cầu',
          'kiện hàng bị tịch thu',
          'cần xác minh',
          'thông quan',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'phí hải quan',
          'tiền phạt',
          'phí vận chuyển',
          'tiền thuế nhập khẩu',
          'chuyển khoản phí',
        ], ScamIntent.romanceScam),
      ],
    ),

    ScamGraphBuilder._linear(
      id: 'ROM_INVEST_01',
      name: 'Đầu tư cùng nhau',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'INVEST_OFFER',
          'Rủ rê đầu tư chung',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'PROOF_SHOW',
          'Cho xem lợi nhuận',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'JOIN_DEMAND',
          'Yêu cầu tham gia',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'đầu tư cùng anh',
          'kiếm tiền cùng nhau',
          'tương lai tài chính',
          'xây dựng cuộc sống',
          'ổn định tài chính',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'anh đã kiếm được',
          'xem tài khoản của anh',
          'lợi nhuận thực tế',
          'bạn gái anh đã đầu tư',
          'không lỗ đâu',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'nạp tiền vào sàn',
          'mở tài khoản',
          'chuyển khoản đầu tư',
          'bắt đầu với số nhỏ',
          'đặt cọc',
        ], ScamIntent.romanceScam),
      ],
    ),

    ScamGraphBuilder._linear(
      id: 'ROM_EMERGENCY_01',
      name: 'Khẩn cấp gửi tiền',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'CRISIS_REPORT',
          'Báo cáo tình trạng khẩn cấp',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'URGENT_NEED',
          'Cần tiền gấp',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'SEND_NOW',
          'Gửi tiền ngay',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'tai nạn',
          'cấp cứu',
          'nhập viện',
          'phẫu thuật',
          'đang ở bệnh viện',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'cần tiền gấp',
          'không có ai giúp',
          'em là hy vọng cuối cùng',
          'chuyển khoản ngay',
          'gửi tiền trong hôm nay',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'chuyển khoản',
          'western union',
          'moneygram',
          'gửi tiền mặt',
          'mua thẻ cào',
        ], ScamIntent.romanceScam),
      ],
    ),

    ScamGraphBuilder._linear(
      id: 'ROM_PASSPORT_01',
      name: 'Passport bị giữ',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'TRAVEL_STORY',
          'Kể chuyện đi du lịch',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'PASSPORT_LOST',
          'Passport bị tịch thu',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'RANSOM_DEMAND',
          'Yêu cầu tiền chuộc',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'đang ở nước ngoài',
          'du lịch',
          'công tác',
          'sân bay',
          'nhà ga',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'passport bị giữ',
          'hộ chiếu bị tịch thu',
          'cảnh sát bắt',
          'bị giam',
          'không về được',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'tiền chuộc',
          'phí bảo lãnh',
          'tiền phạt',
          'chuyển khoản ngay',
          'gửi tiền qua đại sứ quán',
        ], ScamIntent.romanceScam),
      ],
    ),

    ScamGraphBuilder._linear(
      id: 'ROM_CUSTOMS_01',
      name: 'Bưu kiện hải quan (loại 2)',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'PACKAGE_NOTICE',
          'Thông báo có bưu kiện',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'CUSTOMS_ISSUE',
          'Vấn đề hải quan',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'PAY_FEE',
          'Thanh toán phí',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'bưu điện gọi',
          'có bưu kiện',
          'gói hàng quốc tế',
          'chuyển phát nhanh',
          'fedex',
          'dhl',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'hải quan sân bay',
          'kiểm tra an ninh',
          'phát hiện hàng cấm',
          'cần xác minh nguồn gốc',
          'tạm giữ hàng',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'phí xử lý',
          'phí hải quan',
          'tiền phạt',
          'phí vận chuyển bổ sung',
          'chuyển khoản',
        ], ScamIntent.romanceScam),
      ],
    ),
  ];
}
