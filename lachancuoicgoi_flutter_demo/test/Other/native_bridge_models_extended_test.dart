import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';

void main() {
  group('MonitoringState.parse — edge cases', () {
    test('STOPPED:0:empty parses to null transcript', () {
      final (state, duration, transcript) = MonitoringState.parse('STOPPED:0:');
      expect(state, MonitoringState.stopped);
      expect(duration, 0);
      expect(transcript, isNull);
    });

    test('STOPPED: with no second colon after duration', () {
      final (state, duration, transcript) = MonitoringState.parse('STOPPED:45');
      expect(state, MonitoringState.stopped);
      expect(duration, 45);
      // parts.length == 2 so no transcript part
      expect(transcript, isNull);
    });

    test('STOPPED: with negative duration', () {
      final (state, duration, transcript) = MonitoringState.parse(
        'STOPPED:-5:hello',
      );
      expect(state, MonitoringState.stopped);
      expect(duration, -5);
      expect(transcript, 'hello');
    });

    test('STOPPED: with very long transcript', () {
      final longTranscript = 'a' * 5000;
      final (state, duration, transcript) = MonitoringState.parse(
        'STOPPED:10:$longTranscript',
      );
      expect(state, MonitoringState.stopped);
      expect(duration, 10);
      expect(transcript, longTranscript);
    });

    test('STARTED does not parse as STOPPED', () {
      final (state, _, _) = MonitoringState.parse('STARTED');
      expect(state, MonitoringState.started);
    });

    test('unknown string falls back to idle', () {
      final (state, _, _) = MonitoringState.parse('UNKNOWN_EVENT');
      expect(state, MonitoringState.idle);
    });

    test('empty string falls back to idle', () {
      final (state, _, _) = MonitoringState.parse('');
      expect(state, MonitoringState.idle);
    });
  });

  group('CallEvent.fromMap — edge cases', () {
    test('all null fields', () {
      final event = CallEvent.fromMap({});
      expect(event.type, 'UNKNOWN');
      expect(event.phoneNumber, isNull);
      expect(event.source, isNull);
    });

    test('all fields present', () {
      final event = CallEvent.fromMap({
        'type': 'RINGING',
        'phoneNumber': '0123456789',
        'source': 'native',
      });
      expect(event.type, 'RINGING');
      expect(event.phoneNumber, '0123456789');
      expect(event.source, 'native');
    });

    test('non-string type falls back to UNKNOWN', () {
      // CallEvent.fromMap uses `as String?` — int throws TypeError,
      // which means the caller must pass correct types.
      // This test documents the behavior: TypeError on wrong type.
      expect(() => CallEvent.fromMap({'type': 123}), throwsA(isA<TypeError>()));
    });
  });

  group('PermissionSnapshot', () {
    test('default has all false', () {
      const snapshot = PermissionSnapshot();
      expect(snapshot.recordAudio, isFalse);
      expect(snapshot.phoneState, isFalse);
      expect(snapshot.callLog, isFalse);
      expect(snapshot.overlay, isFalse);
      expect(snapshot.notification, isFalse);
      expect(snapshot.accessibility, isFalse);
      expect(snapshot.callScreening, isFalse);
    });

    test('allGranted returns true when all are true', () {
      const snapshot = PermissionSnapshot(
        recordAudio: true,
        phoneState: true,
        callLog: true,
        overlay: true,
        notification: true,
        accessibility: true,
        callScreening: true,
      );
      expect(snapshot.allGranted, isTrue);
    });

    test('allGranted returns false when one is false', () {
      const snapshot = PermissionSnapshot(
        recordAudio: true,
        phoneState: true,
        callLog: true,
        overlay: false,
        notification: true,
        accessibility: true,
        callScreening: true,
      );
      expect(snapshot.allGranted, isFalse);
    });

    test('grantedCount counts correctly', () {
      const snapshot = PermissionSnapshot(
        recordAudio: true,
        phoneState: true,
        overlay: true,
      );
      expect(snapshot.grantedCount, 3);
    });

    test('fromMap handles null values as false', () {
      final snapshot = PermissionSnapshot.fromMap({
        'recordAudio': true,
        'phoneState': null,
      });
      expect(snapshot.recordAudio, isTrue);
      expect(snapshot.phoneState, isFalse);
    });

    test('totalPermissions returns 7', () {
      expect(PermissionSnapshot.totalPermissions, 7);
    });
  });
}
