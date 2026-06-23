import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

class ManualMockGDetectionEngine implements GDetectionEngine {
  int activeAnalyses = 0;
  int maxConcurrentAnalyses = 0;
  bool _isReady = true;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> initialize() async {
    _isReady = true;
  }

  @override
  void reset() {}

  @override
  void onMemoryPressure() {}

  @override
  void dispose() {}

  @override
  Future<GResult> performFullAnalysis(String text) async {
    activeAnalyses++;
    if (activeAnalyses > maxConcurrentAnalyses) {
      maxConcurrentAnalyses = activeAnalyses;
    }
    // Simulate some work that takes time
    await Future<void>.delayed(const Duration(milliseconds: 100));
    activeAnalyses--;
    return const GResult(riskLevel: RiskLevel.green, reason: 'OK');
  }

  @override
  void setAssetProvider(GDetectionAssetProvider provider) {}

  @override
  double calculateContextScore(Set<dynamic> matches, int totalTokens) => 0.0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('L2Analyzer - should run analyses sequentially even if triggered concurrently', (tester) async {
    final mockEngine = ManualMockGDetectionEngine();
    final analyzer = L2Analyzer(gDetectionEngine: mockEngine);

    // Fire 3 analyses concurrently
    final futures = [
      analyzer.analyze('text 1', 'full text 1'),
      analyzer.analyze('text 2', 'full text 2'),
      analyzer.analyze('text 3', 'full text 3'),
    ];

    // Pump sequentially to let each analysis's delay complete
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    await Future.wait(futures);

    // If the lock works perfectly, maxConcurrentAnalyses should be 1.
    expect(mockEngine.maxConcurrentAnalyses, 1, reason: 'Analyses should not run concurrently');
  });
}
