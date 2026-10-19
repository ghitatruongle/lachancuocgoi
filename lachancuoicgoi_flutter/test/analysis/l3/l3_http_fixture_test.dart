import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('L3 HTTP Fixture & Resilience Edge-case Tests', () {
    test(
      'Handles malformed JSON response gracefully without throwing',
      () async {
        final l3 = L3Analyzer(
          apiKeyProvider: StaticApiKeyProvider(const ['AIza_fake_key']),
          geminiClient: GeminiClient(
            apiKeyProvider: StaticApiKeyProvider(const ['AIza_fake_key']),
            config: GeminiConfig.forAnalysis(),
            requestExecutor:
                ({
                  required String apiKey,
                  required GeminiConfig config,
                  required String modelName,
                  required String prompt,
                }) async {
                  return 'THIS IS NOT VALID JSON {[[}';
                },
          ),
        );

        final result = await l3.analyze(
          'Xin chào bạn, đây là cuộc gọi kiểm thử nội dung dài.',
        );
        expect(result.overallRiskLevel, equals(RiskLevel.green));
        expect(result.isError, isTrue);
      },
    );

    test(
      'Parses valid scam JSON response correctly with high risk level',
      () async {
        final l3 = L3Analyzer(
          apiKeyProvider: StaticApiKeyProvider(const ['AIza_fake_key']),
          geminiClient: GeminiClient(
            apiKeyProvider: StaticApiKeyProvider(const ['AIza_fake_key']),
            config: GeminiConfig.forAnalysis(),
            requestExecutor:
                ({
                  required String apiKey,
                  required GeminiConfig config,
                  required String modelName,
                  required String prompt,
                }) async {
                  return jsonEncode({
                    'level': 'red',
                    'label': 'Giả danh công an yêu cầu chuyển tiền',
                    'reason':
                        'Đối tượng yêu cầu chuyển tiền khẩn cấp vào tài khoản tạm giữ',
                    'recommendation': 'Tắt máy ngay lập tức',
                    'confidence': 0.98,
                  });
                },
          ),
        );

        final result = await l3.analyze(
          'Yêu cầu bạn chuyển tiền vào tài khoản an toàn của công an để điều tra.',
        );
        expect(result.overallRiskLevel, equals(RiskLevel.red));
        expect(result.matches.first.keyword, contains('Giả danh công an'));
      },
    );

    test('Short input under 3 words returns green risk level early', () async {
      final l3 = L3Analyzer(
        apiKeyProvider: StaticApiKeyProvider(const ['AIza_fake_key']),
      );

      final result = await l3.analyze('Alo ai');
      expect(result.overallRiskLevel, equals(RiskLevel.green));
      expect(result.reason, contains('Nội dung quá ngắn'));
    });
  });
}
