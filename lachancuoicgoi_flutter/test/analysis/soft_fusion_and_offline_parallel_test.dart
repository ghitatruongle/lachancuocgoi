import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline parallel still fast-tracks L1 red without needing L3', () async {
    final l1 = L1Analyzer(
      vocabularyProvider: () => jsonEncode(_kVocabulary),
      bigramCorrectionsProvider: () => jsonEncode(_kCorrections),
    );
    await l1.initialize();

    final l2 = L2Analyzer(
      gDetectionEngine: _ScriptedGDetectionEngine(
        const GResult(
          riskLevel: RiskLevel.green,
          reason: 'L2 green',
          allMatchedKeywords: <KeywordMatch>{},
          alertEnabled: false,
        ),
      ),
      intentClassifier: const DisabledIntentClassifier(),
      wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
    );
    await l2.initialize();

    final l3 = L3Analyzer(
      apiKeyProvider: StaticApiKeyProvider(const <String>[]),
    );

    final coordinator = AnalysisCoordinator(
      l1Analyzer: l1,
      l2Analyzer: l2,
      l3Analyzer: l3,
      networkAvailable: () => false,
    );

    final result = await coordinator.analyze(
      'Cho tôi mã OTP ngay.',
      AnalysisMode.parallel,
    );

    expect(result.overallRiskLevel, RiskLevel.red);
    expect(result.analysisLevel, AnalysisLevel.l1);
  });

  test('speechRate and network setters are accepted', () {
    final coordinator = AnalysisCoordinator();
    coordinator.setSpeechRate(6.5);
    coordinator.setSpeechRate(-1);
    coordinator.setNetworkAvailable(false);
    coordinator.setNetworkAvailable(true);
    final summary = coordinator.healthSummary();
    expect(summary.containsKey('network'), isTrue);
  });
}

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
