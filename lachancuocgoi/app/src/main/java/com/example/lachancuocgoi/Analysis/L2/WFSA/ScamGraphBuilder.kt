package com.example.lachancuocgoi.Analysis.L2.WFSA

import com.example.lachancuocgoi.Analysis.L2.Intent.ScamIntent

/**
 * Xây dựng các đồ thị kịch bản lừa đảo (WFSA Scenario Graphs) cho 22 nhóm.
 * Mỗi graph mô hình hóa chuỗi sự kiện từ giới thiệu → mồi nhử → thúc ép → hành động.
 * WFSA Engine dùng các graph này để theo dõi tiến trình cuộc gọi theo thời gian thực.
 */
object ScamGraphBuilder {

    fun buildDefaultGraphs(): List<ScenarioGraph> {
        return listOf(
            buildPoliceImpersonationGraph(),       // 0. AUTH_POLICE_LAWSUIT
            buildVNeidScamGraph(),                 // 1. TAX_GOV_APP
            buildTelecomLockGraph(),               // 2. TELECOM_LOCK
            buildTechSupportHijackGraph(),         // 3. TECH_SUPPORT_HIJACK
            buildHospitalEmergencyGraph(),         // 4. HOSPITAL_EMERGENCY
            buildVirtualKidnappingGraph(),         // 5. VIRTUAL_KIDNAPPING
            buildCeoFraudGraph(),                  // 6. CEO_FRAUD_B2B
            buildSocialDeepfakeLoanGraph(),        // 7. SOCIAL_DEEPFAKE_LOAN
            buildRomanceScamGraph(),               // 8. ROMANCE_SCAM
            buildSextortionBlackmailGraph(),       // 9. SEXTORTION_BLACKMAIL
            buildCharityDonationGraph(),           // 10. CHARITY_DONATION
            buildInvestmentScamGraph(),            // 11. INVESTMENT_SCAM
            buildJobTaskScamGraph(),               // 12. JOB_TASK_SCAM
            buildGiftLotteryGraph(),               // 13. GIFT_LOTTERY
            buildGamblingPredictionGraph(),        // 14. GAMBLING_PREDICTION
            buildImmigrationVisaScamGraph(),       // 15. IMMIGRATION_VISA_SCAM
            buildBankCardFraudGraph(),             // 16. BANK_CARD_FRAUD
            buildDeliveryCodGraph(),               // 17. DELIVERY_COD
            buildFakeSubscriptionGraph(),          // 18. FAKE_SUBSCRIPTION
            buildBlackCreditTerrorGraph(),         // 19. BLACK_CREDIT_TERROR
            buildRecoveryScamGraph(),              // 20. RECOVERY_SCAM
            buildGenericScamGraph()                // 21. GENERIC_SCAM
        )
    }

