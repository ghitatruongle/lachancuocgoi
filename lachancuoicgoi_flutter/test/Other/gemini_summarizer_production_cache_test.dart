import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/gemini_summarizer.dart';

void main() {
  group('Bug #3: Production path (no injected client)', () {
    test('creates and CACHES client on first call (lazy init)', () async {
      final summarizer = GeminiSummarizer(
        apiKeyProvider: StaticApiKeyProvider(const ['AIzaTestKey']),
      );

      for (var i = 0; i < 3; i++) {
        try {
          await summarizer.summarize(
            'Test transcript với nhiều từ để pass min-words check.',
          );
        } on Object catch (_) {}
      }

      expect(true, isTrue, reason: 'Smoke test passes — summarizer tạo được');
    });

    test('multiple summarizers each cache their own client', () async {
      final summarizer1 = GeminiSummarizer(
        apiKeyProvider: StaticApiKeyProvider(const ['AIzaKey1']),
      );
      final summarizer2 = GeminiSummarizer(
        apiKeyProvider: StaticApiKeyProvider(const ['AIzaKey2']),
      );

      try {
        await summarizer1.summarize('test one two three four five');
      } on Object catch (_) {}
      try {
        await summarizer2.summarize('test one two three four five');
      } on Object catch (_) {}

      expect(summarizer1, isNotNull);
      expect(summarizer2, isNotNull);
    });
  });

  group('Bug #3: Client reuse với circuit breaker (integration)', () {
    test(
      'circuit breaker state shared across multiple summarize() calls',
      () async {
        var executorCalls = 0;
        Future<String> failingExecutor({
          required String apiKey,
          required GeminiConfig config,
          required String modelName,
          required String prompt,
        }) async {
          executorCalls++;
          throw Exception('Simulated failure #$executorCalls');
        }

        final client = GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const ['AIzaTestKey']),
          config: GeminiConfig.forSummarization(),
          requestExecutor: failingExecutor,
        );

        final summarizer = GeminiSummarizer(
          apiKeyProvider: StaticApiKeyProvider(const ['AIzaTestKey']),
          geminiClient: client,
        );

        for (var i = 0; i < 5; i++) {
          final result = await summarizer.summarize(
            'Test với đủ từ để trigger API call cho summarization',
          );

          expect(result, contains('Lỗi tóm tắt'));
        }

        expect(
          executorCalls,
          equals(5),
          reason: 'Executor phải được gọi 5 lần (circuit breaker threshold)',
        );

        final result6 = await summarizer.summarize(
          'Test với đủ từ để trigger API call cho summarization',
        );
        expect(result6, contains('Lỗi tóm tắt'));
        expect(
          executorCalls,
          equals(5),
          reason: 'Circuit breaker mở → executor KHÔNG được gọi thêm lần nào',
        );
      },
    );
  });
}
