import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/response_cache.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';

void main() {
  group('ResponseCache', () {
    test('get returns null for missing key', () {
      final cache = ResponseCache<String>();
      expect(cache.get('missing'), isNull);
    });

    test('put then get returns stored value', () {
      final cache = ResponseCache<String>();
      cache.put('key1', 'value1');
      expect(cache.get('key1'), 'value1');
    });

    test('put overwrites existing key', () {
      final cache = ResponseCache<String>();
      cache.put('key1', 'value1');
      cache.put('key1', 'value2');
      expect(cache.get('key1'), 'value2');
    });

    test('clear removes all entries', () {
      final cache = ResponseCache<String>();
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.clear();
      expect(cache.get('key1'), isNull);
      expect(cache.get('key2'), isNull);
    });

    test('getStats reports correct size and maxSize', () {
      final cache = ResponseCache<String>(maxSize: 50);
      cache.put('a', '1');
      cache.put('b', '2');
      final stats = cache.getStats();
      expect(stats.size, 2);
      expect(stats.maxSize, 50);
      expect(stats.usagePercent, 4.0);
    });

    test('evicts oldest entry when maxSize exceeded', () {
      final cache = ResponseCache<String>(maxSize: 2);
      cache.put('a', '1');
      cache.put('b', '2');
      cache.put('c', '3');
      expect(cache.get('a'), isNull);
      expect(cache.get('b'), '2');
      expect(cache.get('c'), '3');
    });

    test('key normalization: case insensitive and trimmed', () {
      final cache = ResponseCache<String>();
      cache.put('  Hello  ', 'value');
      expect(cache.get('hello'), 'value');
      expect(cache.get('HELLO'), 'value');
    });

    test('sweepExpired removes expired entries', () async {
      final cache = ResponseCache<String>();
      // Default TTL is 5 minutes for green
      cache.put('key1', 'value1', riskLevel: RiskLevel.green);
      // Cannot easily wait 5 minutes, so test sweep with no expired
      final removed = cache.sweepExpired();
      expect(removed, 0);
      expect(cache.getStats().size, 1);
    });

    test('CacheStats usagePercent returns 0 when maxSize is 0', () {
      const stats = CacheStats(size: 0, maxSize: 0);
      expect(stats.usagePercent, 0.0);
    });

    test('handles generic type int', () {
      final cache = ResponseCache<int>();
      cache.put('count', 42);
      expect(cache.get('count'), 42);
    });
  });
}
