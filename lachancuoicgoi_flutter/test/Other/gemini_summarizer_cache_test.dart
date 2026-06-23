import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/gemini_summarizer.dart';

void main() {
  group('Bug #3: GeminiSummarizer caches client', () {
    test('reuses same client instance across multiple calls', () async {
      var executorCallCount = 0;

      Future<String> fakeExecutor({
        required String apiKey,
        required GeminiConfig config,
        required String modelName,
        required String prompt,
      }) async {
        executorCallCount++;
        return 'Tóm tắt test';
      }

      final client = GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(const ['test-key']),
        config: GeminiConfig.forSummarization(),
        requestExecutor: fakeExecutor,
      );

      final summarizer = GeminiSummarizer(
        apiKeyProvider: StaticApiKeyProvider(const ['test-key']),
        keyHealthTracker: null,
        geminiClient: client,
      );

      for (var i = 0; i < 3; i++) {
        final result = await summarizer.summarize(
          'Test transcript with enough words for summarization to work',
        );
        expect(result, equals('Tóm tắt test'));
      }

      expect(executorCallCount, equals(3));
    });

    test('circuit breaker trips after 5 failures with same client', () async {
      var executorCallCount = 0;

      Future<String> failingExecutor({
        required String apiKey,
        required GeminiConfig config,
        required String modelName,
        required String prompt,
      }) async {
        executorCallCount++;
        throw Exception('API error');
      }

      final client = GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(const ['test-key']),
        config: GeminiConfig.forSummarization(),
        requestExecutor: failingExecutor,
      );

      final summarizer = GeminiSummarizer(
        apiKeyProvider: StaticApiKeyProvider(const ['test-key']),
        keyHealthTracker: null,
        geminiClient: client,
      );

      // 5 failures → circuit breaker trips
      for (var i = 0; i < 5; i++) {
        try {
          await summarizer.summarize(
            'Test with enough words to trigger summarization API call',
          );
        } on Object catch (_) {}
      }

      // 6th call blocked by circuit breaker
      executorCallCount = 0;
      try {
        await summarizer.summarize(
          'Test with enough words to trigger summarization API call',
        );
      } on Object catch (_) {}

      expect(executorCallCount, equals(0),
          reason: 'Circuit breaker should block calls after 5 failures');
    });
  });
}
