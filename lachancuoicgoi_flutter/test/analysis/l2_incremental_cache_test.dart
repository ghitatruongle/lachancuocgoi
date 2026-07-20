import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  group('L2Analyzer incremental early-exit', () {
    test(
      'short risk-free delta still runs GDetection (fullText always re-analyzed)',
      () async {
        final engine = _CountingGDetectionEngine();
        final analyzer = _newAnalyzer(engine);
        await analyzer.initialize();

        const firstText = 'xin chào đây là cuộc gọi kiểm tra bình thường';
        final first = await analyzer.analyze(firstText, firstText);
        expect(first.overallRiskLevel, RiskLevel.green);
        expect(engine.callCount, 1);

        // Full text is extended; GDetection always re-runs on the full text
        // to avoid false negatives from skipping keywords in the delta.
        const secondText = '$firstText ừ ạ';
        final second = await analyzer.analyze(' ừ ạ', secondText);
        expect(second.overallRiskLevel, RiskLevel.green);
        expect(engine.callCount, 2);
      },
    );

    test('short delta containing OTP still re-runs GDetection', () async {
      final engine = _CountingGDetectionEngine();
      final analyzer = _newAnalyzer(engine);
      await analyzer.initialize();

      const firstText = 'xin chào đây là cuộc gọi kiểm tra bình thường';
      await analyzer.analyze(firstText, firstText);
      expect(engine.callCount, 1);

      const safeDelta = ' ừ ạ';
      await analyzer.analyze(safeDelta, '$firstText$safeDelta');
      expect(engine.callCount, 2);

      const riskyDelta = ' mã OTP';
      final result = await analyzer.analyze(
        riskyDelta,
        '$firstText$safeDelta$riskyDelta',
      );

      expect(engine.callCount, 3);
      expect(result.overallRiskLevel, RiskLevel.red);
    });
  });
}

L2Analyzer _newAnalyzer(GDetectionEngine engine) {
  return L2Analyzer(
    gDetectionEngine: engine,
    intentClassifier: const DisabledIntentClassifier(),
    wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
  );
}

class _CountingGDetectionEngine extends GDetectionEngine {
  int callCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => true;

  @override
  Future<GResult> performFullAnalysis(String text) async {
    callCount++;
    if (text.toLowerCase().contains('otp')) {
      return GResult(
        riskLevel: RiskLevel.red,
        reason: 'OTP detected',
        allMatchedKeywords: <KeywordMatch>{
          const KeywordMatch(
            keyword: 'OTP',
            level: RiskLevel.red,
            category: 'Eval',
          ),
        },
        alertEnabled: true,
      );
    }
    return const GResult(
      riskLevel: RiskLevel.green,
      reason: 'green',
      allMatchedKeywords: <KeywordMatch>{},
      alertEnabled: false,
    );
  }
}
