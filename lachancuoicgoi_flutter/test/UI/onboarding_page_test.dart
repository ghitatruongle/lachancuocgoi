import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/ui/onboarding/onboarding_page.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingPage(),
        ),
      ],
    );
  });

  Widget wrapOnboarding({PermissionSnapshot? snapshot}) {
    final bridge = FakeNativeBridge(snapshot: snapshot);
    return ProviderScope(
      overrides: [bridgeOverride(bridge)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('OnboardingPage', () {
    Future<void> finishRationalePager(WidgetTester tester) async {
      // v1.6.5: onboarding starts with multi-step rationales (5 steps).
      for (var i = 0; i < 6; i++) {
        final next = find.text('Tiếp');
        final done = find.text('Xong');
        if (done.evaluate().isNotEmpty) {
          await tester.tap(done);
          await tester.pumpAndSettle();
          return;
        }
        if (next.evaluate().isNotEmpty) {
          await tester.tap(next);
          await tester.pumpAndSettle();
          continue;
        }
        break;
      }
    }

    testWidgets('renders title "Cấp quyền" in AppBar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();
      await finishRationalePager(tester);

      expect(find.text('Cấp quyền'), findsOneWidget);
    });

    testWidgets('renders subtitle texts when permissions are missing', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();
      await finishRationalePager(tester);

      expect(find.text('Bảo vệ cuộc gọi của bạn'), findsOneWidget);
      expect(
        find.text(
          'Ứng dụng cần các quyền sau để giám sát và phát hiện lừa đảo trong cuộc gọi.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders "Bắt đầu cấp quyền" button when not all granted', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();
      await finishRationalePager(tester);

      expect(find.text('Bắt đầu cấp quyền'), findsOneWidget);
    });

    testWidgets('renders "Bỏ qua (không khuyến khích)" skip button', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();
      await finishRationalePager(tester);

      expect(find.text('Bỏ qua (không khuyến khích)'), findsOneWidget);
    });

    testWidgets('shows missing permission names in checklist', (tester) async {
      // All permissions false by default → all should appear in the list.
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();
      await finishRationalePager(tester);

      // Section card header
      expect(find.text('Danh sách quyền cần thiết:'), findsOneWidget);

      // Some expected missing permission names
      expect(find.text('Ghi âm'), findsOneWidget);
      expect(find.text('Trạng thái cuộc gọi'), findsOneWidget);
      expect(find.text('Lịch sử cuộc gọi'), findsOneWidget);
    });

    testWidgets('shows progress indicator with granted/total counts', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();
      await finishRationalePager(tester);

      // Default snapshot: 0/8 granted
      expect(find.text('0/8 quyền đã cấp'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows updated progress when some permissions are granted', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        wrapOnboarding(
          snapshot: const PermissionSnapshot(
            recordAudio: true,
            phoneState: true,
            notification: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await finishRationalePager(tester);

      expect(find.text('3/8 quyền đã cấp'), findsOneWidget);
    });

    testWidgets('continues when core permissions are granted', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // Grant both required capability groups; call screening remains optional.
      await tester.pumpWidget(
        wrapOnboarding(
          snapshot: const PermissionSnapshot(
            recordAudio: true,
            phoneState: true,
            callLog: true,
            answerPhoneCalls: true,
            overlay: true,
            notification: true,
            accessibility: true,
            // callScreening left false
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);
    });

    testWidgets('skip button marks onboarding as completed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // Use a tall viewport so the skip button is visible (default 600 is too short).
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();
      await finishRationalePager(tester);

      await tester.tap(find.text('Bỏ qua (không khuyến khích)'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);
    });

    testWidgets(
      'AppBar does not show back button (automaticallyImplyLeading: false)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(wrapOnboarding());
        await tester.pumpAndSettle();
        await finishRationalePager(tester);

        // No BackButton should be rendered
        expect(find.byType(BackButton), findsNothing);
      },
    );
  });
}
