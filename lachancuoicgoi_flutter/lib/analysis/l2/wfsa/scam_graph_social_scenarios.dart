part of 'scam_graph_builder.dart';

/// Social-impersonation and emotional-manipulation scenarios: kidnap, CEO,
/// deepfake, romance, sextortion, charity, investment, job, lottery,
/// gambling, visa (11 scenarios).
List<ScenarioGraph> _socialScenarios() {
  return <ScenarioGraph>[
    ScamGraphBuilder._linear(
      id: 'G_KIDNAP_01',
      name: 'Bắt cóc ảo',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'KIDNAP_CLAIM',
          'Tuyên bố bắt cóc',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'RANSOM_DEMAND',
          'Đòi tiền chuộc',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'URGENCY_THREAT',
          'Đe dọa khẩn cấp',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'bắt cóc',
          'con bạn',
          'con anh',
          'tính mạng',
          'bị giữ',
          'campuchia',
        ], ScamIntent.virtualKidnapping),
        ScamGraphBuilder._tr(<String>[
          'tiền chuộc',
          'chuộc con',
          'chuộc về',
          'chuyển tiền',
          'giết',
        ], ScamIntent.virtualKidnapping),
        ScamGraphBuilder._tr(<String>[
          'nếu không',
          'không gặp lại',
          'không chuyển',
          'trong 1 tiếng',
          'trong 2 tiếng',
        ], ScamIntent.virtualKidnapping),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_CEO_01',
      name: 'Giả danh lãnh đạo công ty',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'DIRECTOR_INTRO',
          'Giám đốc/Sếp gọi',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'URGENT_TRANSFER',
          'Lệnh chuyển tiền gấp',
          ScamStage.stage3Urgency,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'giám đốc đây',
          'sếp đây',
          'lãnh đạo',
          'phòng nhân sự',
        ], ScamIntent.ceoFraudB2b),
        ScamGraphBuilder._tr(<String>[
          'chuyển khoản cho đối tác',
          'hợp đồng gấp',
          'thanh toán hộ',
          'bí mật',
        ], ScamIntent.ceoFraudB2b),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_DEEPFAKE_01',
      name: 'Deepfake bạn bè mượn tiền',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'FRIEND_INTRO',
          'Bạn bè/người quen gọi',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'LOAN_REQUEST',
          'Mượn tiền gấp',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'TRANSFER_CMD',
          'Yêu cầu chuyển khoản',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'nhờ chút',
          'giúp anh',
          'giúp chị',
          'có chuyện gấp',
        ], ScamIntent.socialDeepfakeLoan),
        ScamGraphBuilder._tr(<String>[
          'mượn tiền',
          'chuyển đỡ',
          'cần gấp',
          'tối trả',
          'mai trả',
        ], ScamIntent.socialDeepfakeLoan),
        ScamGraphBuilder._tr(<String>[
          'số tài khoản',
          'chuyển khoản',
          'chuyển vào',
          'stk',
        ], ScamIntent.bankCardFraud),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_ROMANCE_01',
      name: 'Lừa tình/Bưu kiện hải quan',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'GIFT_CLAIM',
          'Gửi quà tặng đắt tiền',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'CUSTOMS_FEE',
          'Nộp phí hải quan',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'gửi quà',
          'bưu kiện',
          'nước ngoài',
          'quân nhân',
          'tình cảm',
        ], ScamIntent.romanceScam),
        ScamGraphBuilder._tr(<String>[
          'phí hải quan',
          'thuế nhập khẩu',
          'kẹt ở sân bay',
          'đóng tiền',
        ], ScamIntent.romanceScam),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_SEXTORT_01',
      name: 'Tống tiền bằng ảnh/clip nhạy cảm',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'EVIDENCE_CLAIM',
          'Tuyên bố có bằng chứng',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'SPREAD_THREAT',
          'Dọa phát tán',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'RANSOM_CMD',
          'Đòi tiền im lặng',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'ảnh nóng',
          'clip nhạy cảm',
          'video nhạy cảm',
          'lộ clip',
        ], ScamIntent.sextortionBlackmail),
        ScamGraphBuilder._tr(<String>[
          'phát tán',
          'tung lên mạng',
          'gửi cho người thân',
          'bạn bè sẽ thấy',
        ], ScamIntent.sextortionBlackmail),
        ScamGraphBuilder._tr(<String>[
          'chuyển tiền',
          'tống tiền',
          'im lặng',
          'xóa clip',
        ], ScamIntent.sextortionBlackmail),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_CHARITY_01',
      name: 'Kêu gọi từ thiện giả',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'CHARITY_INTRO',
          'Kêu gọi từ thiện',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'PRESSURE_DONATE',
          'Thúc ép quyên góp gấp',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'PERSONAL_ACCOUNT',
          'Chuyển khoản qua STK cá nhân',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'quyên góp',
          'từ thiện',
          'giúp đỡ',
          'hoàn cảnh',
          'bão lũ',
        ], ScamIntent.charityDonation),
        ScamGraphBuilder._tr(<String>[
          'sắp hết hạn',
          'cần ngay',
          'bé đang chờ mổ',
          'thương lắm',
        ], ScamIntent.charityDonation),
        ScamGraphBuilder._tr(<String>[
          'số tài khoản cá nhân',
          'chuyển vào stk',
          'zalo pay',
          'momo',
        ], ScamIntent.charityDonation),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_INVEST_01',
      name: 'Lừa đầu tư tiền ảo',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'INVEST_INTRO',
          'Giới thiệu cơ hội đầu tư',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'PROFIT_BAIT',
          'Hứa hẹn lợi nhuận cao',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'DEPOSIT_CMD',
          'Yêu cầu nạp tiền',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'đầu tư',
          'chứng khoán',
          'crypto',
          'forex',
          'sàn giao dịch',
          'bitcoin',
        ], ScamIntent.investmentScam),
        ScamGraphBuilder._tr(<String>[
          'lợi nhuận',
          'cam kết',
          'x2',
          'gấp đôi',
          'sinh lời',
          'không rủi ro',
        ], ScamIntent.investmentScam),
        ScamGraphBuilder._tr(<String>[
          'nạp tiền',
          'chuyển vào',
          'nâng vốn',
          'kéo lệnh',
          'rút về',
        ], ScamIntent.investmentScam),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_JOB_01',
      name: 'Tuyển CTV kiếm hoa hồng',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'JOB_INTRO',
          'Tuyển cộng tác viên',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'TASK_BAIT',
          'Giao nhiệm vụ dễ',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'DEPOSIT_TRAP',
          'Yêu cầu đặt cọc',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'tuyển cộng tác viên',
          'việc làm',
          'kiếm thêm',
          'thu nhập',
          'online',
        ], ScamIntent.jobTaskScam),
        ScamGraphBuilder._tr(<String>[
          'nhiệm vụ',
          'chốt đơn',
          'like video',
          'đánh giá sản phẩm',
          'hoa hồng',
        ], ScamIntent.jobTaskScam),
        ScamGraphBuilder._tr(<String>[
          'đặt cọc',
          'nạp tiền',
          'phí kích hoạt',
          'nâng cấp tài khoản',
        ], ScamIntent.jobTaskScam),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_LOTTERY_01',
      name: 'Trúng thưởng tri ân',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'WINNER_INTRO',
          'Thông báo trúng thưởng',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'PROC_FEE',
          'Yêu cầu đóng phí nhận giải',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'trúng thưởng',
          'giải nhất',
          'xe sh',
          'tri ân',
          'quà tặng',
        ], ScamIntent.giftLottery),
        ScamGraphBuilder._tr(<String>[
          'phí làm hồ sơ',
          'đóng thuế',
          'mã nhận quà',
          'chuyển khoản phí',
        ], ScamIntent.giftLottery),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_GAMBLE_01',
      name: 'Soi cầu lô đề',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'TIP_BAIT',
          'Cung cấp số chuẩn',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'WINNING_PROOF',
          'Chứng minh chiến thắng giả',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'DEPOSIT_TRAP',
          'Ép nạp tiền đánh đề',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'PLATFORM_MOVE',
          'Chuyển vào sàn/app',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'soi cầu',
          'lô đề',
          'bạch thủ',
          'số chuẩn',
          'về bờ',
        ], ScamIntent.gamblingPrediction),
        ScamGraphBuilder._tr(<String>[
          'trúng rồi',
          'ăn lớn',
          'chiến thắng',
          'chứng minh',
          'hôm qua trúng',
        ], ScamIntent.gamblingPrediction),
        ScamGraphBuilder._tr(<String>[
          'nạp tiền',
          'cọc trước',
          'mua số',
          'phí phần mềm',
        ], ScamIntent.gamblingPrediction),
        ScamGraphBuilder._tr(<String>[
          'vào app',
          'tải ứng dụng',
          'đăng ký tài khoản',
          'sàn cá cược',
        ], ScamIntent.gamblingPrediction),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_VISA_01',
      name: 'Visa/Xuất khẩu lao động',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'VISA_BAIT',
          'Bao đậu Visa/XKLĐ',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'PROMISE_JOB',
          'Hứa lương cao, cam kết',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'DEPOSIT_VISA',
          'Đặt cọc phí visa/XKLĐ',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'MONEY_ABROAD',
          'Chuyển tiền ra nước ngoài',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'visa',
          'xuất khẩu lao động',
          'đi hàn quốc',
          'bao đậu',
          'đi nhật',
        ], ScamIntent.immigrationVisaScam),
        ScamGraphBuilder._tr(<String>[
          'lương cao',
          'cam kết',
          'đảm bảo',
          'công ty phái cử',
          'hợp đồng',
        ], ScamIntent.immigrationVisaScam),
        ScamGraphBuilder._tr(<String>[
          'đặt cọc',
          'phí hồ sơ',
          'phí visa',
          'chuyển trước',
        ], ScamIntent.immigrationVisaScam),
        ScamGraphBuilder._tr(<String>[
          'chuyển tiền',
          'western union',
          'tài khoản nước ngoài',
          'phí bổ sung',
        ], ScamIntent.immigrationVisaScam),
      ],
    ),
  ];
}
