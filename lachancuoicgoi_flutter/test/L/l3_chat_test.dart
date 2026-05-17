import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_chat_session.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_metrics.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/key_health_tracker.dart';

void main() {
  setUp(() {
    GeminiMetrics.resetForTesting();
  });

  group('Phase 7 L3 Chat - GeminiChatSession', () {
    test('sendMessage luu history an toan cho lan goi tiep theo', () async {
      final historyLengths = <int>[];
      final prompts = <String>[];
      final session = GeminiChatSession(
        apiKeyProvider: StaticApiKeyProvider(const ['AIzaSyTestKey123456789']),
        config: GeminiConfig.forAnalysis(),
        chatExecutor:
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required List<Content> history,
              required String prompt,
            }) async {
              historyLengths.add(history.length);
              prompts.add(prompt);
              return '{"level":"green","label":"","reason":"An toan","recommendation":"Theo doi"}';
            },
      );

      final first = await session.sendMessage<String>(
        'Xin chao',
        (responseText, _) => responseText,
      );
      final second = await session.sendMessage<String>(
        'Can ho tro gi khong?',
        (responseText, _) => responseText,
      );

      expect(first.isSuccess, isTrue);
      expect(second.isSuccess, isTrue);
      expect(historyLengths, <int>[0, 2]);
      expect(
        prompts,
        containsAll(<String>['Xin chao', 'Can ho tro gi khong?']),
      );
    });

    test('sendMessage that bai khi khong co API key', () async {
      final session = GeminiChatSession(
        apiKeyProvider: StaticApiKeyProvider(const []),
        config: GeminiConfig.forAnalysis(),
      );

      final result = await session.sendMessage<String>(
        'Test message',
        (responseText, _) => responseText,
      );

      expect(result.isFailure, isTrue);
      expect(result.error, isA<StateError>());
    });

    test('sendMessage fallback sang key khac khi key dau invalid', () async {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaSyKeyInvalid', 'AIzaSyKeyWorking']),
      );
      final attemptedKeys = <String>[];
      final session = GeminiChatSession(
        apiKeyProvider: StaticApiKeyProvider(const [
          'AIzaSyKeyInvalid',
          'AIzaSyKeyWorking',
        ]),
        config: GeminiConfig.forAnalysis(),
        keyHealthTracker: tracker,
        chatExecutor:
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required List<Content> history,
              required String prompt,
            }) async {
              attemptedKeys.add(apiKey);
              if (apiKey.contains('Invalid')) {
                throw Exception('403 API key revoked');
              }
              return '{"level":"orange","label":"Canh bao","reason":"Nghi ngo","recommendation":"Can than"}';
            },
      );

      final result = await session.sendMessage<String>(
        'Toi can xac minh lai',
        (responseText, _) => responseText,
      );

      expect(result.isSuccess, isTrue);
      expect(attemptedKeys, <String>['AIzaSyKeyInvalid', 'AIzaSyKeyWorking']);
      final summary = tracker.getHealthSummary();
      expect(summary[0].status, KeyStatus.exhausted);
      expect(summary[1].status, KeyStatus.active);
    });

    test(
      'sendMessage fail som khi tat ca key deu cooldown hoac exhausted',
      () async {
        final provider = StaticApiKeyProvider(const [
          'AIzaSyKeyInvalid',
          'AIzaSyKeyQuota',
        ]);
        final tracker = KeyHealthTracker(provider)
          ..markInvalid(0)
          ..markInvalid(1);
        final session = GeminiChatSession(
          apiKeyProvider: provider,
          config: GeminiConfig.forAnalysis(),
          keyHealthTracker: tracker,
        );

        final result = await session.sendMessage<String>(
          'Test message',
          (responseText, _) => responseText,
        );

        expect(result.isFailure, isTrue);
        expect(result.error, isA<StateError>());
      },
    );
  });

  group('Phase 7 L3 Chat - GeminiClient', () {
    test(
      'GeminiClient fallback qua model tiep theo khi model dau khong ton tai',
      () async {
        final attemptedModels = <String>[];
        final client = GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const [
            'AIzaSyTestKey123456789',
          ]),
          config: GeminiConfig.forAnalysis(),
          requestExecutor:
              ({
                required String apiKey,
                required GeminiConfig config,
                required String modelName,
                required String prompt,
              }) async {
                attemptedModels.add(modelName);
                if (attemptedModels.length < 3) {
                  throw Exception('404 model not found');
                }
                return '{"level":"green","label":"","reason":"An toan","recommendation":"Theo doi"}';
              },
        );

        final result = await client.query<String>(
          'Phan tich cuoc goi nay',
          (_, modelName) => modelName,
        );

        expect(result.isSuccess, isTrue);
        expect(attemptedModels, <String>[
          'gemini-3.1-flash-lite',
          'gemini-2.5-flash-lite',
          'gemini-3-flash',
        ]);
        expect(result.getOrThrow(), 'gemini-3-flash');
        final snapshot = GeminiMetrics.instance.getSnapshot();
        expect(snapshot.totalApiCalls, 1);
        expect(snapshot.successCalls, 1);
        expect(snapshot.perKeyMetrics.single.index, 0);
      },
    );

    test(
      'GeminiClient thong bao exhausted keys mot lan khi khong con key active',
      () async {
        final provider = StaticApiKeyProvider(const [
          'AIzaSyKey1Revoked',
          'AIzaSyKey2Revoked',
        ]);
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

        final first = await client.query<String>('prompt', (text, _) => text);
        final second = await client.query<String>('prompt', (text, _) => text);

        expect(first.isFailure, isTrue);
        expect(second.isFailure, isTrue);
        expect(notifyCount, 1);
        expect(first.error, isA<StateError>());
      },
    );
  });
}
