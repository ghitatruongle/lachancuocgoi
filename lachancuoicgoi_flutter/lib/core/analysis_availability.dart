/// Whether a monitoring session has enough trustworthy data to present a
/// risk assessment.
///
/// This is deliberately separate from `RiskLevel`: green means that an
/// analysis found no concerning signal, while [pending], [noAudio],
/// [sttUnavailable], and [interrupted] mean that no reliable conclusion can
/// be drawn yet.
enum AnalysisAvailability {
  pending,
  sufficient,
  noAudio,
  sttUnavailable,
  interrupted;

  /// Builds the availability shown for a persisted call-history record.
  ///
  /// [recordingError] uses the existing database wire values. Unknown error
  /// values are treated conservatively as interrupted results.
  static AnalysisAvailability fromStoredSession({
    required String? recordingError,
    required bool hasTranscript,
    required bool analysisCompleted,
  }) {
    switch (recordingError) {
      case 'noAudio':
        return AnalysisAvailability.noAudio;
      case 'sttFailed':
        return AnalysisAvailability.sttUnavailable;
      case 'killed':
      case 'partial':
        return AnalysisAvailability.interrupted;
      case null:
      case '':
        break;
      default:
        return AnalysisAvailability.interrupted;
    }

    if (!hasTranscript) return AnalysisAvailability.noAudio;
    if (!analysisCompleted) return AnalysisAvailability.interrupted;
    return AnalysisAvailability.sufficient;
  }

  bool get canShowRisk => this == AnalysisAvailability.sufficient;

  String get vietnameseName => switch (this) {
    AnalysisAvailability.pending => 'Chưa đủ dữ liệu',
    AnalysisAvailability.sufficient => 'Đã đủ dữ liệu',
    AnalysisAvailability.noAudio => 'Không thu được âm thanh',
    AnalysisAvailability.sttUnavailable => 'Không nhận diện được giọng nói',
    AnalysisAvailability.interrupted => 'Kết quả chưa hoàn chỉnh',
  };

  String get guidance => switch (this) {
    AnalysisAvailability.pending =>
      'Hãy tiếp tục cuộc gọi để ứng dụng có đủ dữ liệu phân tích.',
    AnalysisAvailability.sufficient => '',
    AnalysisAvailability.noAudio =>
      'Hãy kiểm tra quyền micro, nguồn âm thanh hoặc loa ngoài rồi thử lại.',
    AnalysisAvailability.sttUnavailable =>
      'Hãy kiểm tra micro, nói rõ hơn hoặc thử lại sau.',
    AnalysisAvailability.interrupted =>
      'Phiên đã bị gián đoạn. Hãy thực hiện lại để có kết quả đầy đủ.',
  };
}
