import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class PlatformCapabilities {
  const PlatformCapabilities({
    required this.isAndroid,
    required this.realCallMonitoring,
    required this.offlineVosk,
    required this.systemOverlays,
    required this.callScreening,
    required this.accessibilityCaptions,
    required this.persistentHistory,
    required this.isDemoMode,
  });

  final bool isAndroid;
  final bool realCallMonitoring;
  final bool offlineVosk;
  final bool systemOverlays;
  final bool callScreening;
  final bool accessibilityCaptions;
  final bool persistentHistory;
  final bool isDemoMode;

  static PlatformCapabilities get current {
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return PlatformCapabilities(
      isAndroid: android,
      realCallMonitoring: android,
      offlineVosk: android,
      systemOverlays: android,
      callScreening: android,
      accessibilityCaptions: android,

      persistentHistory: !kIsWeb,
      isDemoMode: !android,
    );
  }

  List<({String label, bool supported})> get featureMatrix => [
    (label: 'Giám sát cuộc gọi thật', supported: realCallMonitoring),
    (label: 'STT offline (Vosk)', supported: offlineVosk),
    (label: 'Cảnh báo overlay hệ thống', supported: systemOverlays),
    (label: 'Call screening', supported: callScreening),
    (label: 'Phân tích AI L1–L3', supported: true),
    (label: 'Lịch sử lưu bền', supported: persistentHistory),
  ];
}
