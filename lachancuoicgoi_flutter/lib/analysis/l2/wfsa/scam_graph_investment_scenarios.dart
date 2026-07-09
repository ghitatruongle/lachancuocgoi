part of 'scam_graph_builder.dart';

/// Investment scam scenarios: forex, crypto, MLM, "việc nhẹ lương cao",
/// stock, ICO/IDO, skincare MLM, Ponzi (8 scenarios).
///
/// Wave 6 addition: 2026-06-30. Feature-flagged in analysis_config.
/// Conservative threshold: ≥3 keyword + WFSA terminal required.
List<ScenarioGraph> _investmentScenarios() {
  return <ScenarioGraph>[
    ScamGraphBuilder._linear(
      id: 'INV_FOREX_01',
      name: 'Sàn Forex lừa đảo',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'FOREX_INVITE',
          'Lời mời đầu tư Forex',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'PROFIT_PROMISE',
          'Hứa hẹn lợi nhuận cao',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'DEPOSIT_DEMAND',
          'Yêu cầu nạp tiền',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'đầu tư forex',
          'sàn forex',
          'giao dịch ngoại hối',
          'forex uy tín',
          'kiếm tiền forex',
        ], ScamIntent.investmentScam),
        ScamGraphBuilder._tr(<String>[
          'lợi nhuận cao',
          'lãi suất khủng',
          'kiếm tiền triệu mỗi ngày',
          'lợi nhuận lên đến',
          'cam kết lợi nhuận',
        ], ScamIntent.investmentScam),
        ScamGraphBuilder._tr(<String>[
          'nạp tiền vào sàn',
          'chuyển khoản đầu tư',
          'mở tài khoản giao dịch',
          'đặt cọc',
          'vốn tối thiểu',
        ], ScamIntent.investmentScam),
      ],
    ),

    ScamGraphBuilder._linear(
      id: 'INV_CRYPTO_01',
      name: 'Sàn crypto ảo',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'CRYPTO_INVITE',
          'Lời mời trade crypto',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'FAKE_PROFIT',
          'Hiện lợi nhuận ảo',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'WITHDRAW_TRAP',
          'Rút tiền không được',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'đầu tư bitcoin',
          'trade coin',
          'sàn binance',
          'sàn crypto',
          'tiền ảo',
          'đào coin',
        ], ScamIntent.cryptoDrain),
        ScamGraphBuilder._tr(<String>[
          'lãi kép',
          'compound interest',
          'tài khoản tăng gấp đôi',
          'bảo toàn vốn',
          'profit garantie',
        ], ScamIntent.cryptoDrain),
        ScamGraphBuilder._tr(<String>[
          'rút tiền',
          'nạp thêm để rút',
          'đóng thuế trước khi rút',
          'phí giao dịch',
          'xác minh tài khoản',
        ], ScamIntent.cryptoDrain),
      ],
    ),

    ScamGraphBuilder._linear(
      id: 'INV_MLM_01',
      name: 'MLM/Đa cấp biến tướng',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'MLM_INVITE',
          'Lời mời tham gia hệ thống',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'TEAM_BUILD',
          'Xây dựng hệ thống',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'RECRUIT_DEMAND',
          'Yêu cầu tuyển người',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'kinh doanh đa cấp',
          'bán hàng đa cấp',
          'mlm',
          'network marketing',
          'hệ thống phân phối',
        ], ScamIntent.investmentScam),
        ScamGraphBuilder._tr(<String>[
          'thu nhập thụ động',
          'hoa hồng hệ thống',
          'cấp dưới',
          'doanh số nhóm',
          'phát triển mạng lưới',
        ], ScamIntent.investmentScam),
        ScamGraphBuilder._tr(<String>[
          'mua hàng gia nhập',
          'phí tham gia',
          'bộ sản phẩm starter',
          'đăng ký thành viên',
          'nạp tiền kích hoạt',
        ], ScamIntent.investmentScam),
      ],
    ),

    ScamGraphBuilder._linear(
      id: 'INV_JOB_01',
      name: 'Việc nhẹ lương cao',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'JOB_OFFER',
          'Lời mời làm việc online',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'TASK_PROMISE',
          'Hứa hẹn thu nhập khủng',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'ADVANCE_FEE',
          'Yêu cầu đóng phí/chốt đơn',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'việc nhẹ lương cao',
          'làm việc tại nhà',
          'kiếm tiền online',
          'thu nhập 10 triệu mỗi tháng',
          'cần tuyển người gấp',
        ], ScamIntent.jobTaskScam),
        ScamGraphBuilder._tr(<String>[
          'chốt đơn',
          'mua hàng ảo',
          'đặt hàng fake',
          'hoa hồng cao',
          'thu nhập khủng',
        ], ScamIntent.jobTaskScam),
        ScamGraphBuilder._tr(<String>[
          'đóng phí tham gia',
          'chuyển khoản trước',
          'phí đào tạo',
          'mua tài khoản',
          'kích hoạt tài khoản',
        ], ScamIntent.jobTaskScam),
      ],
    ),

    ScamGraphBuilder._linear(
      id: 'INV_STOCK_01',
      name: 'Chứng khoán lừa đảo',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'STOCK_INVITE',
          'Lời mời đầu tư chứng khoán',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'INSIDER_TIP',
          'Mách nước nội bộ',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'BUY_NOW',
          'Mua ngay kẻo lỡ',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'đầu tư chứng khoán',
          'cổ phiếu nội bộ',
          'mã chứng khoán',
          'sàn chứng khoán',
          'chơi cổ phiếu',
        ], ScamIntent.investmentScam),
        ScamGraphBuilder._tr(<String>[
          'cổ phiếu sẽ tăng',
          'tip nội bộ',
          'nguồn tin đáng tin cậy',
          'cơ hội ngàn vàng',
          'mua trước khi tăng',
        ], ScamIntent.investmentScam),
        ScamGraphBuilder._tr(<String>[
          'chuyển tiền mua cổ phiếu',
          'mở tài khoản chứng khoán',
          'nạp tiền vào tài khoản',
          'đặt lệnh mua',
          'phí giao dịch',
        ], ScamIntent.investmentScam),
      ],
    ),

    ScamGraphBuilder._linear(
      id: 'INV_ICO_01',
      name: 'ICO/IDO/Token giả',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'TOKEN_HYPE',
          'Quảng bá token mới',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'EARLY_ACCESS',
          'Ưu đãi cho nhà đầu tư sớm',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'INVEST_NOW',
          'Đầu tư ngay',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'ico',
          'ido',
          'token mới',
          'presale',
          'private sale',
        ], ScamIntent.cryptoDrain),
        ScamGraphBuilder._tr(<String>[
          'giá sẽ tăng 100 lần',
          'x100',
          'x1000',
          'sớm nhất được giá tốt nhất',
          'giá ưu đãi cho người đầu tiên',
        ], ScamIntent.cryptoDrain),
        ScamGraphBuilder._tr(<String>[
          'mua token bằng eth',
          'chuyển usdt',
          'ví metamask',
          'swap token',
          'đóng góp dự án',
        ], ScamIntent.cryptoDrain),
      ],
    ),

    ScamGraphBuilder._linear(
      id: 'INV_SKIN_01',
      name: 'MLM Skincare/Biệt dược',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'BEAUTY_INVITE',
          'Lời mời kinh doanh mỹ phẩm',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'SUCCESS_STORY',
          'Chia sẻ thành công',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'STOCK_UP',
          'Yêu cầu nhập hàng',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'kinh doanh mỹ phẩm',
          'bán kem dưỡng da',
          'sản phẩm skincare',
          'thuốc giảm cân',
          'thực phẩm chức năng',
        ], ScamIntent.investmentScam),
        ScamGraphBuilder._tr(<String>[
          'kiếm 50 triệu mỗi tháng',
          'thu nhập khủng',
          'đã có người kiếm được',
          'bạn bè đã thành công',
          'thay đổi cuộc đời',
        ], ScamIntent.investmentScam),
        ScamGraphBuilder._tr(<String>[
          'nhập hàng',
          'mua bộ sản phẩm',
          'phí đại lý',
          'đăng ký nhà phân phối',
          'vốn kinh doanh',
        ], ScamIntent.investmentScam),
      ],
    ),

    ScamGraphBuilder._linear(
      id: 'INV_PONZI_01',
      name: 'Ponzi/Pyramid scheme',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'HIGH_RETURN',
          'Hứa hẹn lợi nhuận phi thường',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'REFERRAL_BONUS',
          'Thưởng giới thiệu',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'LOCK_IN',
          'Gửi tiền dài hạn',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'quỹ đầu tư',
          'gửi tiết kiệm online',
          'lãi suất 30 mỗi tháng',
          'bảo toàn vốn 100',
          'cam kết lãi suất',
        ], ScamIntent.investmentScam),
        ScamGraphBuilder._tr(<String>[
          'thưởng giới thiệu',
          'hoa hồng giới thiệu',
          'mời bạn bè nhận tiền',
          'phần thưởng cho người giới thiệu',
          'bạn giới thiệu được bao nhiêu',
        ], ScamIntent.investmentScam),
        ScamGraphBuilder._tr(<String>[
          'gửi tiền',
          'chuyển khoản vào quỹ',
          'ký hợp đồng',
          'đặt cọc',
          'nạp tiền',
        ], ScamIntent.investmentScam),
      ],
    ),
  ];
}
