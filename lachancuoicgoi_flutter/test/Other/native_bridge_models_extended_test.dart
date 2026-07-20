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

  group('NativeCallEvent.fromMap — edge cases', () {
    test('all null fields', () {
      final event = NativeCallEvent.fromMap({});
      expect(event.type, 'UNKNOWN');
      expect(event.timestampMs, 0);
      expect(event.reason, isNull);
      expect(event.numberAvailable, isFalse);
      expect(event.maskedNumber, isNull);
    });

    test('all fields present', () {
      final event = NativeCallEvent.fromMap({
        'type': 'RINGING',
        'timestampMs': 123456,
        'reason': 'phone_state',
        'numberAvailable': true,
        'maskedNumber': '******6789',
      });
      expect(event.type, 'RINGING');
      expect(event.timestampMs, 123456);
      expect(event.reason, 'phone_state');
      expect(event.numberAvailable, isTrue);
      expect(event.maskedNumber, '******6789');
    });

    test('non-string type falls back to UNKNOWN', () {
      final event = NativeCallEvent.fromMap({'type': 123});
      expect(event.type, 'UNKNOWN');
    });

    test('never reads a legacy raw phoneNumber field', () {
      final event = NativeCallEvent.fromMap({
        'type': 'INCOMING',
        'numberAvailable': true,
        'phoneNumber': '+84912345678',
      });
      expect(event.maskedNumber, isNull);
    });
  });

  group('PermissionSnapshot', () {
    test('default has all false', () {
      const snapshot = PermissionSnapshot();
      expect(snapshot.recordAudio, isFalse);
      expect(snapshot.phoneState, isFalse);
      expect(snapshot.callLog, isFalse);
      expect(snapshot.answerPhoneCalls, isFalse);
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
        answerPhoneCalls: true,
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
        answerPhoneCalls: true,
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

    test('totalPermissions returns 8', () {
      expect(PermissionSnapshot.totalPermissions, 8);
    });
  });
}
