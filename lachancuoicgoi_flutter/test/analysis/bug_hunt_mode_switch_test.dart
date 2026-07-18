// Bug Hunt Phase B.2 — Audit 4 analysis modes (Mục 2)
//
// Tests mode switching state boundary + parallel mode timeout + L3 readiness
// fallback. Reference: docs/superpowers/specs/.../Mục 2 — 4 chế độ phân tích.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode_policy.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_client.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_config.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  L3Analyzer makeL3Slow({required List<String> keys, int delayMs = 2000}) {
    return L3Analyzer(
      apiKeyProvider: StaticApiKeyProvider(keys),
      geminiClient: GeminiClient(
        apiKeyProvider: StaticApiKeyProvider(keys),
        config: GeminiConfig.forAnalysis(),
        requestExecutor:
            ({
              required String apiKey,
              required GeminiConfig config,
              required String modelName,
              required String prompt,
            }) async {
              await Future<void>.delayed(Duration(milliseconds: delayMs));
              return jsonEncode({
                'level': 'green',
                'label': 'Safe',
                'reason': 'No threat',
                'recommendation': 'OK',
                'confidence': 0.9,
              });
            },
      ),
    );
  }

  group('BUG-HUNT-MODE — switching AnalysisMode mid-call', () {
    test(
      'BUG-MODE-1: mode switch resets processedTextLength consistently',
      () async {
        final coordinator = AnalysisCoordinator();
        await coordinator.analyzeIncremental('x' * 200, AnalysisMode.normal);
        final l1Length = coordinator.getProcessedTextLength(
          AnalysisMode.normal,
        );
        expect(l1Length, 200);
        // Switching to L2 mode must start from 0 (independent state).
        final l2Length = coordinator.getProcessedTextLength(
          AnalysisMode.gDetection,
        );
        expect(l2Length, 0);
      },
    );

    test('BUG-MODE-2: parallel mode respects 800ms L3 timeout', () async {
      final coordinator = AnalysisCoordinator(
        l3Analyzer: makeL3Slow(
          keys: const <String>['AIza_test'],
          delayMs: 3000, // 3s, exceeds 800ms timeout
        ),
      );
      final sw = Stopwatch()..start();
      final result = await coordinator.analyzeIncremental(
        'x' * 200,
        AnalysisMode.parallel,
      );
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(1500),
        reason:
            'Parallel analyze should respect 800ms L3 timeout even when L3 stalls',
      );
      expect(result.overallRiskLevel, RiskLevel.green);
    });

    test('BUG-MODE-3: effective mode = selected mode when network ok', () {
      final state = AnalysisModePolicy.createRuntimeState(
        AnalysisMode.parallel,
        true,
      );
      expect(state.effectiveMode, AnalysisMode.parallel);
      expect(state.isFallbackActive, isFalse);
    });

    test('BUG-MODE-4: parallel fallback to L2/L1 when L3 not ready', () async {
      final coordinator = AnalysisCoordinator(
        l3Analyzer: L3Analyzer(
          apiKeyProvider: StaticApiKeyProvider(const <String>[]),
        ),
      );
      final result = await coordinator.analyzeIncremental(
        'x' * 200,
        AnalysisMode.parallel,
      );
      // Should not throw — must produce a valid result.
      expect(
        result.overallRiskLevel,
        anyOf(RiskLevel.green, RiskLevel.orange, RiskLevel.red),
      );
    });

    test(
      'BUG-MODE-5: resetMode(parallel) clears cached parallel result',
      () async {
        final coordinator = AnalysisCoordinator(
          l3Analyzer: makeL3Slow(keys: const <String>['AIza_test']),
        );
        // Prime the cache with first call.
        final first = await coordinator.analyzeIncremental(
          'x' * 200,
          AnalysisMode.parallel,
        );
        expect(first.analysisLevel.name, anyOf('l1', 'l2', 'l3'));
        // After reset, second call must NOT reuse old processedTextLength.
        coordinator.resetMode(AnalysisMode.parallel);
        final after = coordinator.getProcessedTextLength(AnalysisMode.parallel);
        expect(
          after,
          0,
          reason: 'resetMode(parallel) must clear processedTextLength',
        );
      },
    );
  });
}
