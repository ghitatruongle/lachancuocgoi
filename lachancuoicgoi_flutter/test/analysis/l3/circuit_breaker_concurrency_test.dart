import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/circuit_breaker.dart';

void main() {
  group('CircuitBreaker concurrency / trip behaviour', () {
    test('opens after consecutive failures at threshold', () {
      final breaker = CircuitBreaker(
        failureThreshold: 3,
        minRequestsForRateCheck: 100,
        cooldown: const Duration(minutes: 2),
      );
      expect(breaker.shouldAllowRequest, isTrue);
      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.isOpen, isFalse);
      breaker.recordFailure();
      expect(breaker.isOpen, isTrue);
      expect(breaker.shouldAllowRequest, isFalse);
    });

    test('success resets consecutive errors', () {
      final breaker = CircuitBreaker(failureThreshold: 3);
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordSuccess();
      expect(breaker.consecutiveErrors, 0);
      breaker.recordFailure();
      expect(breaker.isOpen, isFalse);
    });

    test('rapid failure burst does not throw', () {
      final breaker = CircuitBreaker(failureThreshold: 5);
      for (var i = 0; i < 50; i++) {
        breaker.recordFailure();
      }
      expect(breaker.isOpen, isTrue);
      expect(breaker.getErrorRateString(), isNotEmpty);
    });
  });
}
