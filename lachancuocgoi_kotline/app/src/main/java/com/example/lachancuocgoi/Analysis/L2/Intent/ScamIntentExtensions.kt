package com.example.lachancuocgoi.Analysis.L2.Intent

import com.example.lachancuocgoi.RiskLevel

/**
 * Tiện ích hỗ trợ ánh xạ từ nhãn AI (ScamIntent) sang ngôn ngữ hiển thị và mức độ rủi ro.
 */
fun ScamIntent.getDisplayName(): String {
    return when (this) {
        ScamIntent.AUTH_POLICE_LAWSUIT -> "Giả danh Công an/Tòa án"
        ScamIntent.TAX_GOV_APP -> "Lừa đảo Thuế/VNeID giả"
        ScamIntent.TELECOM_LOCK -> "Dọa khóa SIM viễn thông"
        ScamIntent.TECH_SUPPORT_HIJACK -> "Hỗ trợ kỹ thuật giả mạo"
        ScamIntent.HOSPITAL_EMERGENCY -> "Cấp cứu/Tai nạn giả"
        ScamIntent.VIRTUAL_KIDNAPPING -> "Bắt cóc ảo/Tống tiền"
        ScamIntent.CEO_FRAUD_B2B -> "Giả danh Lãnh đạo/Đồng nghiệp"
        ScamIntent.SOCIAL_DEEPFAKE_LOAN -> "Deepfake mượn tiền (Người quen)"
        ScamIntent.ROMANCE_SCAM -> "Lừa tình/Bưu kiện hải quan"
        ScamIntent.SEXTORTION_BLACKMAIL -> "Tống tiền ảnh nhạy cảm"
        ScamIntent.CHARITY_DONATION -> "Từ thiện ảo/Kêu góp giả"
        ScamIntent.INVESTMENT_SCAM -> "Đầu tư tài chính/Sàn ảo"
        ScamIntent.JOB_TASK_SCAM -> "Việc làm online/Chốt đơn"
        ScamIntent.GIFT_LOTTERY -> "Trúng thưởng/Quà tặng tri ân"
        ScamIntent.GAMBLING_PREDICTION -> "Soi cầu/Lô đề"
        ScamIntent.IMMIGRATION_VISA_SCAM -> "Visa/Xuất khẩu lao động"
        ScamIntent.BANK_CARD_FRAUD -> "Ngân hàng giả mạo/Phishing"
        ScamIntent.DELIVERY_COD -> "Shipper giả/Nợ tiền hàng"
        ScamIntent.FAKE_SUBSCRIPTION -> "Trừ tiền dịch vụ tự động"
        ScamIntent.BLACK_CREDIT_TERROR -> "Tín dụng đen/Đòi nợ thuê"
        ScamIntent.RECOVERY_SCAM -> "Dịch vụ lấy lại tiền bị lừa"
        ScamIntent.GENERIC_SCAM -> "Dấu hiệu lừa đảo chung"
        ScamIntent.SAFE -> "Giao tiếp bình thường"
    }
}

