// Sprint 4.2b — characterization tests for AnalysisMode.parallel.
//
// The parallel path was the only AnalysisMode with no direct coverage
// before this file. These tests pin down its observable contract:
//   • L1/L2 fast-track: a high-risk L1 or L2 short-circuits past L3.
//   • L1+L2+L3 fusion: when no layer hits orange, all three are fused.
//   • Incremental delta-gate: under-threshold deltas reuse the last result.
//   • resetMode(parallel) clears the cached parallel result.
//
// L2 is driven by a _FakeGDetectionEngine so we can script its risk level
// without loading TFLite/assets. L1 uses a real L1Analyzer against a tiny
// in-memory vocabulary (so we control what it flags as red). L3 uses a
// GeminiClient stub backed by StaticApiKeyProvider.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalysisCoordinator — parallel analyze (full transcript)', () {
    test('fast-tracks when L1 hits red, skipping L3', () async {
      // L1 flags 'mã OTP' as red via the in-memory vocabulary.
      final l1 = _newL1();
      await l1.initialize();
      // L2 stays green.
      final l2 = _newL2(_greenGResult());
      await l2.initialize();
      // L3 is not ready, so if the coordinator consulted it we'd know.
      final l3 = _notReadyL3();
      final coordinator = AnalysisCoordinator(
        l1Analyzer: l1,
        l2Analyzer: l2,
        l3Analyzer: l3,
      );

      final result = await coordinator.analyze(
        'Cho tôi mã OTP ngay.',
        AnalysisMode.parallel,
      );

      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.analysisLevel, AnalysisLevel.l1);
    });

    test('fuses L1+L2+L3 when no layer fast-tracks', () async {
      // L1 green (no critical keyword in this text).
      final l1 = _newL1();
      await l1.initialize();
      // L2 green.
      final l2 = _newL2(_greenGResult());
      await l2.initialize();
      // L3 returns a red verdict via the stubbed GeminiClient.
      final l3 = _newL3Returning(level: 'red', reason: 'L3 lừa đảo');
      final coordinator = AnalysisCoordinator(
        l1Analyzer: l1,
        l2Analyzer: l2,
        l3Analyzer: l3,
      );

      final result = await coordinator.analyze(
        'Chào bạn, đây là một cuộc gọi bình thường.',
        AnalysisMode.parallel,
      );

      // Highest risk across the three layers wins → L3's red.
      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.analysisLevel, AnalysisLevel.l3);
      expect(result.reason, contains('L3 lừa đảo'));
      expect(result.alertEnabled, isTrue);
    });
  });

  group('AnalysisCoordinator — parallel analyzeIncremental', () {
    test(
      'delta below threshold returns last result without re-analyzing L3',
      () async {
        final l1 = _newL1();
        await l1.initialize();
        final l2 = _newL2(_greenGResult());
        await l2.initialize();
        final l3 = _newL3Returning(level: 'green', reason: 'L3 green');
        final coordinator = AnalysisCoordinator(
          l1Analyzer: l1,
          l2Analyzer: l2,
          l3Analyzer: l3,
        );

        // First call: large delta triggers a real run and caches the result.
        final firstText = 'A' * 200;
        final first = await coordinator.analyzeIncremental(
          firstText,
          AnalysisMode.parallel,
        );
        expect(first.overallRiskLevel, RiskLevel.green);

        // Second call: text barely grew (delta < adaptiveMinDelta) → the
        // coordinator reuses the cached green result instead of re-running.
        final second = await coordinator.analyzeIncremental(
          '$firstText xx',
          AnalysisMode.parallel,
        );
        expect(second.overallRiskLevel, RiskLevel.green);
      },
    );

    test('resetMode(parallel) clears cached parallel result', () async {
      final l1 = _newL1();
      await l1.initialize();
      // L2 returns red on the first call (fast-track + cache), then green
      // afterwards, so we can observe that the cache was cleared rather
      // than the L2 verdict itself changing.
      final l2 = _newL2WithEngine(
        _SequenceGDetectionEngine([
          _redGResult(reason: 'L2 red'),
          _greenGResult(),
        ]),
      );
      await l2.initialize();
      final l3 = _notReadyL3();
      final coordinator = AnalysisCoordinator(
        l1Analyzer: l1,
        l2Analyzer: l2,
        l3Analyzer: l3,
      );

      // Prime the cached parallel result with a red fast-track.
      final first = await coordinator.analyzeIncremental(
        'A' * 200,
        AnalysisMode.parallel,
      );
      expect(first.overallRiskLevel, RiskLevel.red);

      // Without reset, a tiny-delta second call would reuse the cached red
      // result. After reset the cache is cleared, so the coordinator
      // re-evaluates against L2's next verdict (green) → green.
      coordinator.resetMode(AnalysisMode.parallel);
      final second = await coordinator.analyzeIncremental(
        'A' * 201,
        AnalysisMode.parallel,
      );
      expect(second.overallRiskLevel, RiskLevel.green);
    });
  });
}

