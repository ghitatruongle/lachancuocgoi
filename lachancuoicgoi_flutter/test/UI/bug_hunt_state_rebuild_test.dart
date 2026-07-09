// Bug Hunt Phase B.6 — UI state rebuild + churn audit
//
// Reference: docs/superpowers/specs/.../Mục 6 — Tốc độ

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_state.dart';

void main() {
  group('BUG-HUNT-REBUILD — Monitoring state churn', () {
    test(
      'BUG-REBUILD-1: copyWith preserves unrelated fields (no-op idempotent)',
      () {
        const a = MonitoringPageState(
          transcript: 'hello',
          selectedMode: AnalysisMode.parallel,
        );
        final b = a.copyWith(transcript: 'hello');
        expect(b, equals(a));
      },
    );

    test(
      'BUG-REBUILD-2: copyWith on same isAnalyzing does not bump bannerId',
      () {
        const a = MonitoringPageState(isAnalyzing: true);
        final b = a.copyWith(isAnalyzing: true);
        expect(b.sttFallbackBannerId, equals(a.sttFallbackBannerId));
      },
    );

    test(
      'BUG-REBUILD-3: long transcript (5000 chars) copyWith < 200ms',
      () {
        final long = 'x' * 5000;
        const base = MonitoringPageState();
        final sw = Stopwatch()..start();
        var cur = base;
        for (var i = 0; i < 10; i++) {
          cur = cur.copyWith(transcript: long);
        }
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(200));
      },
    );
  });
}