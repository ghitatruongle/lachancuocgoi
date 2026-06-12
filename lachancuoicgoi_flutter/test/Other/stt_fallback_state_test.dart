import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';

void main() {
  group('MonitoringState.parse — STT_FALLBACK (Sprint 2 / C1)', () {
    test('STT_FALLBACK:VOSK:error12_loop parses to sttFallbackVosk', () {
      final (state, duration, reason) =
          MonitoringState.parse('STT_FALLBACK:VOSK:error12_loop');
      expect(state, MonitoringState.sttFallbackVosk);
      expect(duration, isNull);
      expect(reason, 'error12_loop');
    });

    test('STT_FALLBACK:VOSK:network_errors_3 parses to sttFallbackVosk', () {
      final (state, _, reason) =
          MonitoringState.parse('STT_FALLBACK:VOSK:network_errors_3');
      expect(state, MonitoringState.sttFallbackVosk);
      expect(reason, 'network_errors_3');
    });

    test('STT_FALLBACK:VOSK: with no reason → null reason', () {
      final (state, _, reason) =
          MonitoringState.parse('STT_FALLBACK:VOSK:');
      expect(state, MonitoringState.sttFallbackVosk);
      expect(reason, isNull);
    });

    test('STT_FALLBACK:VOSK: with empty reason → null reason', () {
      // Edge case: "STT_FALLBACK:VOSK:" + "" — handled by checking length.
      final (state, _, reason) =
          MonitoringState.parse('STT_FALLBACK:VOSK:');
      expect(state, MonitoringState.sttFallbackVosk);
      expect(reason, isNull);
    });

    test('STT_FALLBACK:UNKNOWN:foo falls through to idle (unknown prefix)',
        () {
      // Only VOSK is supported; other engines would need a separate branch.
      final (state, _, _) = MonitoringState.parse('STT_FALLBACK:GOOGLE:foo');
      expect(state, MonitoringState.idle);
    });

    test('STT_FALLBACK:VOSK preserves Vietnamese characters in reason', () {
      final (state, _, reason) =
          MonitoringState.parse('STT_FALLBACK:VOSK:lỗi mạng');
      expect(state, MonitoringState.sttFallbackVosk);
      expect(reason, 'lỗi mạng');
    });

    test('regression: STOPPED:30:text still parses correctly', () {
      final (state, duration, transcript) =
          MonitoringState.parse('STOPPED:30:hello');
      expect(state, MonitoringState.stopped);
      expect(duration, 30);
      expect(transcript, 'hello');
    });

    test('regression: STARTED still parses correctly', () {
      final (state, _, _) = MonitoringState.parse('STARTED');
      expect(state, MonitoringState.started);
    });

    test('regression: NETWORK_LOST still parses correctly', () {
      final (state, _, _) = MonitoringState.parse('NETWORK_LOST');
      expect(state, MonitoringState.networkLost);
    });
  });
}
