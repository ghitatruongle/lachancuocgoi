// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_page.dart';
import 'package:lachancuocgoi_flutter/ui/result_page/result_page.dart';

import 'helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sprint 4 — monitoring flow', () {
    late IntegrationTestHarness harness;
    late FakeIntegrationBridge bridge;

    setUp(() async {
      harness = await IntegrationTestHarness.build(initialRoute: '/monitoring');
      bridge = harness.bridge;
    });

    tearDown(() async {
      await harness.dispose();
    });

    testWidgets(
      'Start → transcript arrives → analysis runs → end → history row',
      (tester) async {
        await tester.pumpWidget(harness.widget);
        // A few pumps are enough to flush post-frame callbacks; we
        // deliberately avoid pumpAndSettle because the controller's
        // 1s elapsed-time timer keeps frames scheduled forever.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(
          find.byType(MonitoringPage),
          findsOneWidget,
          reason: 'MonitoringPage should be mounted',
        );

        bridge.sendMonitoringState('STARTED');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        const phrases = <String>[
          'Xin chào, đây là cảnh sát giao thông',
          'Bạn có liên quan đến vụ án ma túy',
          'Vui lòng chuyển khoản 50 triệu để xác minh',
        ];
        for (final p in phrases) {
          bridge.emitTranscript(p);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Wait for the 1200ms analysis debounce + analysis run.
        await tester.pump(const Duration(milliseconds: 1500));
        // Process async analysis completions.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        const finalTranscript = 'Chuyển khoản 50 triệu để xác minh';
        bridge.sendMonitoringState('STOPPED:12:$finalTranscript');
        await tester.pump();
        // Allow endSession() to run and navigation intent to propagate.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        expect(
          find.byType(ResultPage),
          findsOneWidget,
          reason: 'Should have navigated to ResultPage',
        );
        expect(
          find.textContaining('Chuyển khoản', findRichText: true),
          findsWidgets,
          reason: 'Result page should show the final transcript',
        );

        final rows = await harness.db.all();
        expect(rows, hasLength(1));
        expect(rows.first.transcript, contains('Chuyển khoản'));
      },
    );

    testWidgets(
      'End session with empty transcript → recordingError == noAudio',
      (tester) async {
        await tester.pumpWidget(harness.widget);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.byType(MonitoringPage), findsOneWidget);

        bridge.sendMonitoringState('STARTED');
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 550));

        bridge.sendMonitoringState('STOPPED:5:');
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        final rows = await harness.db.all();
        expect(rows, hasLength(1));
        expect(rows.first.recordingError, 'noAudio');
        expect(rows.first.transcript, isEmpty);
      },
    );

    testWidgets('Health-check auto-restarts monitoring when service is down', (
      tester,
    ) async {
      await tester.pumpWidget(harness.widget);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(MonitoringPage), findsOneWidget);

      bridge.setMonitoringActive(active: false);

      // Give initAfterFrame() time to call startMonitoring once.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      final startCallsAfterInit = bridge.startMonitoringCalls;
      expect(
        startCallsAfterInit,
        greaterThanOrEqualTo(1),
        reason: 'initAfterFrame should call startMonitoring at least once',
      );

      bridge.setMonitoringActive(active: false);

      // Advance 61s so the health check timer fires once.
      await tester.pump(const Duration(seconds: 61));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        bridge.startMonitoringCalls,
        greaterThan(startCallsAfterInit),
        reason: 'Health check should trigger a second startMonitoring call',
      );
    });
  });
}
