// Bug Hunt Phase B.9 — privacy-safe native call-event parsing.

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/bridge_models.dart';

void main() {
  group('BUG-HUNT-CALL — NativeCallEvent Dart parsing', () {
    test('preserves type when a masked number is unavailable', () {
      final event = NativeCallEvent.fromMap({
        'type': 'RINGING',
        'timestampMs': 123,
        'numberAvailable': false,
        // A legacy/raw field must never be consumed.
        'phoneNumber': '+84912345678',
      });

      expect(event.type, 'RINGING');
      expect(event.timestampMs, 123);
      expect(event.numberAvailable, isFalse);
      expect(event.maskedNumber, isNull);
    });

    test('parses canonical fields and ignores unknown keys', () {
      final event = NativeCallEvent.fromMap({
        'type': 'OFFHOOK',
        'timestampMs': 456,
        'reason': 'telecom_callback',
        'futureField': 'value',
        'numberAvailable': true,
        'maskedNumber': '******5678',
      });

      expect(event.type, 'OFFHOOK');
      expect(event.timestampMs, 456);
      expect(event.reason, 'telecom_callback');
      expect(event.maskedNumber, '******5678');
    });

    test('handles an empty map gracefully', () {
      final event = NativeCallEvent.fromMap({});

      expect(event.type, 'UNKNOWN');
      expect(event.timestampMs, 0);
      expect(event.reason, isNull);
      expect(event.numberAvailable, isFalse);
      expect(event.maskedNumber, isNull);
    });
  });
}
