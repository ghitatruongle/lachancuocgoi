import 'analysis_level.dart';
import 'analysis_result.dart';
import 'health_check.dart';

abstract interface class Analyzer implements HealthCheckable {
  AnalysisLevel get level;

  Future<void> initialize();

  bool get isReady;

  void resetSession();

  int get processedTextLength;

  void syncProcessedTextLength(int length);

  AnalysisResult get lastResult;
}
