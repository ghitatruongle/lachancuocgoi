// Bug Hunt Phase B.1 — L2 (G-Detection + WFSA) Unicode + state audit
//
// Spec: docs/superpowers/specs/2026-06-28-bug-hunt-campaign-design.md
//       section "Mục 1 — 3 máy phân tích L1, L2, L3"

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';

void main() {
  L2Analyzer newL2() => L2Analyzer(
    wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
    intentClassifier: const DisabledIntentClassifier(),
  );

  group('BUG-HUNT-L2 — Unicode + diacritic edge cases', () {
    test(
      'BUG-L2-1: L2 handles diacritic variants of keywords without crashing',
      () async {
        final l2 = newL2();
        await l2.initialize();
        const inputs = <String>[
          'mã OTP',
          'Ma OTP', // Latin (no diacritic)
          'MA OTP',
          'Mã Otp',
          'MÃ OTP',
        ];
        for (final input in inputs) {
          final result = await l2.analyze(input, input);
          // Without scenario matcher, should return green or low-risk.
          expect(result.analysisLevel.name, anyOf('l2', 'L2'));
        }
      },
    );

    test('BUG-L2-2: L2 resetSession + reuse does not leak state', () async {
      final l2 = newL2();
      await l2.initialize();
      await l2.analyze('lần đầu', 'lần đầu');
      l2.resetSession();
      expect(l2.processedTextLength, 0);
      final result = await l2.analyze('an toàn', 'an toàn');
      // Without leftover state, should not re-emit orange from previous run.
      expect(result.overallRiskLevel.name, isNot('orange'));
      expect(result.overallRiskLevel.name, isNot('red'));
    });

    test(
      'BUG-L2-3: L2 with very long transcript (>10K chars) does not OOM',
      () async {
        final l2 = newL2();
        await l2.initialize();
        final longText = 'an toàn ' * 2000;
        final result = await l2.analyze(longText, longText);
        expect(result.analysisLevel.name, anyOf('l2', 'L2'));
      },
    );

    test('BUG-L2-4: L2 with empty transcript does not throw', () async {
      final l2 = newL2();
      await l2.initialize();
      final result = await l2.analyze('', '');
      expect(result.analysisLevel.name, anyOf('l2', 'L2'));
    });
  });
}
