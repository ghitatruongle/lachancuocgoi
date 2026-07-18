// Bug Hunt Phase B.2 + C.3 — Parallel mode concurrent + race condition tests
//
// Reference: docs/superpowers/specs/.../Mục 2 + Phase C parallel stress.

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_coordinator.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/l3_analysis.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'BUG-PARALLEL-1: 2 concurrent analyzeIncremental calls complete cleanly',
    () async {
      final coordinator = AnalysisCoordinator(
        l3Analyzer: L3Analyzer(
          apiKeyProvider: StaticApiKeyProvider(const <String>[]),
        ),
      );
      final f1 = coordinator.analyzeIncremental(
        'y' * 300,
        AnalysisMode.parallel,
      );
      final f2 = coordinator.analyzeIncremental(
        'y' * 300,
        AnalysisMode.parallel,
      );
      final results = await Future.wait([f1, f2]);
      expect(results.length, 2);
      // processedTextLength must end consistent (0 if both fell back, 300
      // if both ran through the same analyzer).
      expect(
        coordinator.getProcessedTextLength(AnalysisMode.parallel),
        anyOf(0, 300),
      );
    },
  );

  test(
    'BUG-PARALLEL-2: 20 concurrent analyzeIncremental calls do not deadlock',
    () async {
      final coordinator = AnalysisCoordinator(
        l3Analyzer: L3Analyzer(
          apiKeyProvider: StaticApiKeyProvider(const <String>[]),
        ),
      );
      final futures = List.generate(20, (i) {
        return coordinator.analyzeIncremental(
          'x' * (200 + i * 10),
          AnalysisMode.parallel,
        );
      });
      final results = await Future.wait(futures, eagerError: false);
      expect(results.length, 20);
      for (final r in results) {
        expect(r.analysisLevel.name, anyOf('l1', 'l2', 'l3'));
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