fun ScamIntent.getDescription(): String {
    return when (this) {
        ScamIntent.AUTH_POLICE_LAWSUIT -> "Đối tượng giả danh cơ quan pháp luật để đe dọa và yêu cầu chuyển tiền điều tra."
        ScamIntent.TAX_GOV_APP -> "Yêu cầu cài đặt ứng dụng giả mạo (VNeID, Thuế) để chiếm quyền điều khiển điện thoại."
        ScamIntent.TELECOM_LOCK -> "Dọa khóa SIM để ép buộc cung cấp thông tin cá nhân hoặc làm theo hướng dẫn."
        ScamIntent.TECH_SUPPORT_HIJACK -> "Giả danh nhân viên hỗ trợ Zalo/FB để lừa lấy mã OTP hoặc quyền truy cập tài khoản."
        ScamIntent.HOSPITAL_EMERGENCY -> "Đánh vào tâm lý lo lắng cho người thân gặp nạn để yêu cầu chuyển tiền viện phí gấp."
        ScamIntent.VIRTUAL_KIDNAPPING -> "Tạo hiện trường bắt cóc giả để tống tiền người thân trong tình trạng hoảng loạn."
        ScamIntent.CEO_FRAUD_B2B -> "Mạo danh cấp trên yêu cầu chuyển khoản khẩn cấp cho đối tác hoặc công việc."
        ScamIntent.SOCIAL_DEEPFAKE_LOAN -> "Sử dụng công nghệ AI giả giọng nói/hình ảnh người quen để vay tiền kẹt."
        ScamIntent.ROMANCE_SCAM -> "Tán tỉnh qua mạng rồi nhờ thanh toán phí vận chuyển quà tặng giá trị cao bị kẹt."
        ScamIntent.SEXTORTION_BLACKMAIL -> "Sử dụng hình ảnh nhạy cảm (cắt ghép hoặc thật) để uy hiếp đòi tiền."
        ScamIntent.CHARITY_DONATION -> "Lợi dụng lòng tốt để kêu gọi ủng hộ các hoàn cảnh khó khăn không có thật."
        ScamIntent.INVESTMENT_SCAM -> "Hứa hẹn lợi nhuận cực cao từ sàn chứng khoán, tiền ảo nhằm chiếm đoạt vốn nạp."
        ScamIntent.JOB_TASK_SCAM -> "Mồi chài việc nhẹ lương cao, yêu cầu nạp tiền chốt đơn để nhận hoa hồng ảo."
        ScamIntent.GIFT_LOTTERY -> "Thông báo trúng thưởng lớn và yêu cầu đóng phí trước khi nhận giải."
        ScamIntent.GAMBLING_PREDICTION -> "Gạ gẫm mua số lô đề 'chuẩn' hoặc tham gia đánh bạc trực tuyến."
        ScamIntent.IMMIGRATION_VISA_SCAM -> "Cam kết bao đậu visa hoặc đi lao động nước ngoài với chi phí rẻ bất ngờ."
        ScamIntent.BANK_CARD_FRAUD -> "Gửi link giả mạo ngân hàng yêu cầu nhập mật khẩu và OTP để đánh cắp tiền."
        ScamIntent.DELIVERY_COD -> "Giả shipper giao hàng chưa đặt hoặc yêu cầu thanh toán lại đơn đã trả tiền."
        ScamIntent.FAKE_SUBSCRIPTION -> "Thông báo bạn đang bị trừ tiền dịch vụ lạ và dụ dỗ click link để hủy."
        ScamIntent.BLACK_CREDIT_TERROR -> "Đòi nợ với thái độ hung hãn, đe dọa khủng bố tinh thần bạn và người thân."
        ScamIntent.RECOVERY_SCAM -> "Giả danh luật sư/công an hứa hẹn lấy lại tiền đã bị lừa để lừa thêm lần nữa."
        ScamIntent.GENERIC_SCAM -> "Sử dụng các thủ đoạn kịch bản chưa rõ ràng nhưng có dấu hiệu lừa đảo cao."
        ScamIntent.SAFE -> "Nội dung cuộc trò chuyện bình thường, không thấy dấu hiệu rủi ro."
    }
}

fun ScamIntent.getRiskLevel(): RiskLevel {
    return when (this) {
        ScamIntent.SAFE -> RiskLevel.GREEN
        // YELLOW: Các loại lừa đảo có dấu hiệu nhẹ, khó xác nhận ngay
        ScamIntent.CHARITY_DONATION -> RiskLevel.YELLOW
        ScamIntent.GIFT_LOTTERY -> RiskLevel.YELLOW
        ScamIntent.FAKE_SUBSCRIPTION -> RiskLevel.YELLOW
        ScamIntent.GENERIC_SCAM -> RiskLevel.YELLOW
        // ORANGE: Các loại lừa đảo có nguy cơ rõ ràng nhưng cần thêm ngữ cảnh
        ScamIntent.INVESTMENT_SCAM -> RiskLevel.ORANGE
        ScamIntent.JOB_TASK_SCAM -> RiskLevel.ORANGE
        ScamIntent.ROMANCE_SCAM -> RiskLevel.ORANGE
        ScamIntent.IMMIGRATION_VISA_SCAM -> RiskLevel.ORANGE
        ScamIntent.DELIVERY_COD -> RiskLevel.ORANGE
        ScamIntent.RECOVERY_SCAM -> RiskLevel.ORANGE
        ScamIntent.GAMBLING_PREDICTION -> RiskLevel.ORANGE
        ScamIntent.CEO_FRAUD_B2B -> RiskLevel.ORANGE
        ScamIntent.SOCIAL_DEEPFAKE_LOAN -> RiskLevel.ORANGE
        // RED: Các loại lừa đảo nghiêm trọng, đe dọa trực tiếp
        ScamIntent.AUTH_POLICE_LAWSUIT -> RiskLevel.RED
        ScamIntent.TAX_GOV_APP -> RiskLevel.RED
        ScamIntent.TELECOM_LOCK -> RiskLevel.RED
        ScamIntent.TECH_SUPPORT_HIJACK -> RiskLevel.RED
        ScamIntent.HOSPITAL_EMERGENCY -> RiskLevel.RED
        ScamIntent.VIRTUAL_KIDNAPPING -> RiskLevel.RED
        ScamIntent.SEXTORTION_BLACKMAIL -> RiskLevel.RED
        ScamIntent.BANK_CARD_FRAUD -> RiskLevel.RED
        ScamIntent.BLACK_CREDIT_TERROR -> RiskLevel.RED
    }
}

fun ScamIntent.getRiskLevel(confidence: Float): RiskLevel {
    val baseLevel = getRiskLevel()
    if (this == ScamIntent.SAFE || confidence >= 0.85f) {
        return baseLevel
    }
    return when {
        confidence >= 0.70f -> baseLevel
        confidence >= 0.50f -> baseLevel.deescalate()
        else -> baseLevel.deescalate().deescalate().coerceAtLeast(RiskLevel.YELLOW)
    }
}
