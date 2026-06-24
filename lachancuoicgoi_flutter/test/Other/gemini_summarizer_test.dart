import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/gemini_summarizer.dart';

void main() {
  group('GeminiSummarizer', () {
    test('returns min-words message for short input', () async {
      final summarizer = GeminiSummarizer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      final result = await summarizer.summarize('Xin chào');

      expect(result, contains('Không đủ nội dung'));
      expect(result, contains('5'));
    });

    test('returns min-words message for empty string', () async {
      final summarizer = GeminiSummarizer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      final result = await summarizer.summarize('');

      expect(result, contains('Không đủ nội dung'));
    });

    test('returns min-words message for whitespace-only input', () async {
      final summarizer = GeminiSummarizer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
      );

      final result = await summarizer.summarize('   \n  \t  ');

      expect(result, contains('Không đủ nội dung'));
    });

    test('calls Gemini API for text with enough words', () async {
      const expectedSummary = 'Cuộc gọi giả danh công an yêu cầu chuyển tiền.';
      final summarizer = GeminiSummarizer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        geminiClient: GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
          config: GeminiConfig.forSummarization(),
          requestExecutor:
              ({
                required String apiKey,
                required GeminiConfig config,
                required String modelName,
                required String prompt,
              }) async {
                return expectedSummary;
              },
        ),
      );

      final result = await summarizer.summarize(
        'Tôi là công an đang điều tra hồ sơ của anh phải chuyển tiền ngay.',
      );

      expect(result, expectedSummary);
    });

    test('returns error message on API failure', () async {
      final summarizer = GeminiSummarizer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        geminiClient: GeminiClient(
          apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
          config: GeminiConfig.forSummarization(),
          requestExecutor:
              ({
                required String apiKey,
                required GeminiConfig config,
                required String modelName,
                required String prompt,
              }) async {
                throw Exception('Network timeout');
              },
        ),
      );

      final result = await summarizer.summarize(
        'Tôi là công an đang điều tra hồ sơ của anh phải chuyển tiền ngay.',
      );

      expect(result, contains('Lỗi tóm tắt'));
    });
  });
}
