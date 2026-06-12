// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lachancuocgoi_flutter/data/session_recovery_store.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_page.dart';

import 'helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sprint 4 — session recovery (B5)', () {
    late IntegrationTestHarness harness;
    late FakeIntegrationBridge bridge;

    setUp(() async {
      await SessionRecoveryStore.clear();
      harness = await IntegrationTestHarness.build(initialRoute: '/monitoring');
      bridge = harness.bridge;
      bridge.setMonitoringActive(active: false);
    });

    tearDown(() async {
      await SessionRecoveryStore.clear();
      await harness.dispose();
    });

    testWidgets(
      'Snapshot from a previous session is recovered on next boot',
      (tester) async {
        const transcript = 'hello';
        await SessionRecoveryStore.save(
          SessionSnapshot(
            phoneNumber: '',
            transcript: transcript,
            elapsedSeconds: 7,
            riskLevel: 'GREEN',
            analysisResultJson: null,
            recordingError: null,
            startedAt: DateTime.now(),
          ),
        );
        expect(await SessionRecoveryStore.load(), isNotNull);

        await tester.pumpWidget(harness.widget);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.byType(MonitoringPage), findsOneWidget);

        // Pump enough for the recovery to complete.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        final rows = await harness.db.all();
        expect(rows, hasLength(1),
            reason: 'Recovery should insert exactly one row');
        expect(rows.first.transcript, transcript,
            reason: 'Recovered transcript should match the snapshot');
        expect(rows.first.recordingError, 'killed',
            reason: 'Recovered row should be tagged as killed');

        expect(await SessionRecoveryStore.load(), isNull,
            reason: 'Snapshot must be cleared after successful recovery');
      },
    );

    testWidgets('Snapshot older than 30 min is dropped (no row inserted)',
        (tester) async {
      await SessionRecoveryStore.save(
        SessionSnapshot(
          phoneNumber: '',
          transcript: 'stale',
          elapsedSeconds: 99,
          riskLevel: 'GREEN',
          analysisResultJson: null,
          recordingError: null,
          startedAt: DateTime.now().subtract(const Duration(minutes: 31)),
        ),
      );
      expect(await SessionRecoveryStore.load(), isNotNull);

      await tester.pumpWidget(harness.widget);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(MonitoringPage), findsOneWidget);

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      final rows = await harness.db.all();
      expect(rows, isEmpty,
          reason: 'A stale snapshot should not be recovered');

      expect(await SessionRecoveryStore.load(), isNull,
          reason: 'Stale snapshot should be cleared after the age check');
    });
  });
}
