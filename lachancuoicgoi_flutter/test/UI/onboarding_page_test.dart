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
    testWidgets('renders title "Cấp quyền" in AppBar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();

      expect(find.text('Cấp quyền'), findsOneWidget);
    });

    testWidgets('renders subtitle texts when permissions are missing', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();

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

      expect(find.text('Bắt đầu cấp quyền'), findsOneWidget);
    });

    testWidgets('renders "Bỏ qua (không khuyến khích)" skip button', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();

      expect(find.text('Bỏ qua (không khuyến khích)'), findsOneWidget);
    });

    testWidgets('shows missing permission names in checklist', (tester) async {
      // All permissions false by default → all should appear in the list.
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrapOnboarding());
      await tester.pumpAndSettle();

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

      // Default snapshot: 0/7 granted
      expect(find.text('0/7 quyền đã cấp'), findsOneWidget);
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

      expect(find.text('3/7 quyền đã cấp'), findsOneWidget);
    });

    testWidgets('shows fewer missing items when some permissions granted', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      // Use 6 of 7 granted — NOT all, to avoid triggering context.go('/')
      await tester.pumpWidget(
        wrapOnboarding(
          snapshot: const PermissionSnapshot(
            recordAudio: true,
            phoneState: true,
            callLog: true,
            overlay: true,
            notification: true,
            accessibility: true,
            // callScreening left false
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 6/7 granted, only 1 missing
      expect(find.text('6/7 quyền đã cấp'), findsOneWidget);
      // Only "Sàng lọc cuộc gọi" should appear as missing
      expect(find.text('Sàng lọc cuộc gọi'), findsOneWidget);
      // Other items should NOT appear
      expect(find.text('Ghi âm'), findsNothing);
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

        // No BackButton should be rendered
        expect(find.byType(BackButton), findsNothing);
      },
    );
  });
}
