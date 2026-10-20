import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/developer_mode_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DeveloperModeController — tap state machine', () {
    test('initial state is inactive', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await Future<void>.delayed(Duration.zero);

      final state = container.read(developerModeProvider);
      expect(state.isActive, isFalse);
      expect(state.remainingSeconds, -1);
      expect(state.expiresAtEpochMs, 0);
    });

    test('first 9 taps return nothing', () {
      final controller = DeveloperModeController();
      for (var i = 0; i < 9; i++) {
        expect(controller.onTitleTap(), DeveloperTapResult.nothing);
      }
    });

    test('10th tap returns showPassword', () {
      final controller = DeveloperModeController();
      DeveloperTapResult? finalResult;
      for (var i = 0; i < 10; i++) {
        finalResult = controller.onTitleTap();
      }
      expect(finalResult, DeveloperTapResult.showPassword);
    });

    testWidgets('tap counter resets after timeout (2000ms)', (tester) async {
      final controller = DeveloperModeController();

      for (var i = 0; i < 5; i++) {
        controller.onTitleTap();
      }

      await tester.pump(const Duration(milliseconds: 2100));

      expect(controller.onTitleTap(), DeveloperTapResult.nothing);

      for (var i = 0; i < 8; i++) {
        controller.onTitleTap();
      }
      expect(controller.onTitleTap(), DeveloperTapResult.showPassword);
    });

    test('verifyPassword accepts correct password', () {
      final controller = DeveloperModeController();
      expect(controller.verifyPassword('110210'), isTrue);
    });

    test('verifyPassword rejects wrong password', () {
      final controller = DeveloperModeController();
      expect(controller.verifyPassword('000000'), isFalse);
    });

    test('verifyPassword is lenient with whitespace', () {
      final controller = DeveloperModeController();
      expect(controller.verifyPassword('  110210  '), isTrue);
    });

    test('verifyPassword rejects empty string', () {
      final controller = DeveloperModeController();
      expect(controller.verifyPassword(''), isFalse);
    });
  });

  group('DeveloperModeController — activation', () {
    test('activate sets state to active', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(developerModeProvider.notifier);
      await controller.activate();

      final state = container.read(developerModeProvider);
      expect(state.isActive, isTrue);
      expect(state.remainingSeconds, greaterThan(0));
      expect(state.expiresAtEpochMs, greaterThan(0));
    });

    test('deactivate resets state', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(developerModeProvider.notifier);
      await controller.activate();
      await controller.deactivate();

      final state = container.read(developerModeProvider);
      expect(state.isActive, isFalse);
      expect(state.remainingSeconds, -1);
      expect(state.expiresAtEpochMs, 0);
    });

    test('isActive getter returns correct value before activation', () {
      final controller = DeveloperModeController();
      expect(controller.isActive, isFalse);
    });
  });

  group('DeveloperModeController — deactivation taps', () {
    test('3 deactivate taps trigger deactivation when active', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(developerModeProvider.notifier);
      await controller.activate();

      expect(controller.onTitleTap(), DeveloperTapResult.nothing);

      expect(controller.onTitleTap(), DeveloperTapResult.nothing);

      final thirdResult = controller.onTitleTap();
      expect(thirdResult, DeveloperTapResult.deactivated);

      final state = container.read(developerModeProvider);
      expect(state.isActive, isFalse);
    });

    testWidgets('deactivate tap counter resets after timeout', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(developerModeProvider.notifier);
      await controller.activate();

      controller.onTitleTap();
      controller.onTitleTap();

      await tester.pump(const Duration(milliseconds: 2100));

      expect(controller.onTitleTap(), DeveloperTapResult.nothing);

      expect(controller.onTitleTap(), DeveloperTapResult.nothing);

      expect(controller.onTitleTap(), DeveloperTapResult.deactivated);
    });
  });

  group('DeveloperModeController — expiry', () {
    test('expiresAtEpochMs is 0 when not active', () {
      final controller = DeveloperModeController();
      expect(controller.expiresAtEpochMs, 0);
    });

    test('remainingSeconds returns -1 when not active', () {
      final controller = DeveloperModeController();
      expect(controller.remainingSeconds, -1);
    });

    test('activate sets 10 minute expiry', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(developerModeProvider.notifier);
      final beforeActivation = DateTime.now().millisecondsSinceEpoch;
      await controller.activate();
      final afterActivation = DateTime.now().millisecondsSinceEpoch;

      final state = container.read(developerModeProvider);

      expect(state.expiresAtEpochMs, greaterThan(beforeActivation + 599_000));
      expect(state.expiresAtEpochMs, lessThan(afterActivation + 601_000));
    });
  });

  group('DeveloperModeController — persistence', () {
    test('persists activatedAt to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(developerModeProvider.notifier);
      await controller.activate();

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('DEV_MODE_ACTIVATED_AT_MS');
      expect(saved, isNotNull);
      expect(saved, greaterThan(0));
    });

    test('removes from SharedPreferences on deactivate', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(developerModeProvider.notifier);
      await controller.activate();
      await controller.deactivate();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('DEV_MODE_ACTIVATED_AT_MS'), isFalse);
    });
  });
}
