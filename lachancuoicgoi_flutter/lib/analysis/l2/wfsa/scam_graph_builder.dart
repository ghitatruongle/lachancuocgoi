import '../intent/scam_intent.dart';
import 'wfsa_engine.dart';

class ScamGraphBuilder {
  ScamGraphBuilder._();

  static List<ScenarioGraph> buildDefaultGraphs() {
    return <ScenarioGraph>[
      _build(
        'G_POLICE_01',
        'Giả danh cơ quan pháp luật',
        <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s('POLICE_INTRO', 'Giả danh công an', ScamStage.stage1Introduction),
          _s(
            'THREAT_ARREST',
            'Đe dọa bắt giữ/liên quan án',
            ScamStage.stage2BaitingThreat,
          ),
          _s(
            'ISOLATION',
            'Yêu cầu ở một mình, không gác máy',
            ScamStage.stage3Urgency,
          ),
          _s(
            'TRANSFER_MONEY',
            'Yêu cầu chuyển tiền tạm giữ',
            ScamStage.stage4Command,
          ),
        ],
        <_EdgeSpec>[
          _e(0, 1, <String>[
            'cục cảnh sát',
            'điều tra',
            'bộ công an',
            'viện kiểm sát',
          ], ScamIntent.authPoliceLawsuit),
          _e(1, 2, <String>[
            'đường dây ma túy',
            'rửa tiền',
            'lệnh bắt khẩn cấp',
            'chuyên án',
          ], ScamIntent.authPoliceLawsuit),
          _e(2, 3, <String>[
            'vào phòng riêng',
            'không được nói cho ai',
            'bảo mật thông tin',
            'không gác máy',
          ]),
          _e(3, 4, <String>[
            'tài khoản tạm giữ',
            'chuyển tiền để đối soát',
            'cung cấp mã otp',
            'mã bảo mật',
          ], ScamIntent.bankCardFraud),
        ],
      ),
      _build(
        'G_VNEID_01',
        'Lừa đảo cập nhật VNeID/Sinh trắc học',
        <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'VNEID_INTRO',
            'Cán bộ phường xử lý định danh',
            ScamStage.stage1Introduction,
          ),
          _s(
            'ERROR_THREAT',
            'Lỗi dữ liệu, dọa khóa',
            ScamStage.stage2BaitingThreat,
          ),
          _s(
            'URGENCY_DOWNLOAD',
            'Yêu cầu tải app hỗ trợ ngay',
            ScamStage.stage3Urgency,
          ),
          _s(
            'SCREEN_CONTROL',
            'Kiểm soát màn hình, sinh trắc học',
            ScamStage.stage4Command,
          ),
        ],
        <_EdgeSpec>[
          _e(0, 1, <String>[
            'cán bộ phường',
            'định danh mức 2',
            'cập nhật sinh trắc học',
            'bộ công an phường',
          ], ScamIntent.taxGovApp),
          _e(1, 2, <String>[
            'lỗi dữ liệu',
            'chưa đồng bộ',
            'khóa tài khoản ngân hàng',
          ], ScamIntent.taxGovApp),
          _e(2, 3, <String>[
            'tải ứng dụng hỗ trợ',
            'dịch vụ công',
            'cài đặt phần mềm',
            'vào đường link',
          ], ScamIntent.techSupportHijack),
          _e(3, 4, <String>[
            'quét khuôn mặt',
            'cấp quyền trợ năng',
            'chia sẻ màn hình',
          ], ScamIntent.techSupportHijack),
        ],
      ),
      _linear(
        id: 'G_TELECOM_01',
        name: 'Dọa khóa SIM/thuê bao',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'TELECOM_INTRO',
            'Tổng đài nhà mạng',
            ScamStage.stage1Introduction,
          ),
          _s(
            'SIM_THREAT',
            'Dọa khóa SIM hai chiều',
            ScamStage.stage2BaitingThreat,
          ),
          _s('VERIFY_CMD', 'Yêu cầu xác thực/cài app', ScamStage.stage3Urgency),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'tổng đài',
            'nhà mạng',
            'viễn thông',
            'viettel',
            'mobifone',
            'vinaphone',
          ], ScamIntent.telecomLock),
          _tr(<String>[
            'khóa sim',
            'hai chiều',
            'chặn một chiều',
            'vi phạm',
            'thuê bao lạ',
          ], ScamIntent.telecomLock),
          _tr(<String>[
            'xác thực',
            'cài app',
            'bấm phím',
            'nhập mã',
          ], ScamIntent.techSupportHijack),
        ],
      ),
      _linear(
        id: 'G_TECH_01',
        name: 'Hỗ trợ kỹ thuật giả',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'TECH_INTRO',
            'Bộ phận kỹ thuật/bảo mật',
            ScamStage.stage1Introduction,
          ),
          _s(
            'ACCOUNT_THREAT',
            'Tài khoản bị hack/lỗi',
            ScamStage.stage2BaitingThreat,
          ),
          _s(
            'INSTALL_CMD',
            'Yêu cầu cài TeamViewer/AnyDesk',
            ScamStage.stage3Urgency,
          ),
          _s('REMOTE_CTRL', 'Chiếm quyền điều khiển', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'bộ phận kỹ thuật',
            'hỗ trợ kỹ thuật',
            'đội ngũ bảo mật',
            'nhân viên zalo',
          ], ScamIntent.techSupportHijack),
          _tr(<String>[
            'tài khoản bị hack',
            'đăng nhập lạ',
            'bị khóa',
            'lỗi bảo mật',
          ], ScamIntent.techSupportHijack),
          _tr(<String>[
            'tải teamviewer',
            'cài anydesk',
            'tải ứng dụng',
            'cài app hỗ trợ',
          ], ScamIntent.techSupportHijack),
          _tr(<String>[
            'chia sẻ màn hình',
            'cấp quyền',
            'nhập mã',
            'remote',
          ], ScamIntent.techSupportHijack),
        ],
      ),
      _linear(
        id: 'G_HOSPITAL_01',
        name: 'Cấp cứu tai nạn giả',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'HOSPITAL_INTRO',
            'Bệnh viện/bác sĩ gọi',
            ScamStage.stage1Introduction,
          ),
          _s('URGENT_SURGERY', 'Cần mổ gấp/tai nạn', ScamStage.stage3Urgency),
          _s('DEPOSIT_CMD', 'Yêu cầu chuyển viện phí', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'bệnh viện',
            'bác sĩ',
            'cấp cứu',
            'phòng hành chính',
          ], ScamIntent.hospitalEmergency),
          _tr(<String>[
            'tai nạn',
            'nguy kịch',
            'mổ gấp',
            'chấn thương sọ não',
          ], ScamIntent.hospitalEmergency),
          _tr(<String>[
            'chuyển tiền',
            'tạm ứng',
            'viện phí',
            'số tài khoản',
          ], ScamIntent.hospitalEmergency),
        ],
      ),
      _linear(
        id: 'G_KIDNAP_01',
        name: 'Bắt cóc ảo',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s('KIDNAP_CLAIM', 'Tuyên bố bắt cóc', ScamStage.stage2BaitingThreat),
          _s('RANSOM_DEMAND', 'Đòi tiền chuộc', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'bắt cóc',
            'con bạn',
            'con anh',
            'tính mạng',
            'bị giữ',
            'campuchia',
          ], ScamIntent.virtualKidnapping),
          _tr(<String>[
            'tiền chuộc',
            'chuyển tiền',
            'nếu không',
            'giết',
          ], ScamIntent.virtualKidnapping),
        ],
      ),
      _linear(
        id: 'G_CEO_01',
        name: 'Giả danh lãnh đạo công ty',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'DIRECTOR_INTRO',
            'Giám đốc/Sếp gọi',
            ScamStage.stage1Introduction,
          ),
          _s(
            'URGENT_TRANSFER',
            'Lệnh chuyển tiền gấp',
            ScamStage.stage3Urgency,
          ),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'giám đốc đây',
            'sếp đây',
            'lãnh đạo',
            'phòng nhân sự',
          ], ScamIntent.ceoFraudB2b),
          _tr(<String>[
            'chuyển khoản cho đối tác',
            'hợp đồng gấp',
            'thanh toán hộ',
            'bí mật',
          ], ScamIntent.ceoFraudB2b),
        ],
      ),
      _linear(
        id: 'G_DEEPFAKE_01',
        name: 'Deepfake bạn bè mượn tiền',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'FRIEND_INTRO',
            'Bạn bè/người quen gọi',
            ScamStage.stage1Introduction,
          ),
          _s('LOAN_REQUEST', 'Mượn tiền gấp', ScamStage.stage3Urgency),
          _s('TRANSFER_CMD', 'Yêu cầu chuyển khoản', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'ơi',
            'nhờ chút',
            'giúp anh',
            'giúp chị',
            'có chuyện gấp',
          ], ScamIntent.socialDeepfakeLoan),
          _tr(<String>[
            'mượn tiền',
            'chuyển đỡ',
            'cần gấp',
            'tối trả',
            'mai trả',
          ], ScamIntent.socialDeepfakeLoan),
          _tr(<String>[
            'số tài khoản',
            'chuyển khoản',
            'chuyển vào',
            'stk',
          ], ScamIntent.bankCardFraud),
        ],
      ),
      _linear(
        id: 'G_ROMANCE_01',
        name: 'Lừa tình/Bưu kiện hải quan',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'GIFT_CLAIM',
            'Gửi quà tặng đắt tiền',
            ScamStage.stage2BaitingThreat,
          ),
          _s('CUSTOMS_FEE', 'Nộp phí hải quan', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'gửi quà',
            'bưu kiện',
            'nước ngoài',
            'quân nhân',
            'tình cảm',
          ], ScamIntent.romanceScam),
          _tr(<String>[
            'phí hải quan',
            'thuế nhập khẩu',
            'kẹt ở sân bay',
            'đóng tiền',
          ], ScamIntent.romanceScam),
        ],
      ),
      _linear(
        id: 'G_SEXTORT_01',
        name: 'Tống tiền bằng ảnh/clip nhạy cảm',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'EVIDENCE_CLAIM',
            'Tuyên bố có bằng chứng',
            ScamStage.stage2BaitingThreat,
          ),
          _s('SPREAD_THREAT', 'Dọa phát tán', ScamStage.stage3Urgency),
          _s('RANSOM_CMD', 'Đòi tiền im lặng', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'ảnh nóng',
            'clip nhạy cảm',
            'video nhạy cảm',
            'lộ clip',
          ], ScamIntent.sextortionBlackmail),
          _tr(<String>[
            'phát tán',
            'tung lên mạng',
            'gửi cho người thân',
            'bạn bè sẽ thấy',
          ], ScamIntent.sextortionBlackmail),
          _tr(<String>[
            'chuyển tiền',
            'tống tiền',
            'im lặng',
            'xóa clip',
          ], ScamIntent.sextortionBlackmail),
        ],
      ),
      _linear(
        id: 'G_CHARITY_01',
        name: 'Kêu gọi từ thiện giả',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s('CHARITY_INTRO', 'Kêu gọi từ thiện', ScamStage.stage1Introduction),
          _s(
            'PRESSURE_DONATE',
            'Thúc ép quyên góp gấp',
            ScamStage.stage2BaitingThreat,
          ),
          _s(
            'PERSONAL_ACCOUNT',
            'Chuyển khoản qua STK cá nhân',
            ScamStage.stage4Command,
          ),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'quyên góp',
            'từ thiện',
            'giúp đỡ',
            'hoàn cảnh',
            'bão lũ',
          ], ScamIntent.charityDonation),
          _tr(<String>[
            'gấp',
            'sắp hết hạn',
            'cần ngay',
            'bé đang chờ mổ',
            'thương lắm',
          ], ScamIntent.charityDonation),
          _tr(<String>[
            'số tài khoản cá nhân',
            'chuyển vào stk',
            'zalo pay',
            'momo',
          ], ScamIntent.charityDonation),
        ],
      ),
      _linear(
        id: 'G_INVEST_01',
        name: 'Lừa đầu tư tiền ảo',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'INVEST_INTRO',
            'Giới thiệu cơ hội đầu tư',
            ScamStage.stage1Introduction,
          ),
          _s(
            'PROFIT_BAIT',
            'Hứa hẹn lợi nhuận cao',
            ScamStage.stage2BaitingThreat,
          ),
          _s('DEPOSIT_CMD', 'Yêu cầu nạp tiền', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'đầu tư',
            'chứng khoán',
            'crypto',
            'forex',
            'sàn giao dịch',
            'bitcoin',
          ], ScamIntent.investmentScam),
          _tr(<String>[
            'lợi nhuận',
            'cam kết',
            'x2',
            'gấp đôi',
            'sinh lời',
            'không rủi ro',
          ], ScamIntent.investmentScam),
          _tr(<String>[
            'nạp tiền',
            'chuyển vào',
            'nâng vốn',
            'kéo lệnh',
            'rút về',
          ], ScamIntent.investmentScam),
        ],
      ),
      _linear(
        id: 'G_JOB_01',
        name: 'Tuyển CTV kiếm hoa hồng',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s('JOB_INTRO', 'Tuyển cộng tác viên', ScamStage.stage1Introduction),
          _s('TASK_BAIT', 'Giao nhiệm vụ dễ', ScamStage.stage2BaitingThreat),
          _s('DEPOSIT_TRAP', 'Yêu cầu đặt cọc', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'tuyển cộng tác viên',
            'việc làm',
            'kiếm thêm',
            'thu nhập',
            'online',
          ], ScamIntent.jobTaskScam),
          _tr(<String>[
            'nhiệm vụ',
            'chốt đơn',
            'like video',
            'đánh giá sản phẩm',
            'hoa hồng',
          ], ScamIntent.jobTaskScam),
          _tr(<String>[
            'đặt cọc',
            'nạp tiền',
            'phí kích hoạt',
            'nâng cấp tài khoản',
          ], ScamIntent.jobTaskScam),
        ],
      ),
      _linear(
        id: 'G_LOTTERY_01',
        name: 'Trúng thưởng tri ân',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'WINNER_INTRO',
            'Thông báo trúng thưởng',
            ScamStage.stage2BaitingThreat,
          ),
          _s('PROC_FEE', 'Yêu cầu đóng phí nhận giải', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'trúng thưởng',
            'giải nhất',
            'xe sh',
            'tri ân',
            'quà tặng',
          ], ScamIntent.giftLottery),
          _tr(<String>[
            'phí làm hồ sơ',
            'đóng thuế',
            'mã nhận quà',
            'chuyển khoản phí',
          ], ScamIntent.giftLottery),
        ],
      ),
      _linear(
        id: 'G_GAMBLE_01',
        name: 'Soi cầu lô đề',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s('TIP_BAIT', 'Cung cấp số chuẩn', ScamStage.stage1Introduction),
          _s(
            'WINNING_PROOF',
            'Chứng minh chiến thắng giả',
            ScamStage.stage2BaitingThreat,
          ),
          _s('DEPOSIT_TRAP', 'Ép nạp tiền đánh đề', ScamStage.stage3Urgency),
          _s('PLATFORM_MOVE', 'Chuyển vào sàn/app', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'soi cầu',
            'lô đề',
            'bạch thủ',
            'số chuẩn',
            'về bờ',
          ], ScamIntent.gamblingPrediction),
          _tr(<String>[
            'trúng rồi',
            'ăn lớn',
            'chiến thắng',
            'chứng minh',
            'hôm qua trúng',
          ], ScamIntent.gamblingPrediction),
          _tr(<String>[
            'nạp tiền',
            'cọc trước',
            'mua số',
            'phí phần mềm',
          ], ScamIntent.gamblingPrediction),
          _tr(<String>[
            'vào app',
            'tải ứng dụng',
            'đăng ký tài khoản',
            'sàn cá cược',
          ], ScamIntent.gamblingPrediction),
        ],
      ),
      _linear(
        id: 'G_VISA_01',
        name: 'Visa/Xuất khẩu lao động',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s('VISA_BAIT', 'Bao đậu Visa/XKLĐ', ScamStage.stage1Introduction),
          _s(
            'PROMISE_JOB',
            'Hứa lương cao, cam kết',
            ScamStage.stage2BaitingThreat,
          ),
          _s('DEPOSIT_VISA', 'Đặt cọc phí visa/XKLĐ', ScamStage.stage3Urgency),
          _s(
            'MONEY_ABROAD',
            'Chuyển tiền ra nước ngoài',
            ScamStage.stage4Command,
          ),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'visa',
            'xuất khẩu lao động',
            'đi hàn quốc',
            'bao đậu',
            'đi nhật',
          ], ScamIntent.immigrationVisaScam),
          _tr(<String>[
            'lương cao',
            'cam kết',
            'đảm bảo',
            'công ty phái cử',
            'hợp đồng',
          ], ScamIntent.immigrationVisaScam),
          _tr(<String>[
            'đặt cọc',
            'phí hồ sơ',
            'phí visa',
            'chuyển trước',
          ], ScamIntent.immigrationVisaScam),
          _tr(<String>[
            'chuyển tiền',
            'western union',
            'tài khoản nước ngoài',
            'phí bổ sung',
          ], ScamIntent.immigrationVisaScam),
        ],
      ),
      _linear(
        id: 'G_BANK_01',
        name: 'Khóa tài khoản khẩn cấp',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s('BANK_INTRO', 'Nhân viên ngân hàng', ScamStage.stage1Introduction),
          _s(
            'LOGIN_THREAT',
            'Đăng nhập bất thường',
            ScamStage.stage2BaitingThreat,
          ),
          _s(
            'VERIFY_URGENT',
            'Xác thực ngay theo tin nhắn',
            ScamStage.stage3Urgency,
          ),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'nhân viên ngân hàng',
            'tổng đài hỗ trợ',
            'trung tâm thẻ',
          ], ScamIntent.bankCardFraud),
          _tr(<String>[
            'đăng nhập lạ',
            'khóa tài khoản',
            'giao dịch bất thường',
            'trừ tiền',
          ], ScamIntent.bankCardFraud),
          _tr(<String>[
            'đọc mã otp',
            'mã xác thực',
            'tin nhắn gửi về',
          ], ScamIntent.bankCardFraud),
        ],
      ),
      _linear(
        id: 'G_SHIP_01',
        name: 'Shipper giả/Giao hàng nợ',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s('SHIPPER_INTRO', 'Giao hàng COD', ScamStage.stage1Introduction),
          _s('PAY_TRAP', 'Thanh toán nợ cũ', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'shipper',
            'giao hàng',
            'đơn hàng',
            'thanh toán cod',
          ], ScamIntent.deliveryCod),
          _tr(<String>[
            'nợ tiền hàng',
            'chuyển khoản trước',
            'đã đặt',
          ], ScamIntent.deliveryCod),
        ],
      ),
      _linear(
        id: 'G_SUB_01',
        name: 'Trừ tiền dịch vụ ảo',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'SUB_THREAT',
            'Thông báo trừ phí dịch vụ',
            ScamStage.stage1Introduction,
          ),
          _s(
            'CANCEL_URGENCY',
            'Hủy gấp trước khi bị trừ thêm',
            ScamStage.stage2BaitingThreat,
          ),
          _s(
            'CLICK_LINK',
            'Yêu cầu click link hủy dịch vụ',
            ScamStage.stage3Urgency,
          ),
          _s('CARD_STEAL', 'Nhập thông tin thẻ/OTP', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'trừ tiền',
            'gia hạn',
            'dịch vụ',
            'đăng ký',
            'gói vip',
          ], ScamIntent.fakeSubscription),
          _tr(<String>[
            'hủy ngay',
            'trước khi bị trừ',
            'tự động gia hạn',
            'mất tiền',
          ], ScamIntent.fakeSubscription),
          _tr(<String>[
            'bấm vào link',
            'truy cập link',
            'hủy tại đây',
            'vào trang web',
          ], ScamIntent.fakeSubscription),
          _tr(<String>[
            'số thẻ',
            'nhập mã otp',
            'mật khẩu',
            'xác nhận thẻ',
          ], ScamIntent.bankCardFraud),
        ],
      ),
      _linear(
        id: 'G_CREDIT_01',
        name: 'Tín dụng đen khủng bố đòi nợ',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s('DEBT_CLAIM', 'Thông báo nợ', ScamStage.stage2BaitingThreat),
          _s('TERROR_THREAT', 'Đe dọa khủng bố', ScamStage.stage3Urgency),
          _s('PAY_CMD', 'Ép trả tiền ngay', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'nợ',
            'khoản vay',
            'app vay',
            'tín dụng đen',
          ], ScamIntent.blackCreditTerror),
          _tr(<String>[
            'đòi nợ',
            'chửi bới',
            'gọi danh bạ',
            'tung lên mạng',
            'khủng bố',
          ], ScamIntent.blackCreditTerror),
          _tr(<String>[
            'trả ngay',
            'chuyển tiền',
            'nộp phí',
            'phí phạt',
          ], ScamIntent.blackCreditTerror),
        ],
      ),
      _linear(
        id: 'G_RECOVERY_01',
        name: 'Dịch vụ lấy lại tiền lừa đảo',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s('RECOVERY_BAIT', 'Hứa lấy lại tiền', ScamStage.stage1Introduction),
          _s(
            'PROVE_LEGIT',
            'Chứng minh khả năng thu hồi',
            ScamStage.stage2BaitingThreat,
          ),
          _s('DEPOSIT_FEE', 'Đặt cọc phí hỗ trợ', ScamStage.stage3Urgency),
          _s(
            'BANKING_ACCESS',
            'Yêu cầu cung cấp app banking',
            ScamStage.stage4Command,
          ),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'lấy lại tiền',
            'thu hồi',
            'luật sư',
            'cảnh sát mạng',
            'hỗ trợ nạn nhân',
          ], ScamIntent.recoveryScam),
          _tr(<String>[
            'đã thu hồi',
            'thành công',
            'chuyên xử lý',
            'có bằng chứng',
          ], ScamIntent.recoveryScam),
          _tr(<String>[
            'đặt cọc',
            'phí hỗ trợ',
            'phí luật sư',
            'chuyển phí trước',
          ], ScamIntent.recoveryScam),
          _tr(<String>[
            'đăng nhập banking',
            'cung cấp tài khoản',
            'chia sẻ màn hình',
            'mã otp',
          ], ScamIntent.bankCardFraud),
        ],
      ),
      _linear(
        id: 'G_GENERIC_01',
        name: 'Lừa đảo không rõ kịch bản',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'SUSPICIOUS_BAIT',
            'Dấu hiệu nghi vấn',
            ScamStage.stage1Introduction,
          ),
          _s('TRUST_BUILD', 'Tạo niềm tin giả', ScamStage.stage2BaitingThreat),
          _s('MONEY_REQUEST', 'Yêu cầu chuyển tiền', ScamStage.stage3Urgency),
          _s('URGENCY_FORCE', 'Ép buộc khẩn cấp', ScamStage.stage4Command),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'nghe đây',
            'có chuyện này',
            'ưu đãi',
            'bí mật',
            'nghe nè',
          ], ScamIntent.genericScam),
          _tr(<String>[
            'tin tôi đi',
            'cam kết',
            'đảm bảo',
            'có người giới thiệu',
          ], ScamIntent.genericScam),
          _tr(<String>[
            'chuyển tiền',
            'nạp tiền',
            'đặt cọc',
            'thanh toán',
          ], ScamIntent.genericScam),
          _tr(<String>[
            'ngay bây giờ',
            'trong vòng',
            'hết hạn',
            'mất cơ hội',
          ], ScamIntent.genericScam),
        ],
      ),
      _linear(
        id: 'G_ECOMMERCE_01',
        name: 'Shop giả/Thanh toán khống',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'PRODUCT_BAIT',
            'Quảng cáo hàng giá rẻ/sale sốc',
            ScamStage.stage1Introduction,
          ),
          _s(
            'PAYMENT_URGENCY',
            'Ép thanh toán gấp, chỉ còn vài suất',
            ScamStage.stage2BaitingThreat,
          ),
          _s(
            'TRANSFER_REQUEST',
            'Yêu cầu chuyển khoản trước khi giao hàng',
            ScamStage.stage3Urgency,
          ),
          _s(
            'EXTRA_FEE',
            'Phát sinh phí/thuế yêu cầu chuyển thêm',
            ScamStage.stage4Command,
          ),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'sale sốc',
            'giảm giá',
            'hàng xách tay',
            'giá gốc',
            'flash sale',
          ], ScamIntent.fakeEcommerce),
          _tr(<String>[
            'chuyển khoản trước',
            'thanh toán trước',
            'cọc trước',
            'đặt cọc',
            'giữ đơn',
          ], ScamIntent.fakeEcommerce),
          _tr(<String>[
            'chuyển tiền',
            'số tài khoản',
            'nội dung chuyển khoản',
            'chốt đơn',
          ], ScamIntent.fakeEcommerce),
          _tr(<String>[
            'phí hải quan',
            'thuế nhập khẩu',
            'phí phát sinh',
            'chuyển thêm',
          ], ScamIntent.fakeEcommerce),
        ],
      ),
      _linear(
        id: 'G_CRYPTO_01',
        name: 'Ví crypto/Sàn ảo rút tiền',
        states: <_StateSpec>[
          _s('START', 'Initial State', ScamStage.stage1Introduction),
          _s(
            'INVESTMENT_BAIT',
            'Giới thiệu sàn crypto/lợi nhuận cao',
            ScamStage.stage1Introduction,
          ),
          _s(
            'WALLET_SETUP',
            'Hướng dẫn cài ví/tạo tài khoản',
            ScamStage.stage2BaitingThreat,
          ),
          _s(
            'DEPOSIT_PRESSURE',
            'Ép nạp tiền vào sàn',
            ScamStage.stage3Urgency,
          ),
          _s(
            'DRAIN_WALLET',
            'Rút hết tiền/yêu cầu nạp thêm để rút',
            ScamStage.stage4Command,
          ),
        ],
        triggers: <_TriggerSpec>[
          _tr(<String>[
            'sàn crypto',
            'tiền ảo',
            'bitcoin',
            'lợi nhuận',
            'đầu tư online',
          ], ScamIntent.cryptoDrain),
          _tr(<String>[
            'cài ví',
            'tạo tài khoản',
            'đăng ký sàn',
            'meta mask',
            'trust wallet',
          ], ScamIntent.cryptoDrain),
          _tr(<String>[
            'nạp tiền',
            'chuyển vào ví',
            'mua coin',
            'nạp usdt',
            'deposit',
          ], ScamIntent.cryptoDrain),
          _tr(<String>[
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

  static ScenarioGraph _linear({
    required String id,
    required String name,
    required List<_StateSpec> states,
    required List<_TriggerSpec> triggers,
  }) {
    final edges = <_EdgeSpec>[];
    for (var i = 0; i < triggers.length; i++) {
      edges.add(_e(i, i + 1, triggers[i].phrases, triggers[i].requiredIntent));
    }
    return _build(id, name, states, edges);
  }

  static ScenarioGraph _build(
    String id,
    String name,
    List<_StateSpec> stateSpecs,
    List<_EdgeSpec> edgeSpecs,
  ) {
    final states = <StateNode>[
      for (final state in stateSpecs)
        StateNode(
          id: state.id,
          description: state.description,
          stage: state.stage,
        ),
    ];
    final transitions = <String, List<Transition>>{};
    for (final edge in edgeSpecs) {
      transitions
          .putIfAbsent(states[edge.from].id, () => <Transition>[])
          .add(
            Transition(
              triggerPhrases: edge.phrases,
              targetStateId: states[edge.to].id,
              requiredIntent: edge.requiredIntent,
            ),
          );
    }
    return ScenarioGraph(
      graphId: id,
      name: name,
      states: <String, StateNode>{for (final state in states) state.id: state},
      transitions: transitions,
      initialStateId: states.first.id,
    );
  }

  static _StateSpec _s(String id, String description, ScamStage stage) {
    return _StateSpec(id, description, stage);
  }

  static _TriggerSpec _tr(List<String> phrases, [ScamIntent? intent]) {
    return _TriggerSpec(phrases, intent);
  }

  static _EdgeSpec _e(
    int from,
    int to,
    List<String> phrases, [
    ScamIntent? intent,
  ]) {
    return _EdgeSpec(from, to, phrases, intent);
  }
}

class _StateSpec {
  const _StateSpec(this.id, this.description, this.stage);

  final String id;
  final String description;
  final ScamStage stage;
}

class _TriggerSpec {
  const _TriggerSpec(this.phrases, this.requiredIntent);

  final List<String> phrases;
  final ScamIntent? requiredIntent;
}

class _EdgeSpec {
  const _EdgeSpec(this.from, this.to, this.phrases, this.requiredIntent);

  final int from;
  final int to;
  final List<String> phrases;
  final ScamIntent? requiredIntent;
}
