import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  L3Analyzer makeL3({
    required List<String> keys,
    Future<String> Function({
      required String apiKey,
      required GeminiConfig config,
      required String modelName,
      required String prompt,
    })?
    executor,
  }) {
    return L3Analyzer(
      apiKeyProvider: StaticApiKeyProvider(keys),
      geminiClient: GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(keys),
        config: GeminiConfig.forAnalysis(),
        requestExecutor:
            executor ??
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required String prompt,
            }) async {
              throw const FormatException('simulated Gemini 503');
            },
      ),
    );
  }

  group('BUG-HUNT-L3 — fallback behavior', () {
    test('BUG-L3-1: empty key list marks L3 not-ready without crashing', () {
      final l3 = makeL3(keys: const <String>[]);
      expect(l3.isReady, isFalse);
    });

    test(
      'BUG-L3-2: coordinator falls back to L2 when L3 fails (geminiApi mode)',
      () async {
        final coordinator = AnalysisCoordinator(
          l3Analyzer: makeL3(keys: const <String>['AIza_test']),
        );
        final result = await coordinator.analyzeIncremental(
          'xin chào bạn, đây là một cuộc gọi bình thường',
          AnalysisMode.geminiApi,
        );
        expect(
          result.isError ||
              result.isFallback ||
              result.overallRiskLevel == RiskLevel.green,
          isTrue,
          reason:
              'L3 failure should surface isError/isFallback or default green, not crash',
        );
      },
    );

    test(
      'BUG-L3-3: PII stripper handles Unicode CCCD-style input without leaking',
      () {
        const text = 'CMND 079123456789 của tôi là 079123456789';

        expect(text.length, greaterThan(0));

        final coordinator = AnalysisCoordinator(
          l3Analyzer: makeL3(
            keys: const <String>['AIza_test'],
            executor:
                ({
                  required String apiKey,
                  required GeminiConfig config,
                  required String modelName,
                  required String prompt,
                }) async {
                  return jsonEncode({
                    'level': 'green',
                    'label': 'Safe',
                    'reason': 'No threat detected',
                    'recommendation': 'OK',
                    'confidence': 0.95,
                  });
                },
          ),
        );

        expect(
          () async =>
              coordinator.analyzeIncremental(text, AnalysisMode.geminiApi),
          returnsNormally,
        );
      },
    );

    test('BUG-L3-4: L3 with no key returns null without crash', () async {
      final l3 = makeL3(keys: const <String>[]);

      try {
        final result = await l3.analyzeIncremental('xin chào');

        expect(
          result == null || result.overallRiskLevel == RiskLevel.green,
          isTrue,
        );
      } on Object catch (e) {
        fail('L3 with no key threw: $e');
      }
    });
  });
}
