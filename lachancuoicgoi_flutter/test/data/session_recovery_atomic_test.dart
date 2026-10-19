import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/session_recovery_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SessionRecoveryStore Atomic & Resilience Tests', () {
    test('Saves and loads snapshot correctly', () async {
      final now = DateTime.now();
      final snapshot = SessionSnapshot(
        phoneNumber: '0912345678',
        transcript: 'Nội dung kiểm thử',
        elapsedSeconds: 45,
        riskLevel: 'RED',
        analysisResultJson: '{"level":"red"}',
        recordingError: null,
        startedAt: now,
      );

      await SessionRecoveryStore.save(snapshot);
      final loaded = await SessionRecoveryStore.load();

      expect(loaded, isNotNull);
      expect(loaded!.phoneNumber, equals('0912345678'));
      expect(loaded.transcript, equals('Nội dung kiểm thử'));
      expect(loaded.riskLevel, equals('RED'));
    });

    test(
      'Handles corrupted JSON gracefully by auto-clearing snapshot',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'live_session_snapshot_v1',
          '{INVALID_JSON_CORRUPTED',
        );

        final loaded = await SessionRecoveryStore.load();
        expect(loaded, isNull);

        final reloaded = prefs.getString('live_session_snapshot_v1');
        expect(
          reloaded,
          isNull,
          reason: 'Corrupted snapshot should be cleared automatically',
        );
      },
    );

    test('Clears snapshot on session end', () async {
      final snapshot = SessionSnapshot(
        phoneNumber: '0987654321',
        transcript: 'Phiên kết thúc',
        elapsedSeconds: 120,
        riskLevel: 'GREEN',
        analysisResultJson: null,
        recordingError: null,
        startedAt: DateTime.now(),
      );

      await SessionRecoveryStore.save(snapshot);
      await SessionRecoveryStore.clear();

      final loaded = await SessionRecoveryStore.load();
      expect(loaded, isNull);
    });
  });
}
