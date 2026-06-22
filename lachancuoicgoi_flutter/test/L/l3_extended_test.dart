import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/key_health_tracker.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('L3Analyzer — _validateInput', () {
    test('returns green result for empty text', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      final result = await analyzer.analyze('');
      expect(result.overallRiskLevel, RiskLevel.green);
      expect(result.reason, contains('trống'));
      expect(result.analysisLevel, AnalysisLevel.l3);
    });

    test('returns green result for whitespace-only text', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      final result = await analyzer.analyze('   ');
      expect(result.overallRiskLevel, RiskLevel.green);
      expect(result.reason, contains('trống'));
    });

    test('returns green result for text with fewer than 3 words', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      final result = await analyzer.analyze('hello world');
      expect(result.overallRiskLevel, RiskLevel.green);
      expect(result.reason, contains('ngắn'));
      expect(result.reason, contains('3'));
    });

    test('passes validation for text with 3+ words', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        geminiClient: GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
          config: GeminiConfig.forAnalysis(),
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            return '{"level":"green","label":"","reason":"OK","recommendation":""}';
          },
        ),
      );

      final result = await analyzer.analyze('this is valid text');
      expect(result.reason, isNot(contains('trống')));
      expect(result.reason, isNot(contains('ngắn')));
    });
  });

  group('L3Analyzer — _inferLevelFromReason', () {
    test('infers red from scam keywords in reason', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        geminiClient: GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
          config: GeminiConfig.forAnalysis(),
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            return '{"level":"unknown","label":"Test","reason":"Có dấu hiệu lừa đảo chuyển tiền","recommendation":"Cẩn thận"}';
          },
        ),
      );

      final result = await analyzer.analyze('this is a test with enough words');
      expect(result.overallRiskLevel, RiskLevel.red);
    });

    test('infers orange from authority keywords', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        geminiClient: GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
          config: GeminiConfig.forAnalysis(),
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            return '{"level":"unknown","label":"Test","reason":"Công an yêu cầu cung cấp tài khoản","recommendation":""}';
          },
        ),
      );

      final result = await analyzer.analyze('this is a test with enough words');
      expect(result.overallRiskLevel, RiskLevel.orange);
    });

    test('infers yellow from caution keywords', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        geminiClient: GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
          config: GeminiConfig.forAnalysis(),
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            return '{"level":"unknown","label":"Test","reason":"Nội dung đáng ngờ cần lưu ý","recommendation":""}';
          },
        ),
      );

      final result = await analyzer.analyze('this is a test with enough words');
      expect(result.overallRiskLevel, RiskLevel.yellow);
    });

    test('infers green when no keywords match', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        geminiClient: GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
          config: GeminiConfig.forAnalysis(),
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            return '{"level":"unknown","label":"Test","reason":"Normal conversation about weather","recommendation":""}';
          },
        ),
      );

      final result = await analyzer.analyze('this is a test with enough words');
      expect(result.overallRiskLevel, RiskLevel.green);
    });
  });

  group('L3Analyzer — _isSentenceBoundary', () {
    test('detects period as sentence boundary', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        geminiClient: GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
          config: GeminiConfig.forAnalysis(),
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            return '{"level":"green","label":"","reason":"OK","recommendation":""}';
          },
        ),
      );

      analyzer.createSession(initialProcessedTextLength: 0);
      const text = 'Hello world this is a test sentence for boundary detection. Yes it is.';
      final result = await analyzer.analyzeIncremental(text);
      expect(result, isNotNull);
    });

    test('detects Vietnamese ending "nha" as boundary', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        geminiClient: GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
          config: GeminiConfig.forAnalysis(),
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            return '{"level":"green","label":"","reason":"OK","recommendation":""}';
          },
        ),
      );

      analyzer.createSession(initialProcessedTextLength: 0);
      const text = 'Anh oi minh di an com nhe nha di choi nha. Toi cung muon di choi lam nha';
      final result = await analyzer.analyzeIncremental(text);
      expect(result, isNotNull);
    });

    test('returns null for short text without boundary', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      analyzer.createSession(initialProcessedTextLength: 0);
      final result = await analyzer.analyzeIncremental('short text');
      expect(result, isNull);
    });
  });

  group('L3Analyzer — healthCheck edge cases', () {
    test('returns down when no API keys', () {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>[]),
      );

      final report = analyzer.healthCheck();
      expect(report.status.name, 'down');
      expect(report.message, contains('API key'));
    });

    test('returns down when all keys exhausted', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const <String>['AIza_test']),
      );
      tracker.markInvalid(0);

      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        keyHealthTracker: tracker,
      );

      final report = analyzer.healthCheck();
      expect(report.status.name, 'down');
      expect(report.message, contains('INVALID'));
    });

    test('returns degraded when all keys in cooldown', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const <String>['AIza_test']),
      );
      tracker.markError(0);
      tracker.markError(0);
      tracker.markError(0);

      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        keyHealthTracker: tracker,
      );

      final report = analyzer.healthCheck();
      expect(report.status.name, 'degraded');
      expect(report.message, contains('cooldown'));
    });

    test('returns healthy when keys are active', () {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      final report = analyzer.healthCheck();
      expect(report.status.name, 'healthy');
    });
  });

  group('L3Analyzer — analyzeIncremental edge cases', () {
    test('returns null when no active session', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      final result = await analyzer.analyzeIncremental('some text');
      expect(result, isNull);
    });

    test('returns lastResult when newTextLength <= 0', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      analyzer.createSession(initialProcessedTextLength: 100);
      final result = await analyzer.analyzeIncremental('short');
      expect(result, isNotNull);
      expect(result!.overallRiskLevel, RiskLevel.green);
    });
  });

  group('L3Analyzer — syncProcessedTextLength', () {
    test('clamps negative values to 0', () {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      analyzer.syncProcessedTextLength(-10);
      expect(analyzer.processedTextLength, 0);
    });

    test('sets positive values correctly', () {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      analyzer.syncProcessedTextLength(42);
      expect(analyzer.processedTextLength, 42);
    });
  });

  group('L3Analyzer — closeSession', () {
    test('resets all session state', () {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      analyzer.createSession(initialProcessedTextLength: 50);
      expect(analyzer.processedTextLength, 50);

      analyzer.closeSession();
      expect(analyzer.processedTextLength, 0);
    });
  });

  group('L3Analyzer — _calculateConfidence', () {
    test('confidence includes level match bonus', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        geminiClient: GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
          config: GeminiConfig.forAnalysis(),
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            return '{"level":"red","label":"Lua dao","reason":"Co dau hieu","recommendation":"Can than"}';
          },
        ),
      );

      final result = await analyzer.analyze('this is a test sentence here with enough characters');
      // Confidence = 0.3 (level) + 0.15 (reason) + 0.15 (label) + 0.15 (recommendation) = 0.75
      expect(result.confidence, greaterThanOrEqualTo(0.75));
    });

    test('confidence is 0 when all fields missing', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        geminiClient: GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
          config: GeminiConfig.forAnalysis(),
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            return '{"level":"","label":"","reason":"","recommendation":""}';
          },
        ),
      );

      final result = await analyzer.analyze('this is a test sentence here');
      expect(result.confidence, 0.0);
    });
  });
}
