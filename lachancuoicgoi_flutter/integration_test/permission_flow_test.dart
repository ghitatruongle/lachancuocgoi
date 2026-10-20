// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/ui/home_page/home_page.dart';

import 'helpers/integration_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sprint 4 — permission flow', () {
    late FakeIntegrationBridge bridge;

    tearDown(() async {
      await bridge.dispose();
    });

    testWidgets('App boots to home page when all permissions are pre-granted', (
      tester,
    ) async {
      bridge = FakeIntegrationBridge();
      bridge.setPermissionSnapshot(
        const PermissionSnapshot(
          recordAudio: true,
          phoneState: true,
          callLog: true,
          answerPhoneCalls: true,
          overlay: true,
          notification: true,
          accessibility: true,
          callScreening: true,
        ),
      );
      final harness = await IntegrationTestHarness.build(
        bridge: bridge,
        initialPermissions: const PermissionSnapshot(
          recordAudio: true,
          phoneState: true,
          callLog: true,
          answerPhoneCalls: true,
          overlay: true,
          notification: true,
          accessibility: true,
          callScreening: true,
        ),
      );

      try {
        await tester.pumpWidget(harness.widget);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        expect(
          find.byType(HomePage),
          findsOneWidget,
          reason: 'Home page should be visible',
        );

        expect(
          find.text('Lá chắn cuộc gọi'),
          findsWidgets,
          reason: 'Home page should show the app title',
        );

        final startButton = find.widgetWithText(
          ElevatedButton,
          'Bắt đầu giám sát',
        );
        if (startButton.evaluate().isNotEmpty) {
          final w = tester.widget<ElevatedButton>(startButton);
          expect(
            w.onPressed,
            isNotNull,
            reason:
                'Start button should be enabled when recordAudio is granted',
          );
        }
      } finally {
        await harness.dispose();
      }
    });

    testWidgets('App shows permission prompt when mic is denied', (
      tester,
    ) async {
      bridge = FakeIntegrationBridge();
      const deniedMic = PermissionSnapshot(
        recordAudio: false,
        phoneState: true,
        callLog: true,
        overlay: true,
        notification: true,
        accessibility: true,
        callScreening: true,
      );
      bridge.setPermissionSnapshot(deniedMic);
      final harness = await IntegrationTestHarness.build(
        bridge: bridge,
        initialPermissions: deniedMic,
      );

      try {
        await tester.pumpWidget(harness.widget);

        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        expect(
          find.byType(HomePage),
          findsOneWidget,
          reason: 'Home page should still be mounted',
        );

        expect(
          find.byType(Dialog),
          findsWidgets,
          reason: 'A permission dialog should be shown',
        );

        expect(
          find.text('Quyền ứng dụng'),
          findsOneWidget,
          reason: 'Permission dialog header should be visible',
        );

        final startButton = find.widgetWithText(
          ElevatedButton,
          'Bắt đầu giám sát',
        );
        if (startButton.evaluate().isNotEmpty) {
          final w = tester.widget<ElevatedButton>(startButton);
          expect(
            w.onPressed,
            isNull,
            reason:
                'Start button should be disabled when recordAudio is denied',
          );
        }
      } finally {
        await harness.dispose();
      }
    });
  });
}
