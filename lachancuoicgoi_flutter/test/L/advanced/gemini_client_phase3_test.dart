import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';

void main() {
  group('GeminiClient — Phase 3: exponential backoff', () {
    test('retries with increasing delays on quota errors', () async {
      final timestamps = <DateTime>[];
      final client = GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(const ['AIzaKey1']),
        config: GeminiConfig.forAnalysis(),
        requestExecutor:
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required String prompt,
            }) async {
              timestamps.add(DateTime.now());
              throw Exception('429 Too Many Requests — quota exceeded');
            },
      );

      await client.query<String>('test', (text, _) => text);

      // quota error → continue → tries all 5 fallback models
      expect(timestamps.length, 5);

      // Check delays increase: ~0ms, ~1000ms, ~2000ms
      final delay1 = timestamps[1].difference(timestamps[0]).inMilliseconds;
      final delay2 = timestamps[2].difference(timestamps[1]).inMilliseconds;

      // First retry: ~1s
      expect(delay1, greaterThan(800));
      expect(delay1, lessThan(1500));
      // Second retry: ~2s
      expect(delay2, greaterThan(1500));
      expect(delay2, lessThan(2500));
    });

    test('no delay on first attempt', () async {
      final timestamps = <DateTime>[];
      final client = GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(const ['AIzaKey1']),
        config: GeminiConfig.forAnalysis(),
        requestExecutor:
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required String prompt,
            }) async {
              timestamps.add(DateTime.now());
              return '{"level":"green","label":"","reason":"ok","recommendation":""}';
            },
      );

      final result = await client.query<String>('test', (text, _) => text);
      expect(result.isSuccess, isTrue);
      expect(timestamps.length, 1);
    });

    test(
      'unknown error does not retry all models (breaks immediately)',
      () async {
        var callCount = 0;
        final client = GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const ['AIzaKey1']),
          config: GeminiConfig.forAnalysis(),
          requestExecutor:
              ({
                required String apiKey,
                required GeminiConfig config,
                required String modelName,
                required String prompt,
              }) async {
                callCount++;
                throw Exception('Unknown server error');
              },
        );

        await client.query<String>('test', (text, _) => text);

        // Unknown error → break (not continue) → only 1 model tried
        expect(callCount, 1);
      },
    );

    test('auth error does not retry (breaks immediately)', () async {
      var callCount = 0;
      final client = GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(const ['AIzaKey1']),
        config: GeminiConfig.forAnalysis(),
        requestExecutor:
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required String prompt,
            }) async {
              callCount++;
              throw Exception('401 Unauthorized — invalid API key');
            },
      );

      await client.query<String>('test', (text, _) => text);

      // Auth error → break immediately
      expect(callCount, 1);
    });

    test('circuit breaker still works with exponential backoff', () async {
      var callCount = 0; // ignore: unused_local_variable
      final client = GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(const ['AIzaKey1']),
        config: GeminiConfig.forAnalysis(),
        requestExecutor:
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required String prompt,
            }) async {
              callCount++;
              throw Exception('429 quota exceeded');
            },
      );

      // _recordFailure() is called per model attempt (3 per query).
      // Circuit breaker opens after 5 consecutive failures.
      // Query 1: 3 failures (total: 3)
      // Query 2: 3 failures (total: 6, circuit opens at 5)
      // Query 3: blocked by circuit breaker
      for (var i = 0; i < 3; i++) {
        await client.query<String>('fail', (text, _) => text);
      }

      // 4th query should be blocked by circuit breaker
      final result = await client.query<String>('fail', (text, _) => text);
      expect(result.isFailure, isTrue);
      expect(result.error.toString(), contains('Circuit breaker open'));
    });

    test('success after retry resets backoff', () async {
      var callCount = 0;
      final client = GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(const ['AIzaKey1']),
        config: GeminiConfig.forAnalysis(),
        requestExecutor:
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required String prompt,
            }) async {
              callCount++;
              if (callCount == 1) {
                throw Exception('429 quota exceeded');
              }
              return '{"level":"green","label":"","reason":"ok","recommendation":""}';
            },
      );

      final result = await client.query<String>('test', (text, _) => text);
      expect(result.isSuccess, isTrue);
      // First model failed (quota), second model succeeded
      expect(callCount, 2);
    });
  });

  group('GeminiClient — Phase 3: timeout configuration', () {
    test('forAnalysis config has 15s timeout', () {
      final config = GeminiConfig.forAnalysis();
      expect(config.timeout, const Duration(seconds: 15));
    });

    test('forSummarization config has 30s timeout', () {
      final config = GeminiConfig.forSummarization();
      expect(config.timeout, const Duration(seconds: 30));
    });
  });
}
