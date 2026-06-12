import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/session_recovery_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SessionSnapshot — JSON round trip', () {
    test('round-trips with all fields populated', () {
      final original = SessionSnapshot(
        phoneNumber: '+84912345678',
        transcript: 'Anh ơi cho em xin OTP',
        elapsedSeconds: 42,
        riskLevel: 'RED',
        analysisResultJson: '{"level":"L1","risk":"RED"}',
        recordingError: 'sttFailed',
        startedAt: DateTime(2026, 5, 1, 10, 30, 45),
      );
      final encoded = jsonEncode(original.toJson());
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final restored = SessionSnapshot.fromJson(decoded);

      expect(restored.phoneNumber, original.phoneNumber);
      expect(restored.transcript, original.transcript);
      expect(restored.elapsedSeconds, original.elapsedSeconds);
      expect(restored.riskLevel, original.riskLevel);
      expect(restored.analysisResultJson, original.analysisResultJson);
      expect(restored.recordingError, original.recordingError);
      expect(restored.startedAt, original.startedAt);
    });

    test('round-trips with optional fields null', () {
      final original = SessionSnapshot(
        phoneNumber: '',
        transcript: '',
        elapsedSeconds: 0,
        riskLevel: null,
        analysisResultJson: null,
        recordingError: null,
        startedAt: DateTime(2026, 5, 1, 0, 0, 0),
      );
      final encoded = jsonEncode(original.toJson());
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final restored = SessionSnapshot.fromJson(decoded);

      expect(restored.phoneNumber, '');
      expect(restored.transcript, '');
      expect(restored.elapsedSeconds, 0);
      expect(restored.riskLevel, isNull);
      expect(restored.analysisResultJson, isNull);
      expect(restored.recordingError, isNull);
      expect(restored.startedAt, original.startedAt);
    });

    test('missing startedAtIso falls back to now', () {
      final restored = SessionSnapshot.fromJson(const {
        'phoneNumber': '',
        'transcript': '',
        'elapsedSeconds': 0,
      });
      final diff = DateTime.now().difference(restored.startedAt).abs();
      expect(diff.inSeconds, lessThan(5));
    });

    test('handles malformed startedAtIso gracefully', () {
      final restored = SessionSnapshot.fromJson(const {
        'phoneNumber': '',
        'transcript': '',
        'elapsedSeconds': 0,
        'startedAtIso': 'not-a-date',
      });
      final diff = DateTime.now().difference(restored.startedAt).abs();
      expect(diff.inSeconds, lessThan(5));
    });
  });

  group('SessionRecoveryStore — SharedPreferences persistence', () {
    test('load returns null when nothing saved', () async {
      final result = await SessionRecoveryStore.load();
      expect(result, isNull);
    });

    test('save then load returns the same snapshot', () async {
      final snapshot = SessionSnapshot(
        phoneNumber: '+84900000001',
        transcript: 'hello',
        elapsedSeconds: 7,
        riskLevel: 'ORANGE',
        analysisResultJson: null,
        recordingError: null,
        startedAt: DateTime(2026, 1, 1, 12, 0, 0),
      );
      await SessionRecoveryStore.save(snapshot);
      final loaded = await SessionRecoveryStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.phoneNumber, '+84900000001');
      expect(loaded.transcript, 'hello');
      expect(loaded.elapsedSeconds, 7);
      expect(loaded.riskLevel, 'ORANGE');
      expect(loaded.startedAt, DateTime(2026, 1, 1, 12, 0, 0));
    });

    test('clear removes the snapshot', () async {
      await SessionRecoveryStore.save(
        SessionSnapshot(
          phoneNumber: 'p',
          transcript: 't',
          elapsedSeconds: 1,
          riskLevel: null,
          analysisResultJson: null,
          recordingError: null,
          startedAt: DateTime(2026, 1, 1, 0, 0, 0),
        ),
      );
      await SessionRecoveryStore.clear();
      final loaded = await SessionRecoveryStore.load();
      expect(loaded, isNull);
    });

    test('save overwrites previous snapshot', () async {
      await SessionRecoveryStore.save(
        SessionSnapshot(
          phoneNumber: 'first',
          transcript: 'first',
          elapsedSeconds: 1,
          riskLevel: null,
          analysisResultJson: null,
          recordingError: null,
          startedAt: DateTime(2026, 1, 1, 0, 0, 0),
        ),
      );
      await SessionRecoveryStore.save(
        SessionSnapshot(
          phoneNumber: 'second',
          transcript: 'second',
          elapsedSeconds: 2,
          riskLevel: null,
          analysisResultJson: null,
          recordingError: null,
          startedAt: DateTime(2026, 1, 1, 0, 0, 1),
        ),
      );
      final loaded = await SessionRecoveryStore.load();
      expect(loaded!.phoneNumber, 'second');
      expect(loaded.transcript, 'second');
    });

    test('corrupt JSON → load returns null and clears', () async {
      SharedPreferences.setMockInitialValues({
        'live_session_snapshot_v1': '{not valid json',
      });
      final loaded = await SessionRecoveryStore.load();
      expect(loaded, isNull);
      // After clear(), the snapshot is gone.
      final afterClear = await SessionRecoveryStore.load();
      expect(afterClear, isNull);
    });

    test('non-Map JSON → load returns null', () async {
      SharedPreferences.setMockInitialValues({
        'live_session_snapshot_v1': '"just a string"',
      });
      final loaded = await SessionRecoveryStore.load();
      expect(loaded, isNull);
    });
  });

  group('SessionRecoveryStore.maxAge', () {
    test('30 minutes', () {
      expect(SessionRecoveryStore.maxAge, const Duration(minutes: 30));
    });
  });
}