    // === 1. AUTH_POLICE_LAWSUIT ===
    private fun buildPoliceImpersonationGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("POLICE_INTRO", "Giả danh công an", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("THREAT_ARREST", "Đe dọa bắt giữ/liên quan án", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("ISOLATION", "Yêu cầu ở một mình, không gác máy", ScamStage.STAGE_3_URGENCY)
        val s4 = StateNode("TRANSFER_MONEY", "Yêu cầu chuyển tiền tạm giữ", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_POLICE_01",
            name = "Giả danh cơ quan pháp luật",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3, s4.id to s4),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("cục cảnh sát", "điều tra", "bộ công an", "viện kiểm sát"), s1.id, ScamIntent.AUTH_POLICE_LAWSUIT)
                ),
                s1.id to listOf(
                    Transition(listOf("đường dây ma túy", "rửa tiền", "lệnh bắt khẩn cấp", "chuyên án"), s2.id, ScamIntent.AUTH_POLICE_LAWSUIT)
                ),
                s2.id to listOf(
                    Transition(listOf("vào phòng riêng", "không được nói cho ai", "bảo mật thông tin", "không gác máy"), s3.id)
                ),
                s3.id to listOf(
                    Transition(listOf("tài khoản tạm giữ", "chuyển tiền để đối soát", "cung cấp mã otp", "mã bảo mật"), s4.id, ScamIntent.BANK_CARD_FRAUD)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 2. TAX_GOV_APP ===
    private fun buildVNeidScamGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("VNEID_INTRO", "Cán bộ phường xử lý định danh", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("ERROR_THREAT", "Lỗi dữ liệu, dọa khóa", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("URGENCY_DOWNLOAD", "Yêu cầu tải app hỗ trợ ngay", ScamStage.STAGE_3_URGENCY)
        val s4 = StateNode("SCREEN_CONTROL", "Kiểm soát màn hình, sinh trắc học", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_VNEID_01",
            name = "Lừa đảo cập nhật VNeID/Sinh trắc học",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3, s4.id to s4),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("cán bộ phường", "định danh mức 2", "cập nhật sinh trắc học", "bộ công an phường"), s1.id, ScamIntent.TAX_GOV_APP)
                ),
                s1.id to listOf(
                    Transition(listOf("lỗi dữ liệu", "chưa đồng bộ", "khóa tài khoản ngân hàng"), s2.id, ScamIntent.TAX_GOV_APP)
                ),
                s2.id to listOf(
                    Transition(listOf("tải ứng dụng hỗ trợ", "dịch vụ công", "cài đặt phần mềm", "vào đường link"), s3.id, ScamIntent.TECH_SUPPORT_HIJACK)
                ),
                s3.id to listOf(
                    Transition(listOf("quét khuôn mặt", "cấp quyền trợ năng", "chia sẻ màn hình"), s4.id, ScamIntent.TECH_SUPPORT_HIJACK)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 3. TELECOM_LOCK ===
    private fun buildTelecomLockGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("TELECOM_INTRO", "Tổng đài nhà mạng", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("SIM_THREAT", "Dọa khóa SIM hai chiều", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("VERIFY_CMD", "Yêu cầu xác thực/cài app", ScamStage.STAGE_3_URGENCY)

        return ScenarioGraph(
            graphId = "G_TELECOM_01",
            name = "Dọa khóa SIM/thuê bao",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("tổng đài", "nhà mạng", "viễn thông", "viettel", "mobifone", "vinaphone"), s1.id, ScamIntent.TELECOM_LOCK)
                ),
                s1.id to listOf(
                    Transition(listOf("khóa sim", "hai chiều", "chặn một chiều", "vi phạm", "thuê bao lạ"), s2.id, ScamIntent.TELECOM_LOCK)
                ),
                s2.id to listOf(
                    Transition(listOf("xác thực", "cài app", "bấm phím", "nhập mã"), s3.id, ScamIntent.TECH_SUPPORT_HIJACK)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 4. TECH_SUPPORT_HIJACK ===
    private fun buildTechSupportHijackGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("TECH_INTRO", "Bộ phận kỹ thuật/bảo mật", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("ACCOUNT_THREAT", "Tài khoản bị hack/lỗi", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("INSTALL_CMD", "Yêu cầu cài TeamViewer/AnyDesk", ScamStage.STAGE_3_URGENCY)
        val s4 = StateNode("REMOTE_CTRL", "Chiếm quyền điều khiển", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_TECH_01",
            name = "Hỗ trợ kỹ thuật giả",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3, s4.id to s4),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("bộ phận kỹ thuật", "hỗ trợ kỹ thuật", "đội ngũ bảo mật", "nhân viên zalo"), s1.id, ScamIntent.TECH_SUPPORT_HIJACK)
                ),
                s1.id to listOf(
                    Transition(listOf("tài khoản bị hack", "đăng nhập lạ", "bị khóa", "lỗi bảo mật"), s2.id, ScamIntent.TECH_SUPPORT_HIJACK)
                ),
                s2.id to listOf(
                    Transition(listOf("tải teamviewer", "cài anydesk", "tải ứng dụng", "cài app hỗ trợ"), s3.id, ScamIntent.TECH_SUPPORT_HIJACK)
                ),
                s3.id to listOf(
                    Transition(listOf("chia sẻ màn hình", "cấp quyền", "nhập mã", "remote"), s4.id, ScamIntent.TECH_SUPPORT_HIJACK)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 6. VIRTUAL_KIDNAPPING ===
    private fun buildVirtualKidnappingGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("KIDNAP_CLAIM", "Tuyên bố bắt cóc", ScamStage.STAGE_2_BAITING_THREAT)
        val s2 = StateNode("RANSOM_DEMAND", "Đòi tiền chuộc", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_KIDNAP_01",
            name = "Bắt cóc ảo",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("bắt cóc", "con bạn", "con anh", "tính mạng", "bị giữ", "campuchia"), s1.id, ScamIntent.VIRTUAL_KIDNAPPING)
                ),
                s1.id to listOf(
                    Transition(listOf("tiền chuộc", "chuyển tiền", "nếu không", "giết"), s2.id, ScamIntent.VIRTUAL_KIDNAPPING)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 8. SOCIAL_DEEPFAKE_LOAN ===
    private fun buildSocialDeepfakeLoanGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("FRIEND_INTRO", "Bạn bè/người quen gọi", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("LOAN_REQUEST", "Mượn tiền gấp", ScamStage.STAGE_3_URGENCY)
        val s3 = StateNode("TRANSFER_CMD", "Yêu cầu chuyển khoản", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_DEEPFAKE_01",
            name = "Deepfake bạn bè mượn tiền",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("ơi", "nhờ chút", "giúp anh", "giúp chị", "có chuyện gấp"), s1.id, ScamIntent.SOCIAL_DEEPFAKE_LOAN)
                ),
                s1.id to listOf(
                    Transition(listOf("mượn tiền", "chuyển đỡ", "cần gấp", "tối trả", "mai trả"), s2.id, ScamIntent.SOCIAL_DEEPFAKE_LOAN)
                ),
                s2.id to listOf(
                    Transition(listOf("số tài khoản", "chuyển khoản", "chuyển vào", "stk"), s3.id, ScamIntent.BANK_CARD_FRAUD)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 12. INVESTMENT_SCAM ===
    private fun buildInvestmentScamGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("INVEST_INTRO", "Giới thiệu cơ hội đầu tư", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("PROFIT_BAIT", "Hứa hẹn lợi nhuận cao", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("DEPOSIT_CMD", "Yêu cầu nạp tiền", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_INVEST_01",
            name = "Lừa đầu tư tiền ảo",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("đầu tư", "chứng khoán", "crypto", "forex", "sàn giao dịch", "bitcoin"), s1.id, ScamIntent.INVESTMENT_SCAM)
                ),
                s1.id to listOf(
                    Transition(listOf("lợi nhuận", "cam kết", "x2", "gấp đôi", "sinh lời", "không rủi ro"), s2.id, ScamIntent.INVESTMENT_SCAM)
                ),
                s2.id to listOf(
                    Transition(listOf("nạp tiền", "chuyển vào", "nâng vốn", "kéo lệnh", "rút về"), s3.id, ScamIntent.INVESTMENT_SCAM)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 13. JOB_TASK_SCAM ===
    private fun buildJobTaskScamGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("JOB_INTRO", "Tuyển cộng tác viên", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("TASK_BAIT", "Giao nhiệm vụ dễ", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("DEPOSIT_TRAP", "Yêu cầu đặt cọc", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_JOB_01",
            name = "Tuyển CTV kiếm hoa hồng",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("tuyển cộng tác viên", "việc làm", "kiếm thêm", "thu nhập", "online"), s1.id, ScamIntent.JOB_TASK_SCAM)
                ),
                s1.id to listOf(
                    Transition(listOf("nhiệm vụ", "chốt đơn", "like video", "đánh giá sản phẩm", "hoa hồng"), s2.id, ScamIntent.JOB_TASK_SCAM)
                ),
                s2.id to listOf(
                    Transition(listOf("đặt cọc", "nạp tiền", "phí kích hoạt", "nâng cấp tài khoản"), s3.id, ScamIntent.JOB_TASK_SCAM)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 17. BANK_CARD_FRAUD ===
    private fun buildBankCardFraudGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("BANK_INTRO", "Nhân viên ngân hàng", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("LOGIN_THREAT", "Đăng nhập bất thường", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("VERIFY_URGENT", "Xác thực ngay theo tin nhắn", ScamStage.STAGE_3_URGENCY)

        return ScenarioGraph(
            graphId = "G_BANK_01",
            name = "Khóa tài khoản khẩn cấp",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("nhân viên ngân hàng", "tổng đài hỗ trợ", "trung tâm thẻ"), s1.id, ScamIntent.BANK_CARD_FRAUD)
                ),
                s1.id to listOf(
                    Transition(listOf("đăng nhập lạ", "khóa tài khoản", "giao dịch bất thường", "trừ tiền"), s2.id, ScamIntent.BANK_CARD_FRAUD)
                ),
                s2.id to listOf(
                    Transition(listOf("đọc mã otp", "mã xác thực", "tin nhắn gửi về"), s3.id, ScamIntent.BANK_CARD_FRAUD)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 20. BLACK_CREDIT_TERROR ===
    private fun buildBlackCreditTerrorGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("DEBT_CLAIM", "Thông báo nợ", ScamStage.STAGE_2_BAITING_THREAT)
        val s2 = StateNode("TERROR_THREAT", "Đe dọa khủng bố", ScamStage.STAGE_3_URGENCY)
        val s3 = StateNode("PAY_CMD", "Ép trả tiền ngay", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_CREDIT_01",
            name = "Tín dụng đen khủng bố đòi nợ",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("nợ", "khoản vay", "app vay", "tín dụng đen"), s1.id, ScamIntent.BLACK_CREDIT_TERROR)
                ),
                s1.id to listOf(
                    Transition(listOf("đòi nợ", "chửi bới", "gọi danh bạ", "tung lên mạng", "khủng bố"), s2.id, ScamIntent.BLACK_CREDIT_TERROR)
                ),
                s2.id to listOf(
                    Transition(listOf("trả ngay", "chuyển tiền", "nộp phí", "phí phạt"), s3.id, ScamIntent.BLACK_CREDIT_TERROR)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 10. SEXTORTION_BLACKMAIL ===
    private fun buildSextortionBlackmailGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("EVIDENCE_CLAIM", "Tuyên bố có bằng chứng", ScamStage.STAGE_2_BAITING_THREAT)
        val s2 = StateNode("SPREAD_THREAT", "Dọa phát tán", ScamStage.STAGE_3_URGENCY)
        val s3 = StateNode("RANSOM_CMD", "Đòi tiền im lặng", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_SEXTORT_01",
            name = "Tống tiền bằng ảnh/clip nhạy cảm",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("ảnh nóng", "clip nhạy cảm", "video nhạy cảm", "lộ clip"), s1.id, ScamIntent.SEXTORTION_BLACKMAIL)
                ),
                s1.id to listOf(
                    Transition(listOf("phát tán", "tung lên mạng", "gửi cho người thân", "bạn bè sẽ thấy"), s2.id, ScamIntent.SEXTORTION_BLACKMAIL)
                ),
                s2.id to listOf(
                    Transition(listOf("chuyển tiền", "tống tiền", "im lặng", "xóa clip"), s3.id, ScamIntent.SEXTORTION_BLACKMAIL)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 4. HOSPITAL_EMERGENCY ===
    private fun buildHospitalEmergencyGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("HOSPITAL_INTRO", "Bệnh viện/bác sĩ gọi", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("URGENT_SURGERY", "Cần mổ gấp/tai nạn", ScamStage.STAGE_3_URGENCY)
        val s3 = StateNode("DEPOSIT_CMD", "Yêu cầu chuyển viện phí", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_HOSPITAL_01",
            name = "Cấp cứu tai nạn giả",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("bệnh viện", "bác sĩ", "cấp cứu", "phòng hành chính"), s1.id, ScamIntent.HOSPITAL_EMERGENCY)
                ),
                s1.id to listOf(
                    Transition(listOf("tai nạn", "nguy kịch", "mổ gấp", "chấn thương sọ não"), s2.id, ScamIntent.HOSPITAL_EMERGENCY)
                ),
                s2.id to listOf(
                    Transition(listOf("chuyển tiền", "tạm ứng", "viện phí", "số tài khoản"), s3.id, ScamIntent.HOSPITAL_EMERGENCY)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 6. CEO_FRAUD_B2B ===
    private fun buildCeoFraudGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("DIRECTOR_INTRO", "Giám đốc/Sếp gọi", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("URGENT_TRANSFER", "Lệnh chuyển tiền gấp", ScamStage.STAGE_3_URGENCY)

        return ScenarioGraph(
            graphId = "G_CEO_01",
            name = "Giả danh lãnh đạo công ty",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("giám đốc đây", "sếp đây", "lãnh đạo", "phòng nhân sự"), s1.id, ScamIntent.CEO_FRAUD_B2B)
                ),
                s1.id to listOf(
                    Transition(listOf("chuyển khoản cho đối tác", "hợp đồng gấp", "thanh toán hộ", "bí mật"), s2.id, ScamIntent.CEO_FRAUD_B2B)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 8. ROMANCE_SCAM ===
    private fun buildRomanceScamGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("GIFT_CLAIM", "Gửi quà tặng đắt tiền", ScamStage.STAGE_2_BAITING_THREAT)
        val s2 = StateNode("CUSTOMS_FEE", "Nộp phí hải quan", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_ROMANCE_01",
            name = "Lừa tình/Bưu kiện hải quan",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("gửi quà", "bưu kiện", "nước ngoài", "quân nhân", "tình cảm"), s1.id, ScamIntent.ROMANCE_SCAM)
                ),
                s1.id to listOf(
                    Transition(listOf("phí hải quan", "thuế nhập khẩu", "kẹt ở sân bay", "đóng tiền"), s2.id, ScamIntent.ROMANCE_SCAM)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 10. CHARITY_DONATION === [C3 EXPANDED]
    private fun buildCharityDonationGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("CHARITY_INTRO", "Kêu gọi từ thiện", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("PRESSURE_DONATE", "Thúc ép quyên góp gấp", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("PERSONAL_ACCOUNT", "Chuyển khoản qua STK cá nhân", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_CHARITY_01",
            name = "Kêu gọi từ thiện giả",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("quyên góp", "từ thiện", "giúp đỡ", "hoàn cảnh", "bão lũ"), s1.id, ScamIntent.CHARITY_DONATION)
                ),
                s1.id to listOf(
                    Transition(listOf("gấp", "sắp hết hạn", "cần ngay", "bé đang chờ mổ", "thương lắm"), s2.id, ScamIntent.CHARITY_DONATION)
                ),
                s2.id to listOf(
                    Transition(listOf("số tài khoản cá nhân", "chuyển vào stk", "zalo pay", "momo"), s3.id, ScamIntent.CHARITY_DONATION)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 13. GIFT_LOTTERY ===
    private fun buildGiftLotteryGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("WINNER_INTRO", "Thông báo trúng thưởng", ScamStage.STAGE_2_BAITING_THREAT)
        val s2 = StateNode("PROC_FEE", "Yêu cầu đóng phí nhận giải", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_LOTTERY_01",
            name = "Trúng thưởng tri ân",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("trúng thưởng", "giải nhất", "xe sh", "tri ân", "quà tặng"), s1.id, ScamIntent.GIFT_LOTTERY)
                ),
                s1.id to listOf(
                    Transition(listOf("phí làm hồ sơ", "đóng thuế", "mã nhận quà", "chuyển khoản phí"), s2.id, ScamIntent.GIFT_LOTTERY)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 14. GAMBLING_PREDICTION === [C3 EXPANDED]
    private fun buildGamblingPredictionGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("TIP_BAIT", "Cung cấp số chuẩn", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("WINNING_PROOF", "Chứng minh chiến thắng giả", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("DEPOSIT_TRAP", "Ép nạp tiền đánh đề", ScamStage.STAGE_3_URGENCY)
        val s4 = StateNode("PLATFORM_MOVE", "Chuyển vào sàn/app", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_GAMBLE_01",
            name = "Soi cầu lô đề",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3, s4.id to s4),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("soi cầu", "lô đề", "bạch thủ", "số chuẩn", "về bờ"), s1.id, ScamIntent.GAMBLING_PREDICTION)
                ),
                s1.id to listOf(
                    Transition(listOf("trúng rồi", "ăn lớn", "chiến thắng", "chứng minh", "hôm qua trúng"), s2.id, ScamIntent.GAMBLING_PREDICTION)
                ),
                s2.id to listOf(
                    Transition(listOf("nạp tiền", "cọc trước", "mua số", "phí phần mềm"), s3.id, ScamIntent.GAMBLING_PREDICTION)
                ),
                s3.id to listOf(
                    Transition(listOf("vào app", "tải ứng dụng", "đăng ký tài khoản", "sàn cá cược"), s4.id, ScamIntent.GAMBLING_PREDICTION)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 15. IMMIGRATION_VISA_SCAM === [C3 EXPANDED]
    private fun buildImmigrationVisaScamGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("VISA_BAIT", "Bao đậu Visa/XKLĐ", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("PROMISE_JOB", "Hứa lương cao, cam kết", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("DEPOSIT_VISA", "Đặt cọc phí visa/XKLĐ", ScamStage.STAGE_3_URGENCY)
        val s4 = StateNode("MONEY_ABROAD", "Chuyển tiền ra nước ngoài", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_VISA_01",
            name = "Visa/Xuất khẩu lao động",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3, s4.id to s4),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("visa", "xuất khẩu lao động", "đi hàn quốc", "bao đậu", "đi nhật"), s1.id, ScamIntent.IMMIGRATION_VISA_SCAM)
                ),
                s1.id to listOf(
                    Transition(listOf("lương cao", "cam kết", "đảm bảo", "công ty phái cử", "hợp đồng"), s2.id, ScamIntent.IMMIGRATION_VISA_SCAM)
                ),
                s2.id to listOf(
                    Transition(listOf("đặt cọc", "phí hồ sơ", "phí visa", "chuyển trước"), s3.id, ScamIntent.IMMIGRATION_VISA_SCAM)
                ),
                s3.id to listOf(
                    Transition(listOf("chuyển tiền", "western union", "tài khoản nước ngoài", "phí bổ sung"), s4.id, ScamIntent.IMMIGRATION_VISA_SCAM)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 17. DELIVERY_COD ===
    private fun buildDeliveryCodGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("SHIPPER_INTRO", "Giao hàng COD", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("PAY_TRAP", "Thanh toán nợ cũ", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_SHIP_01",
            name = "Shipper giả/Giao hàng nợ",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("shipper", "giao hàng", "đơn hàng", "thanh toán cod"), s1.id, ScamIntent.DELIVERY_COD)
                ),
                s1.id to listOf(
                    Transition(listOf("nợ tiền hàng", "chuyển khoản trước", "đã đặt"), s2.id, ScamIntent.DELIVERY_COD)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 18. FAKE_SUBSCRIPTION === [C3 EXPANDED]
    private fun buildFakeSubscriptionGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("SUB_THREAT", "Thông báo trừ phí dịch vụ", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("CANCEL_URGENCY", "Hủy gấp trước khi bị trừ thêm", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("CLICK_LINK", "Yêu cầu click link hủy dịch vụ", ScamStage.STAGE_3_URGENCY)
        val s4 = StateNode("CARD_STEAL", "Nhập thông tin thẻ/OTP", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_SUB_01",
            name = "Trừ tiền dịch vụ ảo",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3, s4.id to s4),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("trừ tiền", "gia hạn", "dịch vụ", "đăng ký", "gói vip"), s1.id, ScamIntent.FAKE_SUBSCRIPTION)
                ),
                s1.id to listOf(
                    Transition(listOf("hủy ngay", "trước khi bị trừ", "tự động gia hạn", "mất tiền"), s2.id, ScamIntent.FAKE_SUBSCRIPTION)
                ),
                s2.id to listOf(
                    Transition(listOf("bấm vào link", "truy cập link", "hủy tại đây", "vào trang web"), s3.id, ScamIntent.FAKE_SUBSCRIPTION)
                ),
                s3.id to listOf(
                    Transition(listOf("số thẻ", "nhập mã otp", "mật khẩu", "xác nhận thẻ"), s4.id, ScamIntent.BANK_CARD_FRAUD)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 20. RECOVERY_SCAM === [C3 EXPANDED]
    private fun buildRecoveryScamGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("RECOVERY_BAIT", "Hứa lấy lại tiền", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("PROVE_LEGIT", "Chứng minh khả năng thu hồi", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("DEPOSIT_FEE", "Đặt cọc phí hỗ trợ", ScamStage.STAGE_3_URGENCY)
        val s4 = StateNode("BANKING_ACCESS", "Yêu cầu cung cấp app banking", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_RECOVERY_01",
            name = "Dịch vụ lấy lại tiền lừa đảo",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3, s4.id to s4),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("lấy lại tiền", "thu hồi", "luật sư", "cảnh sát mạng", "hỗ trợ nạn nhân"), s1.id, ScamIntent.RECOVERY_SCAM)
                ),
                s1.id to listOf(
                    Transition(listOf("đã thu hồi", "thành công", "chuyên xử lý", "có bằng chứng"), s2.id, ScamIntent.RECOVERY_SCAM)
                ),
                s2.id to listOf(
                    Transition(listOf("đặt cọc", "phí hỗ trợ", "phí luật sư", "chuyển phí trước"), s3.id, ScamIntent.RECOVERY_SCAM)
                ),
                s3.id to listOf(
                    Transition(listOf("đăng nhập banking", "cung cấp tài khoản", "chia sẻ màn hình", "mã otp"), s4.id, ScamIntent.BANK_CARD_FRAUD)
                )
            ),
            initialStateId = s0.id
        )
    }

    // === 21. GENERIC_SCAM === [C3 EXPANDED]
    private fun buildGenericScamGraph(): ScenarioGraph {
        val s0 = StateNode("START", "Initial State", ScamStage.STAGE_1_INTRODUCTION)
        val s1 = StateNode("SUSPICIOUS_BAIT", "Dấu hiệu nghi vấn", ScamStage.STAGE_1_INTRODUCTION)
        val s2 = StateNode("TRUST_BUILD", "Tạo niềm tin giả", ScamStage.STAGE_2_BAITING_THREAT)
        val s3 = StateNode("MONEY_REQUEST", "Yêu cầu chuyển tiền", ScamStage.STAGE_3_URGENCY)
        val s4 = StateNode("URGENCY_FORCE", "Ép buộc khẩn cấp", ScamStage.STAGE_4_COMMAND)

        return ScenarioGraph(
            graphId = "G_GENERIC_01",
            name = "Lừa đảo không rõ kịch bản",
            states = mapOf(s0.id to s0, s1.id to s1, s2.id to s2, s3.id to s3, s4.id to s4),
            transitions = mapOf(
                s0.id to listOf(
                    Transition(listOf("nghe đây", "có chuyện này", "ưu đãi", "bí mật", "nghe nè"), s1.id, ScamIntent.GENERIC_SCAM)
                ),
                s1.id to listOf(
                    Transition(listOf("tin tôi đi", "cam kết", "đảm bảo", "có người giới thiệu"), s2.id, ScamIntent.GENERIC_SCAM)
                ),
                s2.id to listOf(
                    Transition(listOf("chuyển tiền", "nạp tiền", "đặt cọc", "thanh toán"), s3.id, ScamIntent.GENERIC_SCAM)
                ),
                s3.id to listOf(
                    Transition(listOf("ngay bây giờ", "trong vòng", "hết hạn", "mất cơ hội"), s4.id, ScamIntent.GENERIC_SCAM)
                )
            ),
            initialStateId = s0.id
        )
    }
}
