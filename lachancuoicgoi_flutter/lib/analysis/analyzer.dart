import 'analysis_level.dart';
import 'analysis_result.dart';
import 'health_check.dart';

/// Interface cho tất cả analysis levels (L1, L2, L3).
///
/// Contract:
/// - [initialize] — phải gọi trước khi analyze. Idempotent.
/// - [isReady] — true sau khi initialize thành công.
/// - [resetSession] — reset internal state (processedTextLength, lastResult).
/// - [syncProcessedTextLength] — set _processedTextLength về giá trị tuyệt đối.
/// - [lastResult] — kết quả của lần analyze gần nhất.
/// - [processedTextLength] — số ký tự đã được xử lý (tính từ đầu transcript).
abstract interface class Analyzer implements HealthCheckable {
  AnalysisLevel get level;

  /// Initialize the analyzer. Idempotent — multiple calls are safe.
  Future<void> initialize();

  /// True after [initialize] completes successfully.
  bool get isReady;

  /// Reset session state: processedTextLength, lastResult, internal caches.
  void resetSession();

  /// Number of characters already processed from the transcript.
  int get processedTextLength;

  /// Override processedTextLength to an absolute value.
  /// Negative values are clamped to 0.
  void syncProcessedTextLength(int length);

  /// Result of the most recent analyze() or analyzeStream() call.
  AnalysisResult get lastResult;
}
