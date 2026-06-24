part of 'scam_graph_builder.dart';

/// Authority-impersonation scenarios: police, VNeID, telecom, tech support,
/// hospital emergency (5 scenarios).
List<ScenarioGraph> _authorityScenarios() {
  return <ScenarioGraph>[
    ScamGraphBuilder._build(
      'G_POLICE_01',
      'Giả danh cơ quan pháp luật',
      <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'POLICE_INTRO',
          'Giả danh công an',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'THREAT_ARREST',
          'Đe dọa bắt giữ/liên quan án',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'ISOLATION',
          'Yêu cầu ở một mình, không gác máy',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'TRANSFER_MONEY',
          'Yêu cầu chuyển tiền tạm giữ',
          ScamStage.stage4Command,
        ),
      ],
      <_EdgeSpec>[
        ScamGraphBuilder._e(0, 1, <String>[
          'cục cảnh sát',
          'điều tra',
          'bộ công an',
          'viện kiểm sát',
        ], ScamIntent.authPoliceLawsuit),
        ScamGraphBuilder._e(1, 2, <String>[
          'đường dây ma túy',
          'rửa tiền',
          'lệnh bắt khẩn cấp',
          'chuyên án',
        ], ScamIntent.authPoliceLawsuit),
        ScamGraphBuilder._e(2, 3, <String>[
          'vào phòng riêng',
          'không được nói cho ai',
          'bảo mật thông tin',
          'không gác máy',
        ]),
        ScamGraphBuilder._e(3, 4, <String>[
          'tài khoản tạm giữ',
          'chuyển tiền để đối soát',
          'cung cấp mã otp',
          'mã bảo mật',
        ], ScamIntent.bankCardFraud),
      ],
    ),
    ScamGraphBuilder._build(
      'G_VNEID_01',
      'Lừa đảo cập nhật VNeID/Sinh trắc học',
      <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'VNEID_INTRO',
          'Cán bộ phường xử lý định danh',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'ERROR_THREAT',
          'Lỗi dữ liệu, dọa khóa',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'URGENCY_DOWNLOAD',
          'Yêu cầu tải app hỗ trợ ngay',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'SCREEN_CONTROL',
          'Kiểm soát màn hình, sinh trắc học',
          ScamStage.stage4Command,
        ),
      ],
      <_EdgeSpec>[
        ScamGraphBuilder._e(0, 1, <String>[
          'cán bộ phường',
          'định danh mức 2',
          'cập nhật sinh trắc học',
          'bộ công an phường',
        ], ScamIntent.taxGovApp),
        ScamGraphBuilder._e(1, 2, <String>[
          'lỗi dữ liệu',
          'chưa đồng bộ',
          'khóa tài khoản ngân hàng',
        ], ScamIntent.taxGovApp),
        ScamGraphBuilder._e(2, 3, <String>[
          'tải ứng dụng hỗ trợ',
          'dịch vụ công',
          'cài đặt phần mềm',
          'vào đường link',
        ], ScamIntent.techSupportHijack),
        ScamGraphBuilder._e(3, 4, <String>[
          'quét khuôn mặt',
          'cấp quyền trợ năng',
          'chia sẻ màn hình',
        ], ScamIntent.techSupportHijack),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_TELECOM_01',
      name: 'Dọa khóa SIM/thuê bao',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'TELECOM_INTRO',
          'Tổng đài nhà mạng',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'SIM_THREAT',
          'Dọa khóa SIM hai chiều',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'VERIFY_CMD',
          'Yêu cầu xác thực/cài app',
          ScamStage.stage3Urgency,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'tổng đài',
          'nhà mạng',
          'viễn thông',
          'viettel',
          'mobifone',
          'vinaphone',
        ], ScamIntent.telecomLock),
        ScamGraphBuilder._tr(<String>[
          'khóa sim',
          'hai chiều',
          'chặn một chiều',
          'vi phạm',
          'thuê bao lạ',
        ], ScamIntent.telecomLock),
        ScamGraphBuilder._tr(<String>[
          'xác thực',
          'cài app',
          'bấm phím',
          'nhập mã',
        ], ScamIntent.techSupportHijack),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_TECH_01',
      name: 'Hỗ trợ kỹ thuật giả',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'TECH_INTRO',
          'Bộ phận kỹ thuật/bảo mật',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'ACCOUNT_THREAT',
          'Tài khoản bị hack/lỗi',
          ScamStage.stage2BaitingThreat,
        ),
        ScamGraphBuilder._s(
          'INSTALL_CMD',
          'Yêu cầu cài TeamViewer/AnyDesk',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'REMOTE_CTRL',
          'Chiếm quyền điều khiển',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'bộ phận kỹ thuật',
          'hỗ trợ kỹ thuật',
          'đội ngũ bảo mật',
          'nhân viên zalo',
        ], ScamIntent.techSupportHijack),
        ScamGraphBuilder._tr(<String>[
          'tài khoản bị hack',
          'đăng nhập lạ',
          'bị khóa',
          'lỗi bảo mật',
        ], ScamIntent.techSupportHijack),
        ScamGraphBuilder._tr(<String>[
          'tải teamviewer',
          'cài anydesk',
          'tải ứng dụng',
          'cài app hỗ trợ',
        ], ScamIntent.techSupportHijack),
        ScamGraphBuilder._tr(<String>[
          'chia sẻ màn hình',
          'cấp quyền',
          'nhập mã',
          'remote',
        ], ScamIntent.techSupportHijack),
      ],
    ),
    ScamGraphBuilder._linear(
      id: 'G_HOSPITAL_01',
      name: 'Cấp cứu tai nạn giả',
      states: <_StateSpec>[
        ScamGraphBuilder._s(
          'START',
          'Initial State',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'HOSPITAL_INTRO',
          'Bệnh viện/bác sĩ gọi',
          ScamStage.stage1Introduction,
        ),
        ScamGraphBuilder._s(
          'URGENT_SURGERY',
          'Cần mổ gấp/tai nạn',
          ScamStage.stage3Urgency,
        ),
        ScamGraphBuilder._s(
          'DEPOSIT_CMD',
          'Yêu cầu chuyển viện phí',
          ScamStage.stage4Command,
        ),
      ],
      triggers: <_TriggerSpec>[
        ScamGraphBuilder._tr(<String>[
          'bệnh viện',
          'bác sĩ',
          'cấp cứu',
          'phòng hành chính',
        ], ScamIntent.hospitalEmergency),
        ScamGraphBuilder._tr(<String>[
          'tai nạn',
          'nguy kịch',
          'mổ gấp',
          'chấn thương sọ não',
        ], ScamIntent.hospitalEmergency),
        ScamGraphBuilder._tr(<String>[
          'chuyển tiền',
          'tạm ứng',
          'viện phí',
          'số tài khoản',
        ], ScamIntent.hospitalEmergency),
      ],
    ),
  ];
}
