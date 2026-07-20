import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';

void main() {
  group('PermissionSnapshot — advanced', () {
    test('partial permissions counted correctly', () {
      const snapshot = PermissionSnapshot(
        recordAudio: true,
        phoneState: false,
        callLog: true,
        overlay: false,
        notification: true,
        accessibility: false,
        callScreening: true,
      );

      expect(snapshot.grantedCount, 4);
      expect(snapshot.allGranted, isFalse);
    });

    test('single permission granted', () {
      const snapshot = PermissionSnapshot(recordAudio: true);

      expect(snapshot.grantedCount, 1);
      expect(snapshot.allGranted, isFalse);
    });

    test('fromMap constructs snapshot correctly', () {
      final snapshot = PermissionSnapshot.fromMap({
        'recordAudio': true,
        'phoneState': false,
        'callLog': true,
        'answerPhoneCalls': true,
        'overlay': true,
        'notification': false,
        'accessibility': true,
        'callScreening': false,
      });

      expect(snapshot.recordAudio, isTrue);
      expect(snapshot.phoneState, isFalse);
      expect(snapshot.callLog, isTrue);
      expect(snapshot.answerPhoneCalls, isTrue);
      expect(snapshot.overlay, isTrue);
      expect(snapshot.notification, isFalse);
      expect(snapshot.accessibility, isTrue);
      expect(snapshot.callScreening, isFalse);
      expect(snapshot.grantedCount, 5);
    });

    test('fromMap handles null values as false', () {
      final snapshot = PermissionSnapshot.fromMap({
        'recordAudio': null,
        'phoneState': null,
      });

      expect(snapshot.recordAudio, isFalse);
      expect(snapshot.phoneState, isFalse);
      expect(snapshot.grantedCount, 0);
    });
  });

  group('MonitoringState — parsing', () {
    test('STOPPED without colon falls back to idle (exact match)', () {
      // 'STOPPED' without colon does NOT startsWith 'STOPPED:'
      // and the switch case does not have 'STOPPED' => it falls to _
      final (state, duration, transcript) = MonitoringState.parse('STOPPED');
      expect(state, MonitoringState.idle);
      expect(duration, isNull);
      expect(transcript, isNull);
    });

    test('STOPPED: with only colon and duration', () {
      final (state, duration, transcript) = MonitoringState.parse('STOPPED:45');
      expect(state, MonitoringState.stopped);
      expect(duration, 45);
      expect(transcript, isNull);
    });

    test('STOPPED: with empty transcript', () {
      final (state, duration, transcript) = MonitoringState.parse(
        'STOPPED:30:',
      );
      expect(state, MonitoringState.stopped);
      expect(duration, 30);
      expect(transcript, isNull);
    });

    test('STOPPED: with invalid duration uses null', () {
      final (state, duration, transcript) = MonitoringState.parse(
        'STOPPED:abc:some text',
      );
      expect(state, MonitoringState.stopped);
      expect(duration, isNull);
      expect(transcript, 'some text');
    });

    test('STOPPED: with colons in transcript preserves them', () {
      final (state, duration, transcript) = MonitoringState.parse(
        'STOPPED:60:Anh ơi: bước tiếp theo: ok',
      );
      expect(state, MonitoringState.stopped);
      expect(duration, 60);
      expect(transcript, 'Anh ơi: bước tiếp theo: ok');
    });

    test('STARTED parses correctly', () {
      final (state, duration, transcript) = MonitoringState.parse('STARTED');
      expect(state, MonitoringState.started);
      expect(duration, isNull);
      expect(transcript, isNull);
    });

    test('NETWORK_AVAILABLE parses correctly', () {
      final (state, _, _) = MonitoringState.parse('NETWORK_AVAILABLE');
      expect(state, MonitoringState.networkAvailable);
    });

    test('NETWORK_LOST parses correctly', () {
      final (state, _, _) = MonitoringState.parse('NETWORK_LOST');
      expect(state, MonitoringState.networkLost);
    });

    test('empty string falls back to idle', () {
      final (state, _, _) = MonitoringState.parse('');
      expect(state, MonitoringState.idle);
    });

    test('unknown string falls back to idle', () {
      final (state, _, _) = MonitoringState.parse('RANDOM_VALUE');
      expect(state, MonitoringState.idle);
    });
  });

  group('NativeCallEvent — construction', () {
    test('fromMap handles null type as UNKNOWN', () {
      final event = NativeCallEvent.fromMap({
        'type': null,
        'timestampMs': null,
        'reason': null,
        'numberAvailable': null,
        'maskedNumber': null,
      });
      expect(event.type, 'UNKNOWN');
      expect(event.timestampMs, 0);
      expect(event.reason, isNull);
      expect(event.numberAvailable, isFalse);
      expect(event.maskedNumber, isNull);
    });

    test('fromMap with full data', () {
      final event = NativeCallEvent.fromMap({
        'type': 'RINGING',
        'timestampMs': 1000,
        'reason': 'telecom',
        'numberAvailable': true,
        'maskedNumber': '******5678',
      });
      expect(event.type, 'RINGING');
      expect(event.timestampMs, 1000);
      expect(event.reason, 'telecom');
      expect(event.numberAvailable, isTrue);
      expect(event.maskedNumber, '******5678');
    });

    test('fromMap with partial data', () {
      final event = NativeCallEvent.fromMap({'type': 'ENDED'});
      expect(event.type, 'ENDED');
      expect(event.maskedNumber, isNull);
    });

    test('fromMap with empty map', () {
      final event = NativeCallEvent.fromMap(<Object?, Object?>{});
      expect(event.type, 'UNKNOWN');
    });

    test('preserves only the native masked number', () {
      final event = NativeCallEvent.fromMap({
        'type': 'INCOMING',
        'numberAvailable': true,
        'maskedNumber': '******5678',
        'phoneNumber': '+84912345678',
      });
      expect(event.maskedNumber, '******5678');
    });
  });

  group('MonitoringStopResult', () {
    test('stores duration and transcript', () {
      const result = MonitoringStopResult(
        durationSeconds: 120,
        finalTranscript: 'Nội dung cuộc gọi.',
      );

      expect(result.durationSeconds, 120);
      expect(result.finalTranscript, 'Nội dung cuộc gọi.');
    });

    test('defaults to null values', () {
      const result = MonitoringStopResult();

      expect(result.durationSeconds, isNull);
      expect(result.finalTranscript, isNull);
    });
  });
}
