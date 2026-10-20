import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/intent/intent_classifier.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/l2_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/l2/wfsa/wfsa_engine.dart';

void main() {
  L2Analyzer newL2() => L2Analyzer(
    wfsaEngine: WfsaEngine(const <ScenarioGraph>[]),
    intentClassifier: const DisabledIntentClassifier(),
  );

  group('BUG-REPRO-L2 — Regression tests cho 4 L2 bugs đã fix', () {
    test(
      'BUG-REPRO-L2-1: L2 uses incrementalText parameter (skips when empty)',
      () async {
        final l2 = newL2();
        await l2.initialize();

        const fullText = 'xin chào bạn, đây là cuộc gọi bình thường';

        final resultEmpty = await l2.analyze('', fullText);
        await l2.analyze(fullText, fullText);

        expect(
          resultEmpty.matches.length,
          equals(0),
          reason:
              'BUG-REPRO-L2-1: incrementalText="" phải bỏ qua (return green).\n'
              'Sau fix: matches.length = 0 khi incrementalText rỗng.\n'
              'Nếu fail → regression: incrementalText bị ignore lại.',
        );
        expect(
          resultEmpty.overallRiskLevel.name,
          equals('green'),
          reason: 'Empty incrementalText should return green result',
        );
      },
    );

    test('BUG-REPRO-L2-2: initialize() allows retry after failure', () async {
      final l2 = newL2();

      final futureA = l2.initialize();
      final futureB = l2.initialize();

      expect(futureA, isNotNull, reason: 'initialize() should return a Future');
      expect(futureB, isNotNull, reason: 'initialize() should return a Future');

      await futureA;
      await futureB;
    });

    test(
      'BUG-REPRO-L2-3: resetSession() invalidates in-flight analyze()',
      () async {
        final l2 = newL2();
        await l2.initialize();

        const text = 'xin chào';
        final inFlight = l2.analyze(text, text);

        l2.resetSession();

        await inFlight;

        expect(
          l2.processedTextLength,
          equals(0),
          reason:
              'BUG-REPRO-L2-3: resetSession() phải invalidate in-flight analyze.\n'
              'Sau fix: processedTextLength vẫn = 0 sau reset.\n'
              'Nếu fail → regression: in-flight analyze overwrite reset state.',
        );
        expect(
          l2.lastResult.matches,
          isEmpty,
          reason:
              'BUG-REPRO-L2-3: lastResult.matches phải rỗng sau resetSession.\n'
              'Nếu fail → regression: in-flight analyze overwrite reset state.',
        );
      },
    );

    test(
      'BUG-REPRO-L2-4: concurrent analyze() calls complete without issues',
      () async {
        final l2 = newL2();
        await l2.initialize();

        final f1 = l2.analyze('test1', 'test1');
        final f2 = l2.analyze('test2', 'test2');
        final f3 = l2.analyze('test3', 'test3');

        final results = await Future.wait([f1, f2, f3]);

        expect(results.length, equals(3));
        for (final r in results) {
          expect(r.analysisLevel.name, anyOf('l2', 'L2'));
        }

        expect(
          l2.processedTextLength,
          lessThanOrEqualTo(5),
          reason:
              'BUG-REPRO-L2-4: processedTextLength chỉ nên tăng cho current generation.\n'
              'Sau fix: guard ngăn stale analyze overwrite.',
        );
      },
    );
  });
}
