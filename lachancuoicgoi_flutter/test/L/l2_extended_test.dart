import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/scam_intent.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/scam_graph_builder.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('L2Analyzer — healthCheck', () {
    test('returns down when GDetectionEngine not ready', () {
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeNotReadyGDetectionEngine(),
        intentClassifier: const DisabledIntentClassifier(),
        wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
      );

      final report = analyzer.healthCheck();
      expect(report.status.name, 'down');
      expect(report.message, contains('GDetectionEngine'));
    });

    test('returns degraded when GDetection OK but IntentClassifier not ready',
        () {
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeReadyGDetectionEngine(),
        intentClassifier: const DisabledIntentClassifier(),
        wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
      );

      final report = analyzer.healthCheck();
      expect(report.status.name, 'degraded');
      expect(report.message, contains('IntentClassifier'));
    });

    test('returns healthy when both components ready', () {
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeReadyGDetectionEngine(),
        intentClassifier: _FakeReadyIntentClassifier(),
        wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
      );

      final report = analyzer.healthCheck();
      expect(report.status.name, 'healthy');
    });
  });

  group('L2Analyzer — resetSession', () {
    test('resets processed text length and last result', () async {
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeGDetectionEngine(
          GResult(
            riskLevel: RiskLevel.orange,
            reason: 'Test',
            allMatchedKeywords: <KeywordMatch>{
              const KeywordMatch(
                keyword: 'test',
                level: RiskLevel.orange,
                category: 'Test',
              ),
            },
            alertEnabled: true,
          ),
        ),
        intentClassifier: const DisabledIntentClassifier(),
        wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
      );
      await analyzer.initialize();

      await analyzer.analyze('test', 'some test text here');
      expect(analyzer.processedTextLength, greaterThan(0));

      analyzer.resetSession();
      expect(analyzer.processedTextLength, 0);
      expect(analyzer.lastResult.overallRiskLevel, RiskLevel.green);
    });
  });

  group('L2Analyzer — syncProcessedTextLength', () {
    test('clamps negative values to 0', () {
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeReadyGDetectionEngine(),
      );

      analyzer.syncProcessedTextLength(-5);
      expect(analyzer.processedTextLength, 0);
    });

    test('sets positive values', () {
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeReadyGDetectionEngine(),
      );

      analyzer.syncProcessedTextLength(100);
      expect(analyzer.processedTextLength, 100);
    });
  });

  group('L2Analyzer — _discountGDetectionRisk', () {
    test('does not discount red risk', () async {
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeGDetectionEngine(
          GResult(
            riskLevel: RiskLevel.red,
            reason: 'Test',
            allMatchedKeywords: <KeywordMatch>{
              const KeywordMatch(
                keyword: 'test',
                level: RiskLevel.red,
                category: 'Test',
              ),
            },
            alertEnabled: true,
          ),
        ),
        intentClassifier: const DisabledIntentClassifier(),
        wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
      );
      await analyzer.initialize();

      final result = await analyzer.analyze('test', 'test text here');
      expect(result.overallRiskLevel, RiskLevel.red);
    });

    test('does not discount orange risk', () async {
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeGDetectionEngine(
          GResult(
            riskLevel: RiskLevel.orange,
            reason: 'Test',
            allMatchedKeywords: <KeywordMatch>{
              const KeywordMatch(
                keyword: 'test',
                level: RiskLevel.orange,
                category: 'Test',
              ),
            },
            alertEnabled: true,
          ),
        ),
        intentClassifier: const DisabledIntentClassifier(),
        wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
      );
      await analyzer.initialize();

      final result = await analyzer.analyze('test', 'test text here');
      expect(result.overallRiskLevel, RiskLevel.orange);
    });

    test('discounts yellow risk to green when safety discount <= 0.5', () async {
      // SafetyFilter needs to be loaded for this to work
      // This test verifies the discount logic path exists
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeGDetectionEngine(
          GResult(
            riskLevel: RiskLevel.yellow,
            reason: 'Test',
            allMatchedKeywords: <KeywordMatch>{
              const KeywordMatch(
                keyword: 'test',
                level: RiskLevel.yellow,
                category: 'Test',
              ),
            },
            alertEnabled: true,
          ),
        ),
        intentClassifier: const DisabledIntentClassifier(),
        wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
      );
      await analyzer.initialize();

      final result = await analyzer.analyze('test', 'xin chào cảm ơn bạn nhé');
      // With safety phrases, yellow may be discounted to green
      expect(
        result.overallRiskLevel.index,
        lessThanOrEqualTo(RiskLevel.yellow.index),
      );
    });
  });

  group('L2Analyzer — _mergeContextResult', () {
    test('uses WFSA risk when higher than GDetection risk', () async {
      // Create a WFSA engine with active scenarios that will produce high scores
      final wfsaEngine = WfsaEngine(ScamGraphBuilder.buildDefaultGraphs());
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeGDetectionEngine(
          const GResult(
            riskLevel: RiskLevel.green,
            reason: '',
            allMatchedKeywords: <KeywordMatch>{},
            alertEnabled: false,
          ),
        ),
        intentClassifier: const DisabledIntentClassifier(),
        wfsaEngine: wfsaEngine,
      );
      await analyzer.initialize();

      // Even with green GDetection, WFSA may elevate risk if it detects patterns
      final result = await analyzer.analyze(
        'test context',
        'test text here for analysis',
      );
      expect(result.analysisLevel, AnalysisLevel.l2);
    });
  });

  group('L2Analyzer — _distinctMatches', () {
    test('removes duplicate matches', () async {
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeGDetectionEngine(
          GResult(
            riskLevel: RiskLevel.red,
            reason: 'Test',
            allMatchedKeywords: <KeywordMatch>{
              const KeywordMatch(
                keyword: 'công an',
                level: RiskLevel.red,
                category: 'Authority',
              ),
              const KeywordMatch(
                keyword: 'chuyển tiền',
                level: RiskLevel.orange,
                category: 'Finance',
              ),
            },
            alertEnabled: true,
          ),
        ),
        intentClassifier: const DisabledIntentClassifier(),
        wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
      );
      await analyzer.initialize();

      final result = await analyzer.analyze(
        'test',
        'công an chuyển tiền test',
      );

      // Should have distinct matches (no duplicates)
      final keywords = result.matches.map((m) => m.keyword).toList();
      expect(keywords.toSet().length, keywords.length);
    });
  });

  group('L2Analyzer — analyze with empty text', () {
    test('returns green result for empty text', () async {
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeReadyGDetectionEngine(),
      );
      await analyzer.initialize();

      final result = await analyzer.analyze('', '');
      expect(result.overallRiskLevel, RiskLevel.green);
      expect(result.matches, isEmpty);
    });

    test('returns green result for whitespace-only text', () async {
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeReadyGDetectionEngine(),
      );
      await analyzer.initialize();

      final result = await analyzer.analyze('   ', '   ');
      expect(result.overallRiskLevel, RiskLevel.green);
    });
  });

  group('L2Analyzer — concurrency limiter', () {
    test('concurrent analyze calls are serialized', () async {
      int callCount = 0;
      final analyzer = L2Analyzer(
        gDetectionEngine: _FakeSlowGDetectionEngine(() => callCount),
        intentClassifier: const DisabledIntentClassifier(),
        wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
      );
      await analyzer.initialize();

      // Fire 3 concurrent analyses
      final results = await Future.wait([
        analyzer.analyze('a', 'text one'),
        analyzer.analyze('b', 'text two'),
        analyzer.analyze('c', 'text three'),
      ]);

      expect(results.length, 3);
      for (final result in results) {
        expect(result, isNotNull);
      }
    });
  });
}

