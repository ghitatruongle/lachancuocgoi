import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/analysis/health_check.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_detection_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/g_detection/g_models.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_chat_session.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalysisCoordinator — routing', () {
    test('routes normal mode to L1 analyzer', () async {
      final l1 = _newTestL1();
      await l1.initialize();
      final coordinator = AnalysisCoordinator(l1Analyzer: l1);

      final result = await coordinator.analyze(
        'Vui lòng gửi mã OTP để xác minh.',
        AnalysisMode.normal,
      );

      expect(result.analysisLevel, AnalysisLevel.l1);
      expect(result.overallRiskLevel, RiskLevel.red);
    });

    test('routes gDetection mode to L2 analyzer', () async {
      final l2 = L2Analyzer(gDetectionEngine: _newTestGDetectionEngine());
      await l2.initialize();
      final coordinator = AnalysisCoordinator(l2Analyzer: l2);

      final result = await coordinator.analyze(
        'Tôi là công an, chúng tôi đang điều tra và có lệnh bắt.',
        AnalysisMode.gDetection,
      );

      expect(result.analysisLevel, AnalysisLevel.l2);
      expect(result.overallRiskLevel, RiskLevel.red);
    });

    test('routes geminiApi mode to L3 with fallback to L2', () async {
      final l3 = L3Analyzer(
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
                return '{"level":"orange","label":"Canh bao","reason":"Co dau hieu","recommendation":"Can than"}';
              },
        ),
      );
      final coordinator = AnalysisCoordinator(l3Analyzer: l3);

      final result = await coordinator.analyze(
        'Tôi là công an, anh phải chuyển tiền ngay.',
        AnalysisMode.geminiApi,
      );

      expect(result.analysisLevel, AnalysisLevel.l3);
      expect(result.overallRiskLevel, RiskLevel.orange);
    });
  });

  group('AnalysisCoordinator — reset', () {
    test('reset clears all analyzer states', () async {
      final l1 = _newTestL1();
      await l1.initialize();
      final coordinator = AnalysisCoordinator(l1Analyzer: l1);

      // Use syncProcessedTextLength to simulate processed text
      coordinator.syncProcessedTextLength(100, AnalysisMode.normal);
      expect(coordinator.getProcessedTextLength(AnalysisMode.normal), 100);

      coordinator.reset();
      expect(coordinator.getProcessedTextLength(AnalysisMode.normal), 0);
    });

    test('resetMode only resets specified mode', () async {
      final l1 = _newTestL1();
      await l1.initialize();
      final coordinator = AnalysisCoordinator(l1Analyzer: l1);

      await coordinator.analyze('mã OTP', AnalysisMode.normal);
      coordinator.resetMode(AnalysisMode.normal);
      expect(coordinator.getProcessedTextLength(AnalysisMode.normal), 0);
    });
  });

  group('AnalysisCoordinator — incremental analysis', () {
    test('incremental skips when text has not grown', () async {
      final l1 = _newTestL1();
      await l1.initialize();
      final coordinator = AnalysisCoordinator(l1Analyzer: l1);

      const text = 'Vui lòng gửi mã OTP để xác minh.';
      await coordinator.analyzeIncremental(text, AnalysisMode.normal);
      final second = await coordinator.analyzeIncremental(
        text,
        AnalysisMode.normal,
      );

      expect(second.overallRiskLevel, isNotNull);
    });
  });

  group('AnalysisCoordinator — health checks', () {
    test('runAllHealthChecks returns reports for all analyzers', () {
      final coordinator = AnalysisCoordinator();
      final reports = coordinator.runAllHealthChecks();

      expect(reports.keys, containsAll(<String>['L1', 'L2', 'L3']));
      for (final report in reports.values) {
        expect(report, isA<HealthReport>());
      }
    });
  });

  group('AnalysisCoordinator — L3 session lifecycle', () {
    test('createL3Session and closeL3Session lifecycle', () {
      final coordinator = AnalysisCoordinator();

      coordinator.createL3Session(initialProcessedTextLength: 10);
      expect(coordinator.getProcessedTextLength(AnalysisMode.geminiApi), 10);

      coordinator.closeL3Session(resetProgress: true);
      expect(coordinator.getProcessedTextLength(AnalysisMode.geminiApi), 0);
    });

    test('createL3Session clamps negative offset to 0', () {
      final coordinator = AnalysisCoordinator();

      coordinator.createL3Session(initialProcessedTextLength: -5);
      expect(coordinator.getProcessedTextLength(AnalysisMode.geminiApi), 0);
    });
  });

  group('AnalysisCoordinator — default results', () {
    test('getLastResult returns correct default per mode', () {
      final coordinator = AnalysisCoordinator();

      final l1Default = coordinator.getLastResult(AnalysisMode.normal);
      expect(l1Default.overallRiskLevel, RiskLevel.green);

      final l2Default = coordinator.getLastResult(AnalysisMode.gDetection);
      expect(l2Default.overallRiskLevel, RiskLevel.green);

      final l3Default = coordinator.getLastResult(AnalysisMode.geminiApi);
      expect(l3Default.overallRiskLevel, RiskLevel.green);
    });
  });

  group('AnalysisCoordinator — L3 fallback', () {
    test('fallback to L2 when L3 network error', () async {
      final l3 = L3Analyzer(
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
                throw Exception('Network error');
              },
        ),
      );
      final l2 = L2Analyzer(
        gDetectionEngine: _FakeGDetectionEngine(
          GResult(
            riskLevel: RiskLevel.orange,
            reason: 'Phát hiện từ khóa đáng ngờ',
            allMatchedKeywords: <KeywordMatch>{
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

      final coordinator = AnalysisCoordinator(l2Analyzer: l2, l3Analyzer: l3);

      final result = await coordinator.analyze(
        'Anh phải chuyển tiền ngay.',
        AnalysisMode.geminiApi,
      );

      expect(result.isFallback, isTrue);
      expect(result.matches.length, 2);
      expect(
        result.matches.any(
          (m) => m.keyword == 'Sử dụng Luồng 2 (GDetection & WFSA)',
        ),
        isTrue,
      );
      expect(result.matches.any((m) => m.keyword == 'chuyển tiền'), isTrue);
      expect(result.reason, contains('API Error'));
    });

    test('fallback result preserves L2 matches', () async {
      final l3 = L3Analyzer(
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
                throw Exception('Timeout');
              },
        ),
      );
      final l2 = L2Analyzer(
        gDetectionEngine: _FakeGDetectionEngine(
          GResult(
            riskLevel: RiskLevel.red,
            reason: 'Giả danh công an',
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

      final coordinator = AnalysisCoordinator(l2Analyzer: l2, l3Analyzer: l3);

      final result = await coordinator.analyze(
        'Tôi là công an điều tra.',
        AnalysisMode.geminiApi,
      );

      // Should preserve original L2 match and have isFallback = true
      expect(result.isFallback, isTrue);
      expect(result.matches.length, 2);
      expect(
        result.matches.any(
          (m) => m.keyword == 'Sử dụng Luồng 2 (GDetection & WFSA)',
        ),
        isTrue,
      );
      expect(result.matches.any((m) => m.keyword == 'công an'), isTrue);
    });
  });

  group('AnalysisCoordinator — syncProcessedTextLength', () {
    test('syncs processed text length for specified mode', () {
      final coordinator = AnalysisCoordinator();
      coordinator.syncProcessedTextLength(100, AnalysisMode.normal);
      expect(coordinator.getProcessedTextLength(AnalysisMode.normal), 100);
    });
  });

  group('AnalysisCoordinator — analyzeIncremental L1 (normal)', () {
    test(
      'skips analysis when deltaLength < adaptiveMinDelta (30 chars for green L1)',
      () async {
        final l1 = _newTestL1();
        await l1.initialize();
        final coordinator = AnalysisCoordinator(l1Analyzer: l1);

        coordinator.syncProcessedTextLength(100, AnalysisMode.normal);
        // delta = 110 - 100 = 10 < 30 (green L1 minDelta = 50*0.6 = 30)
        final result = await coordinator.analyzeIncremental(
          'x' * 110,
          AnalysisMode.normal,
        );

        expect(result.overallRiskLevel, RiskLevel.green);
        expect(result.analysisLevel, AnalysisLevel.l1);
        // processedTextLength unchanged because analysis was skipped
        expect(coordinator.getProcessedTextLength(AnalysisMode.normal), 100);
      },
    );

    test('processes analysis when deltaLength >= adaptiveMinDelta', () async {
      final l1 = _newTestL1();
      await l1.initialize();
      final coordinator = AnalysisCoordinator(l1Analyzer: l1);

      coordinator.syncProcessedTextLength(0, AnalysisMode.normal);
      const text = 'Vui lòng gửi mã OTP để xác minh.';
      expect(
        text.length,
        greaterThanOrEqualTo(30),
        reason: 'Text must be >= 30 chars to pass L1 minDelta',
      );

      final result = await coordinator.analyzeIncremental(
        text,
        AnalysisMode.normal,
      );

      expect(result.analysisLevel, AnalysisLevel.l1);
      expect(result.overallRiskLevel, RiskLevel.red);
      expect(result.matches.any((m) => m.keyword.contains('mã otp')), isTrue);
    });

    test(
      'second call with same text returns last result to prevent flickering to green',
      () async {
        final l1 = _newTestL1();
        await l1.initialize();
        final coordinator = AnalysisCoordinator(l1Analyzer: l1);

        coordinator.syncProcessedTextLength(0, AnalysisMode.normal);
        const text = 'Vui lòng gửi mã OTP để xác minh.';

        final first = await coordinator.analyzeIncremental(
          text,
          AnalysisMode.normal,
        );
        expect(first.overallRiskLevel, RiskLevel.red);

        // Second call: length hasn't changed, returns lastResult
        final second = await coordinator.analyzeIncremental(
          text,
          AnalysisMode.normal,
        );
        expect(second.overallRiskLevel, RiskLevel.red);
        expect(second.alertEnabled, isFalse);
      },
    );
  });

  group('AnalysisCoordinator — analyzeIncremental L2 (gDetection)', () {
    test(
      'skips analysis when deltaLength < adaptiveMinDelta (40 chars for green L2)',
      () async {
        final l2 = L2Analyzer(
          gDetectionEngine: _FakeGDetectionEngine(
            GResult(
              riskLevel: RiskLevel.red,
              reason: 'Test reason',
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

        coordinator.syncProcessedTextLength(100, AnalysisMode.gDetection);
        // delta = 120 - 100 = 20 < 40 (green L2 minDelta = 50*0.8 = 40)
        final result = await coordinator.analyzeIncremental(
          'x' * 120,
          AnalysisMode.gDetection,
        );

        expect(result.analysisLevel, AnalysisLevel.l2);
        // processedTextLength unchanged
        expect(
          coordinator.getProcessedTextLength(AnalysisMode.gDetection),
          100,
        );
      },
    );

    test('processes analysis when deltaLength >= adaptiveMinDelta', () async {
      final l2 = L2Analyzer(
        gDetectionEngine: _FakeGDetectionEngine(
          GResult(
            riskLevel: RiskLevel.orange,
            reason: 'Phát hiện từ khóa đáng ngờ',
            allMatchedKeywords: <KeywordMatch>{
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
      await l2.initialize();
      final coordinator = AnalysisCoordinator(l2Analyzer: l2);

      coordinator.syncProcessedTextLength(0, AnalysisMode.gDetection);
      const text = 'Anh phải chuyển tiền vào tài khoản này ngay.';
      expect(
        text.length,
        greaterThanOrEqualTo(40),
        reason: 'Text must be >= 40 chars to pass L2 minDelta',
      );

      final result = await coordinator.analyzeIncremental(
        text,
        AnalysisMode.gDetection,
      );

      expect(result.analysisLevel, AnalysisLevel.l2);
      expect(result.overallRiskLevel, RiskLevel.orange);
      expect(
        coordinator.getProcessedTextLength(AnalysisMode.gDetection),
        text.length,
      );
    });
  });

  group('AnalysisCoordinator — analyzeIncremental L3 (geminiApi)', () {
    test('auto-creates session and processes incremental text', () async {
      final session = GeminiChatSession(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        config: GeminiConfig.forAnalysis(),
        chatExecutor:
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required List<Content> history,
              required String prompt,
            }) async {
              return '{"level":"orange","label":"Canh bao","reason":"Co dau hieu lua dao","recommendation":"Can than"}';
            },
      );
      final l3 = L3Analyzer(
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
                return '{"level":"green","label":"","reason":"","recommendation":""}';
              },
        ),
        sessionFactory: () => session,
      );
      final coordinator = AnalysisCoordinator(l3Analyzer: l3);

      // Text >= 50 chars (L3 green minDelta) AND >= 40 chars (minIncrementalChars)
      // AND ends with sentence boundary '.'
      const text =
          'Xin chào, tôi là công an đến từ cơ quan điều tra. Anh phải chuyển tiền ngay nhé.';
      expect(
        text.length,
        greaterThanOrEqualTo(50),
        reason: 'Text must be >= 50 to pass L3 minDelta',
      );

      final result = await coordinator.analyzeIncremental(
        text,
        AnalysisMode.geminiApi,
      );

      expect(result.analysisLevel, AnalysisLevel.l3);
      expect(result.isError, false);
      expect(result.overallRiskLevel, RiskLevel.orange);
    });

    test('falls back to L2 when L3 incremental analysis errors', () async {
      final session = GeminiChatSession(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        config: GeminiConfig.forAnalysis(),
        chatExecutor:
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required List<Content> history,
              required String prompt,
            }) async {
              throw Exception('Gemini API error: test failure');
            },
      );
      final l2 = L2Analyzer(
        gDetectionEngine: _FakeGDetectionEngine(
          GResult(
            riskLevel: RiskLevel.orange,
            reason: 'Phát hiện từ khóa đáng ngờ',
            allMatchedKeywords: <KeywordMatch>{
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
      await l2.initialize();
      final l3 = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        sessionFactory: () => session,
      );
      final coordinator = AnalysisCoordinator(l2Analyzer: l2, l3Analyzer: l3);

      const text =
          'Xin chào, tôi là công an đến từ cơ quan điều tra. Anh phải chuyển tiền ngay nhé.';
      expect(text.length, greaterThanOrEqualTo(50));

      final result = await coordinator.analyzeIncremental(
        text,
        AnalysisMode.geminiApi,
      );

      // Should fall back to L2 with isFallback = true
      expect(result.isFallback, isTrue);
      expect(result.matches.length, 2);
      expect(
        result.matches.any(
          (m) => m.keyword == 'Sử dụng Luồng 2 (GDetection & WFSA)',
        ),
        isTrue,
      );
      expect(result.matches.any((m) => m.keyword == 'chuyển tiền'), isTrue);
      expect(result.reason, contains('Gemini API error'));
    });
  });
}

L1Analyzer _newTestL1() {
  return L1Analyzer(
    vocabularyProvider: () => jsonEncode(_testVocabulary),
    bigramCorrectionsProvider: () => jsonEncode(_testCorrections),
  );
}

GDetectionEngine _newTestGDetectionEngine() {
  final assets = <String, Object?>{
    GDetectionEngine.vocabularyFile: _testGVocabulary,
    GDetectionEngine.scoringConfigFile: _testScoringConfig,
    GDetectionEngine.patternsFile: {'patterns': <Object?>[]},
    GDetectionEngine.situationFile: {
      'title': 'Test',
      'version': '1.0',
      'total_scenarios': 1,
      'scenarios': <Object?>[
        <String, Object?>{
          'id': 'S1',
          'name': 'Giả danh công an',
          'risk_level': 3,
          'category': 'AUTH',
          'trigger_phrases': <String>['công an'],
          'required_context': <String>['điều tra', 'lệnh bắt'],
          'l2_analysis_hints': <String, Object?>{
            'urgency_level': 'medium',
            'authority_claim': true,
            'financial_request': false,
          },
        },
      ],
    },
    GDetectionEngine.sentencesFile: {
      'riskLevels': <Object?>[
        <String, Object?>{
          'level': 0,
          'sentences': <String>['xin chào'],
        },
      ],
    },
    GDetectionEngine.slangFile: {'slang_map': <String, String>{}},
    GDetectionEngine.tierConfigFile: {
      'tier1_topics': <String>['công an'],
      'tier2_urgency': <String>['lệnh bắt'],
      'tier3_pii': <String>['mã otp'],
    },
    GDetectionEngine.aiCheckFile: <String, Object?>{'situations': <Object?>[]},
  };
  return GDetectionEngine(
    assetProvider: (fileName) =>
        jsonEncode(assets[fileName] ?? <String, Object?>{}),
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

const Map<String, Object?> _testGVocabulary = <String, Object?>{
  'riskLevels': <Object?>[
    <String, Object?>{
      'level': 0,
      'keywords': <String>['xin chào'],
    },
    <String, Object?>{
      'level': 3,
      'threats': <String, Object?>{
        'AUTHORITY': <String>['công an'],
        'PII': <String>['mã otp'],
      },
    },
  ],
};

const Map<String, Object?> _testScoringConfig = <String, Object?>{
  'scenario_alert_threshold': 0.6,
  'weights': <String, Object?>{
    'keyword': 0.25,
    'topic': 0.20,
    'pattern': 0.25,
    'scenario': 0.20,
    'context': 0.10,
  },
};
