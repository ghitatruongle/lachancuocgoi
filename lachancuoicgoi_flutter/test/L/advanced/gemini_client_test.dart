import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/key_health_tracker.dart';

void main() {
  group('GeminiClient — circuit breaker', () {
    test('circuit closes after consecutiveFailures < threshold', () async {
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
              return '{"level":"green","label":"","reason":"ok","recommendation":""}';
            },
      );

      final result = await client.query<String>('safe', (text, _) => text);
      expect(result.isSuccess, isTrue);
    });

    test('circuit breaker opens after 5 consecutive failures', () async {
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
              throw Exception('Server error');
            },
      );

      for (var i = 0; i < 5; i++) {
        await client.query<String>('fail', (text, _) => text);
      }
      final result = await client.query<String>('fail', (text, _) => text);

      expect(result.isFailure, isTrue);
      expect(result.error, isA<StateError>());
      expect(result.error.toString(), contains('Circuit breaker open'));
      expect(callCount, 5);
    });

    test(
      'successful call after 4 failures resets counter (stays below threshold)',
      () async {
        var failCount = 0;
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
                failCount++;
                if (failCount <= 4) throw Exception('Error');
                return '{"level":"green","label":"","reason":"ok","recommendation":""}';
              },
        );

        await client.query<String>('fail', (text, _) => text);
        await client.query<String>('fail', (text, _) => text);
        await client.query<String>('fail', (text, _) => text);
        await client.query<String>('fail', (text, _) => text);

        final result = await client.query<String>('success', (text, _) => text);
        expect(result.isSuccess, isTrue);
      },
    );
  });

  group('GeminiClient — model fallback chain', () {
    test('falls through all fallback models before failing', () async {
      final attemptedModels = <String>[];
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
              attemptedModels.add(modelName);
              throw Exception('404 model not found');
            },
      );

      final result = await client.query<String>('prompt', (text, _) => text);

      expect(result.isFailure, isTrue);
      expect(attemptedModels, <String>[
        'gemini-3.5-flash',
        'gemini-3.1-flash-lite',
        'gemini-3-flash',
        'gemini-2.5-flash',
        'gemini-2.5-flash-lite',
      ]);
    });

    test('succeeds on 3rd fallback model', () async {
      var attempts = 0;
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
              attempts++;
              if (attempts < 3) throw Exception('404 model not found');
              return '{"level":"green","label":"","reason":"ok","recommendation":""}';
            },
      );

      final result = await client.query<String>(
        'prompt',
        (text, modelName) => modelName,
      );

      expect(result.isSuccess, isTrue);
      expect(result.getOrThrow(), 'gemini-3-flash');
      expect(attempts, 3);
    });
  });

  group('GeminiClient — key fallback', () {
    test(
      'falls back to second key when first key fails with auth error',
      () async {
        // Pre-exhaust key 0 so only key 1 is active — this ensures deterministic
        // behavior regardless of shuffle order in getActiveKeyIndices().
        final provider = StaticApiKeyProvider(const [
          'AIzaExhaustedKey',
          'AIzaWorkingKey',
        ]);
        final tracker = KeyHealthTracker(provider);
        tracker.markInvalid(0, 'pre-exhausted for test');

        final attemptedKeys = <String>{};
        final client = GeminiClient(
          apiKeyProvider: provider,
          config: GeminiConfig.forAnalysis(),
          keyHealthTracker: tracker,
          requestExecutor:
              ({
                required String apiKey,
                required GeminiConfig config,
                required String modelName,
                required String prompt,
              }) async {
                attemptedKeys.add(apiKey);
                return '{"level":"green","label":"","reason":"ok","recommendation":""}';
              },
        );

        final result = await client.query<String>('prompt', (text, _) => text);

        expect(result.isSuccess, isTrue);
        expect(attemptedKeys, contains('AIzaWorkingKey'));
        expect(attemptedKeys, isNot(contains('AIzaExhaustedKey')));
        // Exhausted key stays exhausted, working key stays active
        final summary = tracker.getHealthSummary();
        expect(summary[0].status, KeyStatus.exhausted);
        expect(summary[1].status, KeyStatus.active);
      },
    );

    test('fails when all keys are exhausted', () async {
      final tracker =
          KeyHealthTracker(StaticApiKeyProvider(const ['AIzaKey1', 'AIzaKey2']))
            ..markInvalid(0)
            ..markInvalid(1);
      final client = GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(const ['AIzaKey1', 'AIzaKey2']),
        config: GeminiConfig.forAnalysis(),
        keyHealthTracker: tracker,
      );

      final result = await client.query<String>('prompt', (text, _) => text);
      expect(result.isFailure, isTrue);
      expect(result.error, isA<StateError>());
    });

    test('all keys exhausted callback fires at most once', () async {
      final provider = StaticApiKeyProvider(const ['AIzaK1', 'AIzaK2']);
      final tracker = KeyHealthTracker(provider)
        ..markInvalid(0)
        ..markInvalid(1);
      var notifyCount = 0;
      final client = GeminiClient(
        apiKeyProvider: provider,
        config: GeminiConfig.forAnalysis(),
        keyHealthTracker: tracker,
        onAllKeysExhausted: () {
          notifyCount++;
        },
      );

      await client.query<String>('p1', (text, _) => text);
      await client.query<String>('p2', (text, _) => text);

      expect(notifyCount, 1);
    });
  });

  group('GeminiClient — error classification', () {
    test('classifies 429 as quota error — key goes to cooldown', () async {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      final client = GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(const ['AIzaKey1']),
        config: GeminiConfig.forAnalysis(),
        keyHealthTracker: tracker,
        requestExecutor:
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required String prompt,
            }) async {
              throw Exception('429 Too Many Requests');
            },
      );

      await client.query<String>('prompt', (text, _) => text);

      expect(tracker.getHealthSummary()[0].status, KeyStatus.cooldown);
      expect(tracker.getHealthSummary()[0].lastErrorMessage, contains('429'));
    });

    test('classifies 403 as auth error — key goes to exhausted', () async {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      final client = GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(const ['AIzaKey1']),
        config: GeminiConfig.forAnalysis(),
        keyHealthTracker: tracker,
        requestExecutor:
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required String prompt,
            }) async {
              throw Exception('403 API key not valid');
            },
      );

      await client.query<String>('prompt', (text, _) => text);

      expect(tracker.getHealthSummary()[0].status, KeyStatus.exhausted);
    });
  });

  group('GeminiClient — edge cases', () {
    test('empty keys returns failure immediately', () async {
      final client = GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(const <String>[]),
        config: GeminiConfig.forAnalysis(),
      );

      final result = await client.query<String>('prompt', (text, _) => text);

      expect(result.isFailure, isTrue);
      expect(result.error, isA<StateError>());
      expect(result.error.toString(), contains('No API keys'));
    });

    test('timeout error classification', () async {
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
              throw TimeoutException('Request timed out');
            },
      );

      final result = await client.query<String>('prompt', (text, _) => text);
      expect(result.isFailure, isTrue);
    });

    test('network error classification', () async {
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
              throw Exception('SocketException: Connection refused');
            },
      );

      final result = await client.query<String>('prompt', (text, _) => text);
      expect(result.isFailure, isTrue);
    });
  });
}
