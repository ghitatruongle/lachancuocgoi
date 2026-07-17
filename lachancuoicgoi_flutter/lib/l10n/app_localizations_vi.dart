// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Lá chắn cuộc gọi';

  @override
  String get settings => 'Cài đặt';

  @override
  String get permissions => 'Quyền';

  @override
  String get instructions => 'Hướng dẫn';

  @override
  String get homeSubtitle =>
      'Phân tích cuộc gọi theo thời gian thực để phát hiện lừa đảo.';

  @override
  String get homeLiveCaptionTip =>
      'Khuyên dùng: Bật Phụ đề trực tiếp để bảo vệ tốt nhất';

  @override
  String get appInfoSemantic => 'Thông tin ứng dụng Lá chắn cuộc gọi';

  @override
  String get startMonitoring => 'Bắt đầu giám sát';

  @override
  String get startMonitoringSemantic => 'Bắt đầu giám sát cuộc gọi';

  @override
  String get simulationMode => 'Chế độ giả lập';

  @override
  String get history => 'Lịch sử';

  @override
  String get antiScamTips => 'Mẹo chống lừa đảo';

  @override
  String get homePermissionWarning =>
      'Một số quyền chưa được cấp — hiệu quả giám sát có thể bị giảm.';

  @override
  String get demoMode => 'Chế độ demo';

  @override
  String get demoModeDescription =>
      'Nền tảng này không gắn cuộc gọi thật. App chạy kịch bản giả để thử AI. Bản đầy đủ (STT, overlay, call screening) trên Android.';

  @override
  String get demoModeSemantic => 'Chế độ demo — không gắn cuộc gọi thật';

  @override
  String get featuresOnThisDevice => 'Tính năng trên máy này';

  @override
  String get monitoringSubtitle => 'Phát hiện Lừa đảo & Bạo lực';

  @override
  String get monitoringEndCall => 'Kết thúc cuộc gọi';

  @override
  String get monitoringSavingResult => 'Đang lưu kết quả...';

  @override
  String get monitoringEndCallSemantic => 'Kết thúc cuộc gọi và lưu kết quả';

  @override
  String get monitoringLiveConversation => 'Cuộc hội thoại trực tiếp';

  @override
  String get monitoringSimulationTranscript => 'Kịch bản mô phỏng';

  @override
  String get monitoringSystemLog => 'Nhật ký hệ thống';

  @override
  String monitoringSimulationPrefix(String title) {
    return 'Mô phỏng: $title';
  }

  @override
  String get monitoringSimulationDefault => 'Mô phỏng';

  @override
  String monitoringRiskSemantic(String level) {
    return 'Mức độ rủi ro cuộc gọi hiện tại: $level';
  }

  @override
  String get monitoringWaveformSemantic =>
      'Biểu đồ sóng âm thanh cuộc gọi trực tiếp';

  @override
  String monitoringModeTarget(String mode) {
    return 'Đích: $mode';
  }

  @override
  String monitoringModeRunning(String mode) {
    return 'Chạy: $mode';
  }

  @override
  String get monitoringNetworkOk => 'Mạng: OK';

  @override
  String get monitoringNetworkError => 'Mạng: Lỗi';

  @override
  String get monitoringSttFatal =>
      'Mic/STT lỗi — không nghe được giọng nói. Kiểm tra quyền micro và thử lại.';

  @override
  String monitoringSttFatalWithReason(String reason) {
    return 'Mic/STT lỗi — không nghe được giọng nói ($reason). Kiểm tra quyền micro và thử lại.';
  }

  @override
  String get monitoringNotificationDegraded =>
      'Bật thông báo để giám sát ổn định. Android có thể tắt app giữa cuộc gọi nếu thiếu quyền thông báo.';

  @override
  String get monitoringWatchdogFailed =>
      'Không khôi phục được dịch vụ giám sát nền. Hãy dừng và bắt đầu lại phiên.';

  @override
  String get monitoringSttFallbackOffline =>
      'STT đã chuyển sang chế độ offline (Vosk)';

  @override
  String monitoringSttFallbackWithReason(String reason) {
    return 'STT offline (Vosk): $reason';
  }

  @override
  String get riskLevelLabel => 'Mức độ rủi ro';

  @override
  String get warningDismissButton => 'ĐÃ HIỂU';

  @override
  String get warningRedTitle => 'NGUY HIỂM';

  @override
  String get warningOrangeTitle => 'NGUY CƠ';
}
