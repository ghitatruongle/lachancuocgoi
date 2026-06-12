import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/gemini_metrics.dart';

void main() {
  group('GeminiMetrics singleton', () {
    setUp(() {
      GeminiMetrics.resetForTesting();
    });

    test('instance returns the same object every time', () {
      final a = GeminiMetrics.instance;
      final b = GeminiMetrics.instance;
      expect(identical(a, b), isTrue);
    });
  });

  group('recordCall — success', () {
    setUp(() {
      GeminiMetrics.resetForTesting();
    });

    test('increments totalCalls and successCalls on success', () {
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 100);
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 200);

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.totalApiCalls, 2);
      expect(snap.successCalls, 2);
      expect(snap.failureCalls, 0);
    });
  });

  group('recordCall — failure', () {
    setUp(() {
      GeminiMetrics.resetForTesting();
    });

    test('increments totalCalls and failureCalls on failure', () {
      GeminiMetrics.instance.recordCall(success: false, latencyMs: 50);
      GeminiMetrics.instance.recordCall(success: false, latencyMs: 60);

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.totalApiCalls, 2);
      expect(snap.successCalls, 0);
      expect(snap.failureCalls, 2);
    });

    test('increments errorsPerKey when keyIndex is provided', () {
      GeminiMetrics.instance.recordCall(
        success: false,
        latencyMs: 30,
        keyIndex: 0,
      );
      GeminiMetrics.instance.recordCall(
        success: false,
        latencyMs: 30,
        keyIndex: 0,
      );

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.perKeyMetrics.length, 1);
      expect(snap.perKeyMetrics.first.index, 0);
      expect(snap.perKeyMetrics.first.calls, 2);
      expect(snap.perKeyMetrics.first.errors, 2);
    });
  });

  group('recordCall — mixed', () {
    setUp(() {
      GeminiMetrics.resetForTesting();
    });

    test('correctly tracks mixed success and failure', () {
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 100);
      GeminiMetrics.instance.recordCall(success: false, latencyMs: 50);
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 150);

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.totalApiCalls, 3);
      expect(snap.successCalls, 2);
      expect(snap.failureCalls, 1);
    });
  });

  group('recordCacheHit / recordCacheMiss', () {
    setUp(() {
      GeminiMetrics.resetForTesting();
    });

    test('recordCacheHit increments cacheHits counter', () {
      GeminiMetrics.instance.recordCacheHit();
      GeminiMetrics.instance.recordCacheHit();
      GeminiMetrics.instance.recordCacheHit();

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.cacheHits, 3);
      expect(snap.cacheMisses, 0);
    });

    test('recordCacheMiss increments cacheMisses counter', () {
      GeminiMetrics.instance.recordCacheMiss();
      GeminiMetrics.instance.recordCacheMiss();

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.cacheHits, 0);
      expect(snap.cacheMisses, 2);
    });

    test('cacheHitRate is correct with mixed hits and misses', () {
      GeminiMetrics.instance.recordCacheHit();
      GeminiMetrics.instance.recordCacheHit();
      GeminiMetrics.instance.recordCacheMiss();
      GeminiMetrics.instance.recordCacheMiss();

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.cacheHitRate, 0.5);
    });

    test('cacheHitRate is 0 when no requests recorded', () {
      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.cacheHitRate, 0.0);
    });

    test('cacheHitRate is 1.0 when all are hits', () {
      GeminiMetrics.instance.recordCacheHit();
      GeminiMetrics.instance.recordCacheHit();

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.cacheHitRate, 1.0);
    });
  });

  group('MetricsSnapshot', () {
    setUp(() {
      GeminiMetrics.resetForTesting();
    });

    test('has correct field values after mixed operations', () {
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 100);
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 200);
      GeminiMetrics.instance.recordCall(success: false, latencyMs: 50);
      GeminiMetrics.instance.recordCacheHit();
      GeminiMetrics.instance.recordCacheMiss();

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.totalApiCalls, 3);
      expect(snap.successCalls, 2);
      expect(snap.failureCalls, 1);
      expect(snap.cacheHits, 1);
      expect(snap.cacheMisses, 1);
      expect(snap.cacheHitRate, 0.5);
    });

    test('successRate computes correctly', () {
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 100);
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 100);
      GeminiMetrics.instance.recordCall(success: false, latencyMs: 100);

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.successRate, closeTo(2 / 3, 0.001));
    });

    test('failureRate computes correctly', () {
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 100);
      GeminiMetrics.instance.recordCall(success: false, latencyMs: 100);
      GeminiMetrics.instance.recordCall(success: false, latencyMs: 100);

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.failureRate, closeTo(2 / 3, 0.001));
    });

    test('successRate is 0 when no calls recorded', () {
      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.successRate, 0.0);
    });

    test('failureRate is 0 when no calls recorded', () {
      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.failureRate, 0.0);
    });
  });

  group('average latency calculation', () {
    setUp(() {
      GeminiMetrics.resetForTesting();
    });

    test('computes average latency as integer division', () {
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 100);
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 200);
      // (100 + 200) ~/ 2 = 150
      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.averageLatencyMs, 150);
    });

    test('average latency is 0 when no calls recorded', () {
      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.averageLatencyMs, 0);
    });

    test('average latency tracks across success and failure calls', () {
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 50);
      GeminiMetrics.instance.recordCall(success: false, latencyMs: 150);
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 100);
      // (50 + 150 + 100) ~/ 3 = 100
      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.averageLatencyMs, 100);
    });
  });

  group('per-key metrics tracking', () {
    setUp(() {
      GeminiMetrics.resetForTesting();
    });

    test('tracks calls per key index', () {
      GeminiMetrics.instance.recordCall(
        success: true,
        latencyMs: 100,
        keyIndex: 0,
      );
      GeminiMetrics.instance.recordCall(
        success: true,
        latencyMs: 100,
        keyIndex: 1,
      );
      GeminiMetrics.instance.recordCall(
        success: true,
        latencyMs: 100,
        keyIndex: 0,
      );

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.perKeyMetrics.length, 2);

      final key0 = snap.perKeyMetrics.firstWhere((k) => k.index == 0);
      final key1 = snap.perKeyMetrics.firstWhere((k) => k.index == 1);
      expect(key0.calls, 2);
      expect(key0.errors, 0);
      expect(key1.calls, 1);
      expect(key1.errors, 0);
    });

    test('tracks errors per key index', () {
      GeminiMetrics.instance.recordCall(
        success: false,
        latencyMs: 50,
        keyIndex: 0,
      );
      GeminiMetrics.instance.recordCall(
        success: true,
        latencyMs: 100,
        keyIndex: 0,
      );
      GeminiMetrics.instance.recordCall(
        success: false,
        latencyMs: 50,
        keyIndex: 0,
      );

      final snap = GeminiMetrics.instance.getSnapshot();
      final key0 = snap.perKeyMetrics.first;
      expect(key0.index, 0);
      expect(key0.calls, 3);
      expect(key0.errors, 2);
    });

    test('perKeyMetrics are sorted by index', () {
      GeminiMetrics.instance.recordCall(
        success: true,
        latencyMs: 100,
        keyIndex: 2,
      );
      GeminiMetrics.instance.recordCall(
        success: true,
        latencyMs: 100,
        keyIndex: 0,
      );
      GeminiMetrics.instance.recordCall(
        success: true,
        latencyMs: 100,
        keyIndex: 1,
      );

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.perKeyMetrics.length, 3);
      expect(snap.perKeyMetrics[0].index, 0);
      expect(snap.perKeyMetrics[1].index, 1);
      expect(snap.perKeyMetrics[2].index, 2);
    });

    test('negative keyIndex is excluded from per-key metrics', () {
      // keyIndex defaults to -1, which means "no key"
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 100);

      final snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.perKeyMetrics, isEmpty);
    });
  });

  group('KeyMetricSummary', () {
    test('errorRate computes correctly', () {
      const summary = KeyMetricSummary(index: 0, calls: 10, errors: 3);
      expect(summary.errorRate, closeTo(0.3, 0.001));
    });

    test('errorRate is 0 when calls is 0', () {
      const summary = KeyMetricSummary(index: 0, calls: 0, errors: 0);
      expect(summary.errorRate, 0.0);
    });
  });

  group('resetForTesting', () {
    test('clears all counters to zero', () {
      // Record some data first.
      GeminiMetrics.instance.recordCall(success: true, latencyMs: 100);
      GeminiMetrics.instance.recordCall(success: false, latencyMs: 50);
      GeminiMetrics.instance.recordCacheHit();
      GeminiMetrics.instance.recordCacheMiss();

      // Verify data is present.
      var snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.totalApiCalls, greaterThan(0));

      // Reset.
      GeminiMetrics.resetForTesting();

      // Verify everything is cleared.
      snap = GeminiMetrics.instance.getSnapshot();
      expect(snap.totalApiCalls, 0);
      expect(snap.successCalls, 0);
      expect(snap.failureCalls, 0);
      expect(snap.cacheHits, 0);
      expect(snap.cacheMisses, 0);
      expect(snap.averageLatencyMs, 0);
      expect(snap.cacheHitRate, 0.0);
      expect(snap.perKeyMetrics, isEmpty);
    });
  });
}