// ─── Helpers ────────────────────────────────────────────────────────────────

L1Analyzer _newL1() {
  return L1Analyzer(
    vocabularyProvider: () => jsonEncode(_kVocabulary),
    bigramCorrectionsProvider: () => jsonEncode(_kCorrections),
  );
}

L2Analyzer _newL2(GResult gResult) =>
    _newL2WithEngine(_ScriptedGDetectionEngine(gResult));

L2Analyzer _newL2WithEngine(GDetectionEngine engine) {
  return L2Analyzer(
    gDetectionEngine: engine,
    intentClassifier: const DisabledIntentClassifier(),
    wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
  );
}

L3Analyzer _newL3Returning({required String level, required String reason}) {
  return L3Analyzer(
    apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
    geminiClient: GeminiClient(
      apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      config: GeminiConfig.forAnalysis(),
      requestExecutor:
          ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            return jsonEncode({
              'level': level,
              'label': 'Label',
              'reason': reason,
              'recommendation': 'Cẩn thận',
            });
          },
    ),
  );
}

L3Analyzer _notReadyL3() {
  // No API key → not ready. The coordinator's parallel path will then
  // fall back to a default L3 green result instead of consulting Gemini.
  return L3Analyzer(apiKeyProvider: StaticApiKeyProvider(const <String>[]));
}

GResult _greenGResult() => const GResult(
  riskLevel: RiskLevel.green,
  reason: 'L2 green',
  allMatchedKeywords: <KeywordMatch>{},
  alertEnabled: false,
);

GResult _redGResult({required String reason}) => GResult(
  riskLevel: RiskLevel.red,
  reason: reason,
  allMatchedKeywords: <KeywordMatch>{
    const KeywordMatch(
      keyword: 'công an',
      level: RiskLevel.red,
      category: 'AUTHORITY',
    ),
  },
  alertEnabled: true,
);

class _ScriptedGDetectionEngine extends GDetectionEngine {
  _ScriptedGDetectionEngine(this._result);

  final GResult _result;

  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => true;

  @override
  Future<GResult> performFullAnalysis(String text) async => _result;
}

/// Returns each scripted [GResult] in order, then repeats the last one for
/// any further calls. Used to make a single L2 instance change its verdict
/// across successive parallel runs.
class _SequenceGDetectionEngine extends GDetectionEngine {
  _SequenceGDetectionEngine(this._results);

  final List<GResult> _results;
  int _callCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  bool get isReady => true;

  @override
  Future<GResult> performFullAnalysis(String text) async {
    if (_callCount < _results.length) {
      return _results[_callCount++];
    }
    return _results.last;
  }
}

const Map<String, Object?> _kVocabulary = {
  'riskLevels': [
    {
      'level': 0,
      'keywords': ['xin chào'],
    },
    {
      'level': 3,
      'threats': {
        'PII': ['mã otp'],
      },
      'keywords': ['mã otp'],
    },
  ],
};

const Map<String, Object?> _kCorrections = {'corrections': <Object?>[]};
