// Bug Hunt Phase B.9 — CallEvent Dart-side parsing (Android 13+ number)
//
// Reference: docs/superpowers/specs/.../Mục 10 — Nhận diện cuộc gọi đến

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/bridge_models.dart';

void main() {
  group('BUG-HUNT-CALL — CallEvent Dart parsing', () {
    test(
      'BUG-CALL-1: CallEvent.fromMap preserves type when phoneNumber missing',
      () {
        // Bug #6 fix (Android 13+ numberAvailable flag): Kotlin sends
        // numberAvailable=false + phoneNumber=null. Dart side should not
        // throw, should preserve type.
        final event = CallEvent.fromMap({
          'type': 'RINGING',
          'phoneNumber': null,
          'numberAvailable': false,
        });
        expect(event.type, equals('RINGING'));
        expect(event.phoneNumber, isNull);
      },
    );

    test(
      'BUG-CALL-2: CallEvent.fromMap does not crash on unknown keys',
      () {
        // Future-proof: Kotlin may add new fields; Dart must ignore them.
        final event = CallEvent.fromMap({
          'type': 'OFFHOOK',
          'futureField': 'value',
          'numberAvailable': true,
        });
        expect(event.type, equals('OFFHOOK'));
      },
    );

    test(
      'BUG-CALL-3: CallEvent.fromMap handles empty map gracefully',
      () {
        // type defaults to 'UNKNOWN' when missing.
        final event = CallEvent.fromMap({});
        expect(event.type, equals('UNKNOWN'));
        expect(event.phoneNumber, isNull);
        expect(event.source, isNull);
      },
    );
  });
}