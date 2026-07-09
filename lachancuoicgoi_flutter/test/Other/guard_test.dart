import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/core/guard.dart';

void main() {
  group('Guard', () {
    test('initial state is unlocked with generation zero', () {
      final guard = Guard();
      expect(guard.isLocked, isFalse);
      expect(guard.generation, 0);
    });

    test('tryLock acquires lock and prevents concurrent acquire', () {
      final guard = Guard();
      expect(guard.tryLock(), isTrue);
      expect(guard.isLocked, isTrue);

      // Subsequent attempt fails
      expect(guard.tryLock(), isFalse);
      expect(guard.isLocked, isTrue);
    });

    test('unlock releases lock', () {
      final guard = Guard();
      expect(guard.tryLock(), isTrue);
      
      guard.unlock();
      expect(guard.isLocked, isFalse);

      // Can lock again
      expect(guard.tryLock(), isTrue);
    });

    test('advanceGeneration increments generation counter', () {
      final guard = Guard();
      expect(guard.generation, 0);

      expect(guard.advanceGeneration(), 1);
      expect(guard.generation, 1);

      expect(guard.advanceGeneration(), 2);
      expect(guard.generation, 2);
    });

    test('reset clears lock state and generation counter', () {
      final guard = Guard();
      guard.tryLock();
      guard.advanceGeneration();
      guard.advanceGeneration();

      expect(guard.isLocked, isTrue);
      expect(guard.generation, 2);

      guard.reset();
      expect(guard.isLocked, isFalse);
      expect(guard.generation, 0);
    });
  });
}
