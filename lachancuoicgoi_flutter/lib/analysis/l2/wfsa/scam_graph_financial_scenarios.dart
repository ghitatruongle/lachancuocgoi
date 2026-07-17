part of 'scam_graph_builder.dart';

/// Financial and miscellaneous scenarios: bank, shipper, subscription, black
/// credit, recovery, generic, ecommerce, crypto (8 scenarios).
List<ScenarioGraph> _financialScenarios() {
  return <ScenarioGraph>[
    ScamGraphBuilder._linear(
      id: 'G_BANK_01',
      name: 'Khóa tài khoản khẩn cấp',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'BANK_INTRO',
          'Nhân viên ngân hàng',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'LOGIN_THREAT',
          'Đăng nhập bất thường',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'VERIFY_URGENT',
          'Xác thực ngay theo tin nhắn',
          ScamStage.stage3Urgency,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'nhân viên ngân hàng',
          'tổng đài hỗ trợ',
          'trung tâm thẻ',
        ], ScamIntent.bankCardFraud),
        ScamGraphBuilder._tr(<String>[
          'đăng nhập lạ',
          'khóa tài khoản',
          'giao dịch bất thường',
          'trừ tiền',
        ], ScamIntent.bankCardFraud),
        ScamGraphBuilder._tr(<String>[
          'đọc mã otp',
          'mã xác thực',
          'tin nhắn gửi về',
        ], ScamIntent.bankCardFraud),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_SHIP_01',
      name: 'Shipper giả/Giao hàng nợ',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'SHIPPER_INTRO',
          'Giao hàng COD',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'PAY_TRAP',
          'Thanh toán nợ cũ',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'shipper',
          'giao hàng',
          'đơn hàng',
          'thanh toán cod',
        ], ScamIntent.deliveryCod),
        ScamGraphBuilder._tr(<String>[
          'nợ tiền hàng',
          'chuyển khoản trước',
          'đã đặt',
        ], ScamIntent.deliveryCod),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_SUB_01',
      name: 'Trừ tiền dịch vụ ảo',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'SUB_THREAT',
          'Thông báo trừ phí dịch vụ',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'CANCEL_URGENCY',
          'Hủy gấp trước khi bị trừ thêm',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'CLICK_LINK',
          'Yêu cầu click link hủy dịch vụ',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'CARD_STEAL',
          'Nhập thông tin thẻ/OTP',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'trừ tiền',
          'gia hạn',
          'dịch vụ',
          'đăng ký',
          'gói vip',
        ], ScamIntent.fakeSubscription),
        ScamGraphBuilder._tr(<String>[
          'hủy ngay',
          'trước khi bị trừ',
          'tự động gia hạn',
          'mất tiền',
        ], ScamIntent.fakeSubscription),
        ScamGraphBuilder._tr(<String>[
          'bấm vào link',
          'truy cập link',
          'hủy tại đây',
          'vào trang web',
        ], ScamIntent.fakeSubscription),
        ScamGraphBuilder._tr(<String>[
          'số thẻ',
          'nhập mã otp',
          'mật khẩu',
          'xác nhận thẻ',
        ], ScamIntent.bankCardFraud),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_CREDIT_01',
      name: 'Tín dụng đen khủng bố đòi nợ',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'DEBT_CLAIM',
          'Thông báo nợ',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'TERROR_THREAT',
          'Đe dọa khủng bố',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'PAY_CMD',
          'Ép trả tiền ngay',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'khoản vay',
          'app vay',
          'tín dụng đen',
        ], ScamIntent.blackCreditTerror),
        ScamGraphBuilder._tr(<String>[
          'đòi nợ',
          'chửi bới',
          'gọi danh bạ',
          'tung lên mạng',
          'khủng bố',
        ], ScamIntent.blackCreditTerror),
        ScamGraphBuilder._tr(<String>[
          'trả ngay',
          'chuyển tiền',
          'nộp phí',
          'phí phạt',
        ], ScamIntent.blackCreditTerror),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_RECOVERY_01',
      name: 'Dịch vụ lấy lại tiền lừa đảo',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'RECOVERY_BAIT',
          'Hứa lấy lại tiền',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'PROVE_LEGIT',
          'Chứng minh khả năng thu hồi',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'DEPOSIT_FEE',
          'Đặt cọc phí hỗ trợ',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'BANKING_ACCESS',
          'Yêu cầu cung cấp app banking',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'lấy lại tiền',
          'thu hồi',
          'luật sư',
          'cảnh sát mạng',
          'hỗ trợ nạn nhân',
        ], ScamIntent.recoveryScam),
        ScamGraphBuilder._tr(<String>[
          'đã thu hồi',
          'thành công',
          'chuyên xử lý',
          'có bằng chứng',
        ], ScamIntent.recoveryScam),
        ScamGraphBuilder._tr(<String>[
          'đặt cọc',
          'phí hỗ trợ',
          'phí luật sư',
          'chuyển phí trước',
        ], ScamIntent.recoveryScam),
        ScamGraphBuilder._tr(<String>[
          'đăng nhập banking',
          'cung cấp tài khoản',
          'chia sẻ màn hình',
          'mã otp',
        ], ScamIntent.bankCardFraud),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_GENERIC_01',
      name: 'Lừa đảo không rõ kịch bản',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'SUSPICIOUS_BAIT',
          'Dấu hiệu nghi vấn',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'TRUST_BUILD',
          'Tạo niềm tin giả',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'MONEY_REQUEST',
          'Yêu cầu chuyển tiền',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'URGENCY_FORCE',
          'Ép buộc khẩn cấp',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'nghe đây',
          'có chuyện này',
          'ưu đãi',
          'bí mật',
        ], ScamIntent.genericScam),
        ScamGraphBuilder._tr(<String>[
          'tin tôi đi',
          'cam kết',
          'đảm bảo',
          'có người giới thiệu',
        ], ScamIntent.genericScam),
        ScamGraphBuilder._tr(<String>[
          'chuyển tiền',
          'nạp tiền',
          'đặt cọc',
          'thanh toán',
        ], ScamIntent.genericScam),
        ScamGraphBuilder._tr(<String>[
          'ngay bây giờ',
          'trong vòng',
          'hết hạn',
          'mất cơ hội',
        ], ScamIntent.genericScam),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_ECOMMERCE_01',
      name: 'Shop giả/Thanh toán khống',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'PRODUCT_BAIT',
          'Quảng cáo hàng giá rẻ/sale sốc',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'PAYMENT_URGENCY',
          'Ép thanh toán gấp, chỉ còn vài suất',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'TRANSFER_REQUEST',
          'Yêu cầu chuyển khoản trước khi giao hàng',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'EXTRA_FEE',
          'Phát sinh phí/thuế yêu cầu chuyển thêm',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'sale sốc',
          'giảm giá',
          'hàng xách tay',
          'giá gốc',
          'flash sale',
        ], ScamIntent.fakeEcommerce),
        ScamGraphBuilder._tr(<String>[
          'chuyển khoản trước',
          'thanh toán trước',
          'cọc trước',
          'đặt cọc',
          'giữ đơn',
        ], ScamIntent.fakeEcommerce),
        ScamGraphBuilder._tr(<String>[
          'chuyển tiền',
          'số tài khoản',
          'nội dung chuyển khoản',
          'chốt đơn',
        ], ScamIntent.fakeEcommerce),
        ScamGraphBuilder._tr(<String>[
          'phí hải quan',
          'thuế nhập khẩu',
          'phí phát sinh',
          'chuyển thêm',
        ], ScamIntent.fakeEcommerce),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_CRYPTO_01',
      name: 'Ví crypto/Sàn ảo rút tiền',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'INVESTMENT_BAIT',
          'Giới thiệu sàn crypto/lợi nhuận cao',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'WALLET_SETUP',
          'Hướng dẫn cài ví/tạo tài khoản',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'DEPOSIT_PRESSURE',
          'Ép nạp tiền vào sàn',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'DRAIN_WALLET',
          'Rút hết tiền/yêu cầu nạp thêm để rút',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'sàn crypto',
          'tiền ảo',
          'bitcoin',
          'lợi nhuận',
          'đầu tư online',
        ], ScamIntent.cryptoDrain),
        ScamGraphBuilder._tr(<String>[
          'cài ví',
          'tạo tài khoản',
          'đăng ký sàn',
          'meta mask',
          'trust wallet',
        ], ScamIntent.cryptoDrain),
        ScamGraphBuilder._tr(<String>[
          'nạp tiền',
          'chuyển vào ví',
          'mua coin',
          'nạp usdt',
          'deposit',
        ], ScamIntent.cryptoDrain),
        ScamGraphBuilder._tr(<String>[
          'rút tiền',
          'phí rút',
          'nạp thêm để rút',
          'đóng thuế rút',
          'unlock ví',
        ], ScamIntent.cryptoDrain),
      ],
    ),
  ];
}
