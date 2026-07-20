import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/core/lru_cache.dart';

void main() {
  group('LruCache', () {
    test('initialization asserts valid size', () {
      expect(() => LruCache<String, int>(maxSize: 0), throwsAssertionError);
      expect(() => LruCache<String, int>(maxSize: -1), throwsAssertionError);

      final cache = LruCache<String, int>(maxSize: 5);
      expect(cache.maxSize, 5);
      expect(cache.length, 0);
    });

    test('put and get items correctly', () {
      final cache = LruCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);

      expect(cache.get('a'), 1);
      expect(cache.get('b'), 2);
      expect(cache.get('c'), isNull);
    });

    test('promotes item to MRU on get', () {
      final cache = LruCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      // Access 'a' to promote it to MRU
      expect(cache.get('a'), 1);

      // Now insert 'd' (capacity exceeded). 'b' is the LRU and should be evicted.
      cache.put('d', 4);

      expect(cache.get('b'), isNull); // Evicted
      expect(cache.get('a'), 1); // Still here (MRU)
      expect(cache.get('c'), 3);
      expect(cache.get('d'), 4);
    });

    test('containsKey checks presence without promoting to MRU', () {
      final cache = LruCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      // check containsKey for 'a' (does not promote it)
      expect(cache.containsKey('a'), isTrue);

      // insert 'd', 'a' is still the LRU and should be evicted
      cache.put('d', 4);

      expect(cache.containsKey('a'), isFalse); // Evicted!
      expect(cache.containsKey('b'), isTrue);
    });

    test('putIfAbsent inserts when missing and returns null', () {
      final cache = LruCache<String, int>(maxSize: 3);

      int callCount = 0;
      final result1 = cache.putIfAbsent('a', () {
        callCount++;
        return 1;
      });

      expect(result1, isNull);
      expect(callCount, 1);
      expect(cache.get('a'), 1);
    });

    test(
      'putIfAbsent returns existing and promotes without calling generator',
      () {
        final cache = LruCache<String, int>(maxSize: 3);
        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);

        int callCount = 0;
        final result = cache.putIfAbsent('a', () {
          callCount++;
          return 99;
        });

        expect(result, 1);
        expect(callCount, 0); // Not called

        // insert 'd', 'b' should be evicted because 'a' was promoted
        cache.put('d', 4);

        expect(cache.get('b'), isNull); // Evicted
        expect(cache.get('a'), 1); // Kept
      },
    );

    test('remove deletes specified key', () {
      final cache = LruCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);

      cache.remove('a');
      expect(cache.get('a'), isNull);
      expect(cache.length, 1);
    });

    test('clear empties cache', () {
      final cache = LruCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);

      cache.clear();
      expect(cache.length, 0);
      expect(cache.get('a'), isNull);
    });

    test('entries iterates in LRU to MRU order', () {
      final cache = LruCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      // Access 'a' to make it MRU
      cache.get('a');

      // Order should be 'b', 'c', 'a'
      final order = cache.entries.map((e) => e.key).toList();
      expect(order, ['b', 'c', 'a']);
    });

    test('toString representation', () {
      final cache = LruCache<String, int>(maxSize: 10);
      cache.put('a', 1);
      expect(cache.toString(), 'LruCache(1/10)');
    });
    group('evicting multiple when capacity exceeded drastically', () {
      test('reduces size to maxSize', () {
        // In practice _evictIfNeeded is called after every put, so it never exceeds by more than 1.
        // But if someone manually modifies the internal map, it should evict until maxSize.
        final cache = LruCache<String, int>(maxSize: 2);
        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);
        expect(cache.length, 2);
      });
    });
  });
}