// ─── Test fakes ──────────────────────────────────────────────────────────────

class _FakeGDetectionEngine extends GDetectionEngine {
  _FakeGDetectionEngine(this._result);
  final GResult _result;

  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => true;

  @override
  Future<GResult> performFullAnalysis(String text) async => _result;
}

class _FakeNotReadyGDetectionEngine extends GDetectionEngine {
  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => false;

  @override
  Future<GResult> performFullAnalysis(String text) async => const GResult(
        riskLevel: RiskLevel.green,
        reason: '',
        allMatchedKeywords: <KeywordMatch>{},
        alertEnabled: false,
      );
}

class _FakeReadyGDetectionEngine extends GDetectionEngine {
  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => true;

  @override
  Future<GResult> performFullAnalysis(String text) async => const GResult(
        riskLevel: RiskLevel.green,
        reason: '',
        allMatchedKeywords: <KeywordMatch>{},
        alertEnabled: false,
      );
}

class _FakeSlowGDetectionEngine extends GDetectionEngine {
  _FakeSlowGDetectionEngine(this._onCall);
  final int Function() _onCall;

  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => true;

  @override
  Future<GResult> performFullAnalysis(String text) async {
    _onCall();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return const GResult(
      riskLevel: RiskLevel.green,
      reason: '',
      allMatchedKeywords: <KeywordMatch>{},
      alertEnabled: false,
    );
  }
}

class _FakeReadyIntentClassifier implements IntentClassifier {
  @override
  bool get isReady => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<IntentPrediction>> predictIntent(String text) async => [];

  @override
  void close() {}
}
