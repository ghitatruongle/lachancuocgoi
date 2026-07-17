import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_controller.dart';

void main() {
  group('MonitoringPageState — Sprint 2 (C1) banner fields', () {
    test('defaults: banner flag is false, reason is null, id is 0', () {
      const state = MonitoringPageState();
      expect(state.isSttFallback, isFalse);
      expect(state.sttFallbackReason, isNull);
      expect(state.sttFallbackBannerId, 0);
    });

    test('copyWith updates all three banner fields', () {
      const original = MonitoringPageState();
      final updated = original.copyWith(
        isSttFallback: true,
        sttFallbackReason: 'error12_loop',
        sttFallbackBannerId: 1,
      );
      expect(updated.isSttFallback, isTrue);
      expect(updated.sttFallbackReason, 'error12_loop');
      expect(updated.sttFallbackBannerId, 1);
      // Original is unchanged
      expect(original.isSttFallback, isFalse);
    });

    test('bannerId increments allow re-keying banner widgets', () {
      const original = MonitoringPageState();
      final first = original.copyWith(
        isSttFallback: true,
        sttFallbackReason: 'first',
        sttFallbackBannerId: 1,
      );
      final second = first.copyWith(
        sttFallbackReason: 'second',
        sttFallbackBannerId: 2,
      );
      expect(first.sttFallbackBannerId, 1);
      expect(second.sttFallbackBannerId, 2);
      expect(first, isNot(equals(second)));
    });

    test('equality includes new banner fields', () {
      const a = MonitoringPageState(
        isSttFallback: true,
        sttFallbackReason: 'error12_loop',
        sttFallbackBannerId: 1,
      );
      const b = MonitoringPageState(
        isSttFallback: true,
        sttFallbackReason: 'error12_loop',
        sttFallbackBannerId: 1,
      );
      const c = MonitoringPageState(
        isSttFallback: true,
        sttFallbackReason: 'network_errors_3',
        sttFallbackBannerId: 1,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // Verify the static `formatElapsedTime` and `_formatDateTime` behave
  // well for use in B5 recovery.
  group('Sprint 2 (B5) — helper methods', () {
    test('formatElapsedTime formats seconds as MM:SS', () {
      expect(MonitoringController.formatElapsedTime(0), '00:00');
      expect(MonitoringController.formatElapsedTime(65), '01:05');
      expect(MonitoringController.formatElapsedTime(3600), '60:00');
    });
  });
}
