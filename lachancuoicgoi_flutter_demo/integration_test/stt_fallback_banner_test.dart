// ignore_for_file: avoid_print

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_controller.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_page.dart';

import 'helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sprint 4 — STT fallback banner (C1)', () {
    late IntegrationTestHarness harness;
    late FakeIntegrationBridge bridge;

    setUp(() async {
      harness = await IntegrationTestHarness.build(initialRoute: '/monitoring');
      bridge = harness.bridge;
    });

    tearDown(() async {
      await harness.dispose();
    });

    testWidgets('STT_FALLBACK:VOSK event sets isSttFallback + reason',
        (tester) async {
      await tester.pumpWidget(harness.widget);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(MonitoringPage), findsOneWidget);

      bridge.sendMonitoringState('STARTED');
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MonitoringPage)),
      );
      final before = container.read(monitoringControllerProvider);
      expect(before.isSttFallback, isFalse);
      expect(before.sttFallbackReason, isNull);

      bridge.sendMonitoringState('STT_FALLBACK:VOSK:error12_loop');
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final after = container.read(monitoringControllerProvider);
      expect(after.isSttFallback, isTrue);
      expect(after.sttFallbackReason, 'error12_loop');
      expect(after.sttFallbackBannerId, greaterThan(0));
    });
  });
}
