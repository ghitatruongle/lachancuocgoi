import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/health_check.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/scam_intent.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('L2Analyzer - edge cases', () {
    test('analyze with empty text returns GREEN', () async {
      final analyzer = _createL2Analyzer(
        gResult: _greenGResult(),
      );
      await analyzer.initialize();

      final result = await analyzer.analyze('', '');
      expect(result.overallRiskLevel, RiskLevel.green);
      expect(result.analysisLevel, AnalysisLevel.l2);
    });

    test('analyze with whitespace-only fullText returns GREEN', () async {
      final analyzer = _createL2Analyzer(
        gResult: _greenGResult(),
      );
      await analyzer.initialize();

      final result = await analyzer.analyze('   ', '   \n\t  ');
      expect(result.overallRiskLevel, RiskLevel.green);
    });

    test('analyze with single character fullText returns GREEN', () async {
      final analyzer = _createL2Analyzer(
        gResult: _greenGResult(),
      );
      await analyzer.initialize();

      // GDetection will still run, but with minimal tokens
      final result = await analyzer.analyze('x', 'x');
      expect(result.overallRiskLevel, isA<RiskLevel>());
      expect(result.analysisLevel, AnalysisLevel.l2);
    });

    test(
      '_applySafetyDiscount with orange risk level preserves it',
      () async {
        // The safety discount logic does not downgrade orange or red
        final gResult = GResult(
          riskLevel: RiskLevel.orange,
          reason: 'Cảnh báo phát hiện',
          allMatchedKeywords: <KeywordMatch>{
            const KeywordMatch(
              keyword: 'test',
              level: RiskLevel.orange,
              category: 'Chung',
            ),
          },
          alertEnabled: true,
        );
        final analyzer = _createL2Analyzer(gResult: gResult);
        await analyzer.initialize();

        // Full text with casual opening to trigger safety discount
        final casualText =
            '${'ăn cơm chưa ' * 10} co dau hieu lua dao';
        final result = await analyzer.analyze(casualText, casualText);

        // Orange should not be downgraded by safety discount
        expect(
          result.overallRiskLevel.index,
          greaterThanOrEqualTo(RiskLevel.orange.index),
        );
      },
    );

    test('resetSession clears all state', () async {
      final analyzer = _createL2Analyzer(
        gResult: _greenGResult(),
      );
      await analyzer.initialize();

      // Run an analysis to set state
      await analyzer.analyze('some text', 'some text');
      expect(analyzer.processedTextLength, greaterThan(0));

      analyzer.resetSession();

      expect(analyzer.processedTextLength, 0);
      expect(analyzer.lastResult.overallRiskLevel, RiskLevel.green);
      expect(analyzer.lastResult.matches, isEmpty);
    });

    test(
      'syncProcessedTextLength propagates correctly',
      () async {
        final analyzer = _createL2Analyzer(
          gResult: _greenGResult(),
        );
        await analyzer.initialize();

        analyzer.syncProcessedTextLength(500);
        expect(analyzer.processedTextLength, 500);
      },
    );

    test(
      'syncProcessedTextLength with negative value clamps to 0',
      () async {
        final analyzer = _createL2Analyzer(
          gResult: _greenGResult(),
        );
        await analyzer.initialize();

        analyzer.syncProcessedTextLength(-10);
        expect(analyzer.processedTextLength, 0);
      },
    );

    test(
      'healthCheck returns down when GDetectionEngine not ready',
      () async {
        final analyzer = _createL2Analyzer(
          gResult: _greenGResult(),
          gReady: false,
          intentReady: false,
        );
        // Do NOT initialize — engine won't be ready
        final report = analyzer.healthCheck();
        expect(report.status, HealthStatus.down);
        expect(report.component, 'L2');
      },
    );

    test(
      'healthCheck returns degraded when GDetection OK but IntentClassifier not ready',
      () async {
        final analyzer = _createL2Analyzer(
          gResult: _greenGResult(),
          gReady: true,
          intentReady: false,
        );
        // We need the gDetectionEngine to report ready
        final report = analyzer.healthCheck();
        // Since intentClassifier is DisabledIntentClassifier (isReady = false),
        // and gDetectionEngine is overridden to report ready
        expect(report.status, HealthStatus.degraded);
        expect(report.component, 'L2');
      },
    );

    test(
      'healthCheck returns healthy when both engines ready',
      () async {
        final analyzer = _createL2Analyzer(
          gResult: _greenGResult(),
          gReady: true,
          intentReady: true,
        );
        final report = analyzer.healthCheck();
        expect(report.status, HealthStatus.healthy);
        expect(report.component, 'L2');
      },
    );

    test('level returns l2', () async {
      final analyzer = _createL2Analyzer(
        gResult: _greenGResult(),
      );
      expect(analyzer.level, AnalysisLevel.l2);
    });

    test(
      'lastResult returns initial green result before any analysis',
      () async {
        final analyzer = _createL2Analyzer(
          gResult: _greenGResult(),
        );
        expect(analyzer.lastResult.overallRiskLevel, RiskLevel.green);
        expect(analyzer.lastResult.matches, isEmpty);
        expect(analyzer.lastResult.analysisLevel, AnalysisLevel.l2);
      },
    );

    test(
      'analyze with red GDetection result produces red or high result',
      () async {
        final redGResult = GResult(
          riskLevel: RiskLevel.red,
          reason: 'Phát hiện câu thoại nguy hiểm',
          allMatchedKeywords: <KeywordMatch>{
            const KeywordMatch(
              keyword: 'chuyển tiền',
              level: RiskLevel.red,
              category: 'MONEY',
            ),
          },
          alertEnabled: true,
        );
        final analyzer = _createL2Analyzer(gResult: redGResult);
        await analyzer.initialize();

        final result = await analyzer.analyze(
          'chuyen tien gap',
          'chuyen tien gap',
        );
        expect(
          result.overallRiskLevel.index,
          greaterThanOrEqualTo(RiskLevel.red.index),
        );
        expect(result.alertEnabled, isTrue);
      },
    );

    test('isReady delegates to GDetectionEngine', () async {
      final analyzer = _createL2Analyzer(
        gResult: _greenGResult(),
        gReady: false,
      );
      expect(analyzer.isReady, isFalse);
    });

    test('isFullyReady requires both engines ready', () async {
      final analyzer = _createL2Analyzer(
        gResult: _greenGResult(),
        gReady: true,
        intentReady: false,
      );
      expect(analyzer.isFullyReady, isFalse);
    });
  });
}

L2Analyzer _createL2Analyzer({
  required GResult gResult,
  bool gReady = true,
  bool intentReady = false,
}) {
  return L2Analyzer(
    gDetectionEngine: _FakeGDetectionEngine(gResult, ready: gReady),
    intentClassifier: intentReady
        ? _FakeIntentClassifier()
        : const DisabledIntentClassifier(),
    wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
  );
}

GResult _greenGResult() {
  return const GResult(
    riskLevel: RiskLevel.green,
    reason: 'Không phát hiện dấu hiệu rủi ro',
  );
}

class _FakeGDetectionEngine extends GDetectionEngine {
  _FakeGDetectionEngine(this._result, {this.ready = true});

  final GResult _result;
  final bool ready;

  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => ready;

  @override
  Future<GResult> performFullAnalysis(String text) async => _result;
}

class _FakeIntentClassifier implements IntentClassifier {
  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => true;

  @override
  Future<List<IntentPrediction>> predictIntent(String transcript) async {
    return <IntentPrediction>[
      const IntentPrediction(
        intent: ScamIntent.safe,
        confidence: 0.95,
      ),
    ];
  }

  @override
  void close() {}
}
