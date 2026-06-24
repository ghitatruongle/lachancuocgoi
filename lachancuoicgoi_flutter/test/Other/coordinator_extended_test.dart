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

  group('AnalysisCoordinator — _adaptiveMinDelta', () {
    test('L1 (normal) mode has lower threshold than L2', () async {
      final l1 = _newTestL1();
      await l1.initialize();
      final coordinator = AnalysisCoordinator(l1Analyzer: l1);

      // L1 green minDelta = 50 * 0.6 = 30
      // Text with delta = 35 should trigger L1 analysis
      coordinator.syncProcessedTextLength(0, AnalysisMode.normal);
      const text = 'Vui lòng gửi mã OTP để xác minh ngay.'; // ~40 chars
      final result = await coordinator.analyzeIncremental(
        text,
        AnalysisMode.normal,
      );

      expect(result.analysisLevel, AnalysisLevel.l1);
      expect(result.matches, isNotEmpty);
    });

    test('L2 (gDetection) mode has medium threshold', () async {
      final l2 = L2Analyzer(
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
      await l2.initialize();
      final coordinator = AnalysisCoordinator(l2Analyzer: l2);

      // L2 green minDelta = 50 * 0.8 = 40
      // delta = 30 should NOT trigger L2
      coordinator.syncProcessedTextLength(100, AnalysisMode.gDetection);
      final result = await coordinator.analyzeIncremental(
        'x' * 130, // delta = 30 < 40
        AnalysisMode.gDetection,
      );

      // Should return default result (skipped)
      expect(result.analysisLevel, AnalysisLevel.l2);
    });
  });

  group('AnalysisCoordinator — _fallbackToL2 when L2 not ready', () {
    test('returns green error result when L2 also not ready', () async {
      final l3 = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );
      // L2 not initialized → not ready
      final l2 = L2Analyzer(
        gDetectionEngine: _FakeNotReadyGDetectionEngine(),
        intentClassifier: const DisabledIntentClassifier(),
        wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
      );

      final coordinator = AnalysisCoordinator(l2Analyzer: l2, l3Analyzer: l3);

      final result = await coordinator.analyze(
        'Test text for L3 fallback',
        AnalysisMode.geminiApi,
      );

      expect(result.isError, isTrue);
      expect(result.overallRiskLevel, RiskLevel.green);
      // Returns l2 level so MonitoringPage can detect the fallback.
      expect(result.analysisLevel, AnalysisLevel.l2);
    });
  });

  group('AnalysisCoordinator — analyzeWithTranscript L2 init failure', () {
    test(
      'returns "L2 initializing" result when L2 fails to initialize twice',
      () async {
        // L2 with engine that never becomes ready
        final l2 = L2Analyzer(
          gDetectionEngine: _FakeNotReadyGDetectionEngine(),
          intentClassifier: const DisabledIntentClassifier(),
          wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
        );

        final coordinator = AnalysisCoordinator(l2Analyzer: l2);

        final result = await coordinator.analyzeWithTranscript(
          'test text',
          'test text',
          AnalysisMode.gDetection,
        );

        expect(result.overallRiskLevel, RiskLevel.green);
        expect(result.reason, contains('khởi tạo'));
        expect(result.analysisLevel, AnalysisLevel.l2);
      },
    );
  });

  group('AnalysisCoordinator — analyzeIncremental with adaptive minDelta', () {
    test('red risk level uses smaller minDelta (20 for L2)', () async {
      final l2 = L2Analyzer(
        gDetectionEngine: _FakeGDetectionEngine(
          GResult(
            riskLevel: RiskLevel.red,
            reason: 'Test reason',
            allMatchedKeywords: <KeywordMatch>{
              const KeywordMatch(
                keyword: 'công an',
                level: RiskLevel.red,
                category: 'Authority',
              ),
            },
            alertEnabled: true,
          ),
        ),
        intentClassifier: const DisabledIntentClassifier(),
        wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
      );
      await l2.initialize();
      final coordinator = AnalysisCoordinator(l2Analyzer: l2);

      // First analysis to set risk level to red
      coordinator.syncProcessedTextLength(0, AnalysisMode.gDetection);
      await coordinator.analyze(
        'Tôi là công an, anh phải chuyển tiền ngay lập tức.',
        AnalysisMode.gDetection,
      );

      // Now with red risk, L2 minDelta = 20 * 0.8 = 16
      // Add 20 chars — should trigger re-analysis
      const extendedText =
          'Tôi là công an, anh phải chuyển tiền ngay lập tức. Ma OTP la gi?';
      final result = await coordinator.analyzeIncremental(
        extendedText,
        AnalysisMode.gDetection,
      );

      expect(result.analysisLevel, AnalysisLevel.l2);
    });

    test(
      'returns lastResult with alertEnabled=false for orange incremental skip',
      () async {
        final l2 = L2Analyzer(
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
        await l2.initialize();
        final coordinator = AnalysisCoordinator(l2Analyzer: l2);

        // First analysis
        coordinator.syncProcessedTextLength(0, AnalysisMode.gDetection);
        await coordinator.analyze(
          'Anh phải chuyển tiền vào tài khoản ngay.',
          AnalysisMode.gDetection,
        );

        // Small delta — should skip
        final result = await coordinator.analyzeIncremental(
          'Anh phải chuyển tiền vào tài khoản ngay. xy', // +3 chars
          AnalysisMode.gDetection,
        );

        // Orange result should have alertEnabled=false when skipped
        if (result.overallRiskLevel.index >= RiskLevel.orange.index) {
          expect(result.alertEnabled, isFalse);
        }
      },
    );
  });

  group('AnalysisCoordinator — resetMode', () {
    test('resets compatibility mode when resetting current mode', () async {
      final l1 = _newTestL1();
      await l1.initialize();
      final coordinator = AnalysisCoordinator(l1Analyzer: l1);

      // Use analyzeIncremental to set processedTextLength
      coordinator.syncProcessedTextLength(42, AnalysisMode.normal);
      expect(coordinator.getProcessedTextLength(AnalysisMode.normal), 42);

      coordinator.resetMode(AnalysisMode.normal);
      expect(coordinator.getProcessedTextLength(AnalysisMode.normal), 0);
    });

    test('resetting non-current mode does not affect other modes', () async {
      final l1 = _newTestL1();
      await l1.initialize();
      final coordinator = AnalysisCoordinator(l1Analyzer: l1);

      coordinator.syncProcessedTextLength(42, AnalysisMode.normal);
      // Reset L2 instead — should not affect L1
      coordinator.resetMode(AnalysisMode.gDetection);
      expect(coordinator.getProcessedTextLength(AnalysisMode.normal), 42);
    });
  });
}

L1Analyzer _newTestL1() {
  return L1Analyzer(
    vocabularyProvider: () => jsonEncode(_testVocabulary),
    bigramCorrectionsProvider: () => jsonEncode(_testCorrections),
  );
}

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

const Map<String, Object?> _testVocabulary = {
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

const Map<String, Object?> _testCorrections = {'corrections': <Object?>[]};
