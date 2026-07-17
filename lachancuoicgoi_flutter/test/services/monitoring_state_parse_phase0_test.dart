import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/bridge_models.dart';

void main() {
  group('MonitoringState.parse — Phase 0/1 states', () {
    test('parses STT_UNAVAILABLE with reason', () {
      final (state, _, reason) = MonitoringState.parse(
        'STT_UNAVAILABLE:no_engine',
      );
      expect(state, MonitoringState.sttUnavailable);
      expect(reason, 'no_engine');
    });

    test('parses DEGRADED_NO_NOTIFICATION', () {
      final (state, _, _) = MonitoringState.parse('DEGRADED_NO_NOTIFICATION');
      expect(state, MonitoringState.degradedNoNotification);
    });

    test('parses WATCHDOG_RESTART_FAILED', () {
      final (state, _, _) = MonitoringState.parse('WATCHDOG_RESTART_FAILED');
      expect(state, MonitoringState.watchdogRestartFailed);
    });

    test('parses STT_FALLBACK:VOSK still works', () {
      final (state, _, reason) = MonitoringState.parse(
        'STT_FALLBACK:VOSK:network_errors_3',
      );
      expect(state, MonitoringState.sttFallbackVosk);
      expect(reason, 'network_errors_3');
    });
  });
}
