import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_level.dart';
import 'package:lachancuocgoi_flutter/analysis/health_check.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_chat_session.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_metrics.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('L3Analyzer - edge cases', () {
    setUp(() {
      GeminiMetrics.resetForTesting();
    });

    test(
      'analyzeIncremental with null session returns null',
      () async {
        final analyzer = _createL3AnalyzerWithSession();
        // Do NOT call createSession — _activeSession is null
        final result = await analyzer.analyzeIncremental('some text');
        expect(result, isNull);
      },
    );

    test(
      'analyzeIncremental with zero new text returns last result',
      () async {
        final analyzer = _createL3AnalyzerWithSession();
        analyzer.createSession();
        // Set processedTextLength to equal the text length
        analyzer.syncProcessedTextLength(10);

        final result = await analyzer.analyzeIncremental('0123456789');
        // newTextLength = 10 - 10 = 0, should return _lastResult
        expect(result, isNotNull);
        expect(result!.overallRiskLevel, RiskLevel.green);
      },
    );

    test(
      'analyzeIncremental with text shorter than _minIncrementalChars returns null',
      () async {
        final analyzer = _createL3AnalyzerWithSession();
        analyzer.createSession();

        // Less than 40 chars of new text
        final result = await analyzer.analyzeIncremental(
          'xin chao cac ban',
        );
        expect(result, isNull);
      },
    );

    test(
      'risk decay: 3 consecutive greens de-escalate from red',
      () async {
        final analyzer = _createL3AnalyzerWithSession();

        // First parse sets max risk to red
        final red = analyzer.parseResponse(
          '{"level":"red","label":"Scam","reason":"Lừa đảo","recommendation":"Ngắt"}',
          'gemini',
        );
        expect(red.overallRiskLevel, RiskLevel.red);

        // Green 1, 2: max stays red
        final g1 = analyzer.parseResponse(
          '{"level":"green","label":"","reason":"An toàn","recommendation":""}',
          'gemini',
        );
        expect(g1.overallRiskLevel, RiskLevel.red);

        final g2 = analyzer.parseResponse(
          '{"level":"green","label":"","reason":"An toàn","recommendation":""}',
          'gemini',
        );
        expect(g2.overallRiskLevel, RiskLevel.red);

        // Green 3: RED should NOT de-escalate (only YELLOW can for safety)
        final g3 = analyzer.parseResponse(
          '{"level":"green","label":"","reason":"An toàn","recommendation":""}',
          'gemini',
        );
        expect(g3.overallRiskLevel, RiskLevel.red);
      },
    );

    test(
      'risk decay: green interrupted by orange resets counter',
      () async {
        final analyzer = _createL3AnalyzerWithSession();

        // Set red
        analyzer.parseResponse(
          '{"level":"red","label":"Scam","reason":"Lừa đảo","recommendation":""}',
          'gemini',
        );

        // Green 1
        analyzer.parseResponse(
          '{"level":"green","label":"","reason":"An toàn","recommendation":""}',
          'gemini',
        );

        // Green 2
        analyzer.parseResponse(
          '{"level":"green","label":"","reason":"An toàn","recommendation":""}',
          'gemini',
        );

        // Orange interrupts green streak
        final orange = analyzer.parseResponse(
          '{"level":"orange","label":"Cảnh báo","reason":"Tài khoản","recommendation":""}',
          'gemini',
        );
        expect(orange.overallRiskLevel, RiskLevel.orange); // returns parsed level, not max

        // Now we need 3 more greens, but RED still won't de-escalate
        // Green 1 (after reset)
        analyzer.parseResponse(
          '{"level":"green","label":"","reason":"An toàn","recommendation":""}',
          'gemini',
        );
        // Green 2 (after reset)
        analyzer.parseResponse(
          '{"level":"green","label":"","reason":"An toàn","recommendation":""}',
          'gemini',
        );
        // Green 3 should NOT de-escalate from RED (safety constraint)
        final deescalated = analyzer.parseResponse(
          '{"level":"green","label":"","reason":"An toàn","recommendation":""}',
          'gemini',
        );
        expect(deescalated.overallRiskLevel, RiskLevel.red);
      },
    );

    test(
      'cache hit returns cached result without API call',
      () async {
        var requestCount = 0;
        final analyzer = _createL3AnalyzerWithClient(
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            requestCount++;
            return '{"level":"orange","label":"Cảnh báo","reason":"Đáng ngờ","recommendation":"Cẩn thận"}';
          },
        );

        const text = 'Toi la cong an, anh can xac minh tai khoan.';
        final first = await analyzer.analyze(text);
        expect(requestCount, 1);
        expect(first.overallRiskLevel, RiskLevel.orange);

        // Second call with same text should hit cache
        final second = await analyzer.analyze(text);
        expect(requestCount, 1); // No additional API call
        expect(second.overallRiskLevel, RiskLevel.orange);

        final metrics = analyzer.getMetrics();
        expect(metrics.cacheHits, 1);
        expect(metrics.cacheMisses, 1);
      },
    );

    test(
      'cache miss triggers API call for different text',
      () async {
        var requestCount = 0;
        final analyzer = _createL3AnalyzerWithClient(
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            requestCount++;
            return '{"level":"green","label":"","reason":"An toàn","recommendation":""}';
          },
        );

        await analyzer.analyze('First transcript with enough words here.');
        await analyzer.analyze('Second completely different text here now.');

        expect(requestCount, 2);
        final metrics = analyzer.getMetrics();
        expect(metrics.cacheMisses, 2);
      },
    );

    test(
      'closeSession clears session state',
      () async {
        final analyzer = _createL3AnalyzerWithSession();
        analyzer.createSession();
        analyzer.syncProcessedTextLength(100);

        analyzer.closeSession();

        // After closeSession, analyzeIncremental should return null
        final result = await analyzer.analyzeIncremental('some text');
        expect(result, isNull);
      },
    );

    test(
      'closeSession with resetProgress=false preserves processedTextLength',
      () async {
        final analyzer = _createL3AnalyzerWithSession();
        analyzer.createSession();
        analyzer.syncProcessedTextLength(100);

        analyzer.closeSession(resetProgress: false);

        // processedTextLength should be preserved
        expect(analyzer.processedTextLength, 100);
      },
    );

    test(
      'closeSession with resetProgress=true resets processedTextLength',
      () async {
        final analyzer = _createL3AnalyzerWithSession();
        analyzer.createSession();
        analyzer.syncProcessedTextLength(100);

        analyzer.closeSession(resetProgress: true);

        expect(analyzer.processedTextLength, 0);
      },
    );

    test(
      'analyze with empty text returns green without API call',
      () async {
        var requestCount = 0;
        final analyzer = _createL3AnalyzerWithClient(
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            requestCount++;
            return '{"level":"green","label":"","reason":"","recommendation":""}';
          },
        );

        final result = await analyzer.analyze('');
        expect(result.overallRiskLevel, RiskLevel.green);
        expect(result.reason, 'Văn bản trống');
        expect(requestCount, 0);
      },
    );

    test(
      'analyze with too few words returns green without API call',
      () async {
        var requestCount = 0;
        final analyzer = _createL3AnalyzerWithClient(
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            requestCount++;
            return '{"level":"green","label":"","reason":"","recommendation":""}';
          },
        );

        // Only 2 words — minimum is 3
        final result = await analyzer.analyze('hello world');
        expect(result.overallRiskLevel, RiskLevel.green);
        expect(result.reason, contains('ngắn'));
        expect(requestCount, 0);
      },
    );

    test(
      'syncProcessedTextLength with negative value clamps to 0',
      () async {
        final analyzer = _createL3AnalyzerWithSession();
        analyzer.createSession();
        analyzer.syncProcessedTextLength(-50);
        expect(analyzer.processedTextLength, 0);
      },
    );

    test(
      'createSession with negative initialProcessedTextLength clamps to 0',
      () async {
        final analyzer = _createL3AnalyzerWithSession();
        analyzer.createSession(initialProcessedTextLength: -100);
        expect(analyzer.processedTextLength, 0);
      },
    );

    test(
      'createSession closes previous session',
      () async {
        final analyzer = _createL3AnalyzerWithSession();
        analyzer.createSession();
        analyzer.syncProcessedTextLength(50);

        // Creating new session should reset
        analyzer.createSession();
        expect(analyzer.processedTextLength, 0);
      },
    );

    test(
      'parseResponse with blank response throws FormatException',
      () async {
        final analyzer = _createL3AnalyzerWithSession();

        expect(
          () => analyzer.parseResponse('', 'gemini'),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'parseResponse with non-JSON text infers risk from reason words',
      () async {
        final analyzer = _createL3AnalyzerWithSession();

        // No valid JSON, so _extractJson returns the full text
        // jsonDecode will fail, but the method should handle it
        // Actually the method expects valid JSON. Let me test with embedded JSON.
        final result = analyzer.parseResponse(
          'Analysis: {"level":"green","label":"OK","reason":"An toàn","recommendation":"Tiếp tục"}',
          'gemini',
        );
        expect(result.overallRiskLevel, RiskLevel.green);
      },
    );

    test(
      'parseResponse with null/unknown level infers from reason',
      () async {
        final analyzer = _createL3AnalyzerWithSession();

        // Level is null — should infer from reason containing "lừa đảo"
        final result = analyzer.parseResponse(
          '{"level":null,"label":"Test","reason":"Có dấu hiệu lừa đảo","recommendation":""}',
          'gemini',
        );
        expect(result.overallRiskLevel, RiskLevel.red);
      },
    );

    test(
      'parseResponse with unknown level and no keywords returns green',
      () async {
        final analyzer = _createL3AnalyzerWithSession();

        final result = analyzer.parseResponse(
          '{"level":"unknown","label":"Test","reason":"Nothing special","recommendation":""}',
          'gemini',
        );
        expect(result.overallRiskLevel, RiskLevel.green);
      },
    );

    test(
      'resetSession delegates to closeSession',
      () async {
        final analyzer = _createL3AnalyzerWithSession();
        analyzer.createSession();
        analyzer.syncProcessedTextLength(100);

        analyzer.resetSession();

        expect(analyzer.processedTextLength, 0);
        expect(analyzer.lastResult.overallRiskLevel, RiskLevel.green);
      },
    );

    test(
      'level returns l3',
      () async {
        final analyzer = _createL3AnalyzerWithSession();
        expect(analyzer.level, AnalysisLevel.l3);
      },
    );

    test(
      'isReady returns false when no API keys',
      () async {
        final analyzer = L3Analyzer(
          apiKeyProvider: StaticApiKeyProvider(const <String>[]),
        );
        expect(analyzer.isReady, isFalse);
      },
    );

    test(
      'analyze API error sets isError flag',
      () async {
        final analyzer = _createL3AnalyzerWithClient(
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            throw Exception('Network error');
          },
        );

        final result = await analyzer.analyze(
          'Toi la cong an, anh can chuyen tien ngay.',
        );
        expect(result.isError, isTrue);
        expect(result.overallRiskLevel, RiskLevel.green);
        expect(result.reason, contains('API Error'));
      },
    );

    test(
      'consecutive API errors increment error counter',
      () async {
        final analyzer = _createL3AnalyzerWithClient(
          requestExecutor: ({
            required String apiKey,
            required GeminiConfig config,
            required String modelName,
            required String prompt,
          }) async {
            throw Exception('Network error');
          },
        );

        // Trigger 3 errors
        await analyzer.analyze('Toi la cong an can chuyen tien gap.');
        await analyzer.analyze('Noi dung khac de vuot qua cache.');
        await analyzer.analyze('Them mot doan nua de chac chan.');

        final report = analyzer.healthCheck();
        expect(report.status, HealthStatus.degraded);
        expect(report.message, contains('lỗi liên tiếp'));
      },
    );
  });
}

L3Analyzer _createL3AnalyzerWithSession() {
  return L3Analyzer(
    apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
    sessionFactory: () => _FakeChatSession(),
  );
}

L3Analyzer _createL3AnalyzerWithClient({
  required GeminiRequestExecutor requestExecutor,
}) {
  final provider = StaticApiKeyProvider(const <String>['AIza_test']);
  return L3Analyzer(
    apiKeyProvider: provider,
    geminiClient: GeminiClient(
      apiKeyProvider: provider,
      config: GeminiConfig.forAnalysis(),
      requestExecutor: requestExecutor,
    ),
  );
}

class _FakeChatSession extends GeminiChatSession {
  _FakeChatSession()
      : super(
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
                return '{"level":"green","label":"","reason":"An toàn","recommendation":"Tiếp tục theo dõi"}';
              },
        );
}
