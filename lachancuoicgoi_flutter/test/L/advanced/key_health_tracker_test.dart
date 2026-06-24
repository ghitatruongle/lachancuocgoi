import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/api_key_provider.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/key_health_tracker.dart';

void main() {
  group('KeyHealthTracker — state transitions', () {
    test('initial state: all keys active', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1', 'AIzaKey2']),
      );
      final summary = tracker.getHealthSummary();
      expect(summary.every((k) => k.status == KeyStatus.active), isTrue);
      expect(summary.every((k) => k.consecutiveErrors == 0), isTrue);
    });

    test('markSuccess resets errors and clears cooldown', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      tracker.markError(0, 'Timeout');
      tracker.markError(0, 'Timeout');

      // Reset via success
      tracker.markSuccess(0);

      final summary = tracker.getHealthSummary();
      expect(summary[0].consecutiveErrors, 0);
      expect(summary[0].status, KeyStatus.active);
      expect(summary[0].cooldownUntil, isNull);
      expect(summary[0].lastErrorMessage, isNull);
    });

    test('markSuccess becomes preferred key', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1', 'AIzaKey2', 'AIzaKey3']),
      );
      tracker.markSuccess(2);
      expect(tracker.getAvailableKeyIndex(), 2);
    });

    test('3 consecutive errors triggers cooldown', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      tracker.markError(0, 'err1');
      expect(tracker.getHealthSummary()[0].status, KeyStatus.active);

      tracker.markError(0, 'err2');
      expect(tracker.getHealthSummary()[0].status, KeyStatus.active);

      tracker.markError(0, 'err3');
      expect(tracker.getHealthSummary()[0].status, KeyStatus.cooldown);
      expect(tracker.getHealthSummary()[0].consecutiveErrors, 3);
    });

    test('2 errors do not trigger cooldown', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      tracker.markError(0, 'err');
      tracker.markError(0, 'err2');
      expect(tracker.getHealthSummary()[0].status, KeyStatus.active);
    });

    test('quota exceeded marks cooldown until midnight', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      tracker.markQuotaExceeded(0);

      final summary = tracker.getHealthSummary();
      expect(summary[0].status, KeyStatus.cooldown);
      expect(summary[0].lastErrorMessage, contains('429'));
      expect(summary[0].cooldownUntil, isNotNull);

      // Cooldown should be sometime tomorrow
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(summary[0].cooldownUntil!.day, tomorrow.day);
    });

    test('invalid key marks exhausted', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      tracker.markInvalid(0, '403 API key revoked');

      final summary = tracker.getHealthSummary();
      expect(summary[0].status, KeyStatus.exhausted);
      expect(summary[0].lastErrorMessage, contains('403'));
    });

    test('error state is independent per key index', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1', 'AIzaKey2']),
      );
      tracker.markError(0, 'err');
      tracker.markSuccess(1);

      final s0 = tracker.getHealthSummary()[0];
      final s1 = tracker.getHealthSummary()[1];
      expect(s0.consecutiveErrors, 1);
      expect(s0.status, KeyStatus.active);
      expect(s1.consecutiveErrors, 0);
      expect(s1.status, KeyStatus.active);
    });
  });

  group('KeyHealthTracker — cooldown recovery', () {
    test(
      'recoverCooldownKeysIfNeeded does not recover non-expired cooldowns',
      () {
        final tracker = KeyHealthTracker(
          StaticApiKeyProvider(const ['AIzaKey1']),
        );
        // markQuotaExceeded sets cooldown until midnight (future)
        tracker.markQuotaExceeded(0);
        expect(tracker.getHealthSummary()[0].status, KeyStatus.cooldown);

        // Call recovery — cooldown not expired yet, so key stays cooldown
        tracker.recoverCooldownKeysIfNeeded();
        expect(tracker.getHealthSummary()[0].status, KeyStatus.cooldown);
      },
    );

    test('getAvailableKeyIndex returns -1 when all keys in cooldown', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      tracker.markQuotaExceeded(0);
      expect(tracker.getAvailableKeyIndex(), -1);
    });
  });

  group('KeyHealthTracker — getAvailableKeyIndex', () {
    test('returns -1 when no keys', () {
      final tracker = KeyHealthTracker(StaticApiKeyProvider(const <String>[]));
      expect(tracker.getAvailableKeyIndex(), -1);
    });

    test('returns preferred key when active', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1', 'AIzaKey2']),
      );
      tracker.markSuccess(1);
      expect(tracker.getAvailableKeyIndex(), 1);
    });

    test('returns another key when preferred is exhausted', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1', 'AIzaKey2', 'AIzaKey3']),
      );
      tracker.markSuccess(0);
      tracker.markInvalid(0);
      expect(tracker.getAvailableKeyIndex(), anyOf(1, 2));
    });

    test('returns -1 when all keys exhausted', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1', 'AIzaKey2']),
      );
      tracker.markInvalid(0);
      tracker.markInvalid(1);
      expect(tracker.getAvailableKeyIndex(), -1);
    });
  });

  group('KeyHealthTracker — getActiveKeyIndices', () {
    test('returns all indices when all active', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const [
          'AIzaK1',
          'AIzaK2',
          'AIzaK3',
          'AIzaK4',
          'AIzaK5',
        ]),
      );
      final active = tracker.getActiveKeyIndices();
      expect(active, hasLength(5));
      expect(active.toSet(), {0, 1, 2, 3, 4});
    });

    test('excludes exhausted keys', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaK1', 'AIzaK2', 'AIzaK3']),
      );
      tracker.markInvalid(1);
      final active = tracker.getActiveKeyIndices();
      expect(active, hasLength(2));
      expect(active, isNot(contains(1)));
    });

    test('returns shuffled (order differs from input)', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(List.generate(10, (i) => 'AIzaK$i')),
      );
      // Run multiple times — at least some should differ from [0,1,2,...]
      final runs = List.generate(5, (_) => tracker.getActiveKeyIndices());
      final allFirst = runs.map((r) => r.first).toSet();
      // With 10 keys and 5 runs, it's very unlikely all first elements are identical
      // unless the shuffle is deterministic (which it shouldn't be)
      expect(allFirst.length, greaterThan(1));
    });
  });

  group('KeyHealthTracker — hasActiveKeys / areAllKeysDown', () {
    test('hasActiveKeys true when keys available', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      expect(tracker.hasActiveKeys(), isTrue);
      expect(tracker.areAllKeysDown(), isFalse);
    });

    test('hasActiveKeys false when empty', () {
      final tracker = KeyHealthTracker(StaticApiKeyProvider(const <String>[]));
      expect(tracker.hasActiveKeys(), isFalse);
      expect(tracker.areAllKeysDown(), isTrue);
    });

    test('areAllKeysDown true when all exhausted', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      tracker.markInvalid(0);
      expect(tracker.areAllKeysDown(), isTrue);
    });
  });

  group('KeyHealthTracker — getHealthSummary', () {
    test('correctly reports mixed states', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaK1', 'AIzaK2', 'AIzaK3']),
      );
      tracker.markSuccess(0);
      tracker.markError(1);
      tracker.markInvalid(2);

      final summary = tracker.getHealthSummary();
      expect(summary[0].status, KeyStatus.active);
      expect(summary[0].consecutiveErrors, 0);
      expect(summary[1].status, KeyStatus.active);
      expect(summary[1].consecutiveErrors, 1);
      expect(summary[2].status, KeyStatus.exhausted);
    });
  });

  group('KeyHealthTracker — edge cases', () {
    test('markError on out-of-range index does not crash', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      expect(() => tracker.markError(99), returnsNormally);
      expect(() => tracker.markError(-1), returnsNormally);
    });

    test('markSuccess on out-of-range index does not crash', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      expect(() => tracker.markSuccess(99), returnsNormally);
    });

    test('recoverCooldownKeysIfNeeded with empty cooldowns does nothing', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      expect(() => tracker.recoverCooldownKeysIfNeeded(), returnsNormally);
    });

    test('getAvailableKeyIndex with single active key returns 0', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaKey1']),
      );
      expect(tracker.getAvailableKeyIndex(), 0);
    });

    test('preferredKeyIndex persists across calls', () {
      final tracker = KeyHealthTracker(
        StaticApiKeyProvider(const ['AIzaK1', 'AIzaK2', 'AIzaK3']),
      );
      tracker.markSuccess(2);
      expect(tracker.getAvailableKeyIndex(), 2);
      expect(tracker.getAvailableKeyIndex(), 2);
    });
  });
}
