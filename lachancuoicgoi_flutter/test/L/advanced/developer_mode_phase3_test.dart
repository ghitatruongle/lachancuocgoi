import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/developer_mode_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DeveloperModeController — Phase 3: timer optimization', () {
    test('timer interval is 10 seconds (not 1 second)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await Future<void>.delayed(Duration.zero);

      // Activate developer mode via tap + password + activate
      final controller =
          container.read(developerModeProvider.notifier);
      for (var i = 0; i < 10; i++) {
        controller.onTitleTap();
      }
      expect(controller.verifyPassword('110210'), isTrue);
      await controller.activate();

      final state1 = container.read(developerModeProvider);
      expect(state1.isActive, isTrue);
      final remaining1 = state1.remainingSeconds;

      // Wait 2 seconds — with 10s interval, state should NOT update
      await Future.delayed(const Duration(seconds: 2));
      final state2 = container.read(developerModeProvider);
      // remainingSeconds should be the same (timer hasn't fired yet)
      expect(state2.remainingSeconds, remaining1);

      // Wait for timer to fire (10s total)
      await Future.delayed(const Duration(seconds: 9));
      final state3 = container.read(developerModeProvider);
      // Now remainingSeconds should have decreased
      expect(state3.remainingSeconds, lessThan(remaining1));
    });

    test('deactivation still works with 10s timer', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await Future<void>.delayed(Duration.zero);

      // Activate
      final controller =
          container.read(developerModeProvider.notifier);
      for (var i = 0; i < 10; i++) {
        controller.onTitleTap();
      }
      expect(controller.verifyPassword('110210'), isTrue);
      await controller.activate();

      expect(container.read(developerModeProvider).isActive, isTrue);

      // Deactivate with 3 taps
      for (var i = 0; i < 3; i++) {
        controller.onTitleTap();
      }

      expect(container.read(developerModeProvider).isActive, isFalse);
    });

    test('remainingSeconds decreases in 10s increments', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await Future<void>.delayed(Duration.zero);

      // Activate
      final controller =
          container.read(developerModeProvider.notifier);
      for (var i = 0; i < 10; i++) {
        controller.onTitleTap();
      }
      expect(controller.verifyPassword('110210'), isTrue);
      await controller.activate();

      final initialRemaining =
          container.read(developerModeProvider).remainingSeconds;

      // Wait for one timer tick (10s)
      await Future.delayed(const Duration(seconds: 11));

      final newRemaining =
          container.read(developerModeProvider).remainingSeconds;

      // Should decrease by approximately 10 seconds
      final diff = initialRemaining - newRemaining;
      expect(diff, greaterThanOrEqualTo(8));
      expect(diff, lessThanOrEqualTo(12));
    });

    test('onTitleTap returns showPassword on 10th tap', () {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = DeveloperModeController();
      DeveloperTapResult? lastResult;
      for (var i = 0; i < 10; i++) {
        lastResult = controller.onTitleTap();
      }
      expect(lastResult, DeveloperTapResult.showPassword);
    });

    test('onTitleTap returns deactivated on 3 taps when active', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await Future<void>.delayed(Duration.zero);

      // Activate via container
      final controller =
          container.read(developerModeProvider.notifier);
      for (var i = 0; i < 10; i++) {
        controller.onTitleTap();
      }
      expect(controller.verifyPassword('110210'), isTrue);
      await controller.activate();

      // Deactivate with 3 taps
      DeveloperTapResult? lastResult;
      for (var i = 0; i < 3; i++) {
        lastResult = controller.onTitleTap();
      }
      expect(lastResult, DeveloperTapResult.deactivated);
    });

    test('verifyPassword returns true for correct password', () {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = DeveloperModeController();
      expect(controller.verifyPassword('110210'), isTrue);
      expect(controller.verifyPassword('wrong'), isFalse);
    });

    test('verifyPassword returns false for incorrect password', () {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = DeveloperModeController();
      expect(controller.verifyPassword('000000'), isFalse);
      expect(controller.verifyPassword(''), isFalse);
    });
  });
}
