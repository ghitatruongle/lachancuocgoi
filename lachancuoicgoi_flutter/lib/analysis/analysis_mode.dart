enum AnalysisMode {
  normal,
  gDetection,
  geminiApi;

  String get storageName {
    return switch (this) {
      AnalysisMode.normal => 'NORMAL',
      AnalysisMode.gDetection => 'GDetection',
      AnalysisMode.geminiApi => 'GEMINI_API',
    };
  }

  String get title {
    return switch (this) {
      AnalysisMode.normal => 'Cấp 1: Cơ bản',
      AnalysisMode.gDetection => 'Cấp 2: Nâng cao',
      AnalysisMode.geminiApi => 'Cấp 3: AI',
    };
  }

  String get description {
    return switch (this) {
      AnalysisMode.normal => 'Phân tích nhanh dựa trên từ khóa.',
      AnalysisMode.gDetection => 'Phân tích chủ đề lừa đảo nâng cao.',
      AnalysisMode.geminiApi => 'Phân tích bằng AI trực tuyến.',
    };
  }
}

extension AnalysisModeX on AnalysisMode {
  static AnalysisMode fromName(
    String? value, {
    AnalysisMode fallback = AnalysisMode.gDetection,
  }) {
    return switch (value?.trim()) {
      'NORMAL' => AnalysisMode.normal,
      'GDetection' => AnalysisMode.gDetection,
      'GEMINI_API' => AnalysisMode.geminiApi,
      'normal' => AnalysisMode.normal,
      'gDetection' => AnalysisMode.gDetection,
      'geminiApi' => AnalysisMode.geminiApi,
      _ => fallback,
    };
  }
}
