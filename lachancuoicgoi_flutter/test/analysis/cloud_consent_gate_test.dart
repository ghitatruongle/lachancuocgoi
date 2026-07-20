import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';
import 'package:lachancuocgoi_flutter/data/cloud_analysis_consent_store.dart';

void main() {
  group('Cloud analysis consent gate', () {
    test('GeminiClient does not invoke executor without consent', () async {
      var executorCalls = 0;
      final client = GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        config: GeminiConfig.forAnalysis(),
        cloudConsentStore: const _ConsentStore(false),
        requestExecutor:
            ({
              required apiKey,
              required config,
              required modelName,
              required prompt,
            }) async {
              executorCalls++;
              return '{}';
            },
      );

      final result = await client.query<String>('sensitive text', (text, _) {
        return text;
      });

      expect(result.isFailure, isTrue);
      expect(executorCalls, 0);
    });

    test('L3 returns typed fallback error without consent', () async {
      final analyzer = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const <String>['AIza_test']),
        cloudConsentStore: const _ConsentStore(false),
      );

      final result = await analyzer.analyze('đây là nội dung đủ dài để gửi');

      expect(result.isError, isTrue);
      expect(result.isFallback, isTrue);
      expect(result.reason, contains('L1+L2'));
    });
  });
}

class _ConsentStore extends CloudAnalysisConsentStore {
  const _ConsentStore(this.granted);

  final bool granted;

  @override
  bool get isGranted => granted;
}
