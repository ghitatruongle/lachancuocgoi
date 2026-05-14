class GeminiMetrics {
  static int _totalCalls = 0;
  static int _successCalls = 0;
  static int _failureCalls = 0;
  static int _cacheHits = 0;
  static int _cacheMisses = 0;
  static int _totalLatencyMs = 0;
  static final Map<int, int> _callsPerKey = <int, int>{};
  static final Map<int, int> _errorsPerKey = <int, int>{};

  static void recordCall({
    required bool success,
    required int latencyMs,
    int keyIndex = -1,
  }) {
    _totalCalls++;
    if (success) {
      _successCalls++;
    } else {
      _failureCalls++;
      if (keyIndex >= 0) {
        _errorsPerKey[keyIndex] = (_errorsPerKey[keyIndex] ?? 0) + 1;
      }
    }
    _totalLatencyMs += latencyMs;
    if (keyIndex >= 0) {
      _callsPerKey[keyIndex] = (_callsPerKey[keyIndex] ?? 0) + 1;
    }
  }

  static void recordCacheHit() {
    _cacheHits++;
  }

  static void recordCacheMiss() {
    _cacheMisses++;
  }

  static MetricsSnapshot getSnapshot() {
    final totalRequests = _cacheHits + _cacheMisses;
    final summaries = _callsPerKey.entries
        .map(
          (entry) => KeyMetricSummary(
            index: entry.key,
            calls: entry.value,
            errors: _errorsPerKey[entry.key] ?? 0,
          ),
        )
        .toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    return MetricsSnapshot(
      totalApiCalls: _totalCalls,
      successCalls: _successCalls,
      failureCalls: _failureCalls,
      cacheHits: _cacheHits,
      cacheMisses: _cacheMisses,
      averageLatencyMs: _totalCalls > 0 ? _totalLatencyMs ~/ _totalCalls : 0,
      cacheHitRate: totalRequests > 0 ? _cacheHits / totalRequests : 0,
      perKeyMetrics: summaries,
    );
  }

  static void reset() {
    _totalCalls = 0;
    _successCalls = 0;
    _failureCalls = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    _totalLatencyMs = 0;
    _callsPerKey.clear();
    _errorsPerKey.clear();
  }
}

class KeyMetricSummary {
  const KeyMetricSummary({
    required this.index,
    required this.calls,
    required this.errors,
  });

  final int index;
  final int calls;
  final int errors;

  double get errorRate => calls > 0 ? errors / calls : 0;
}

class MetricsSnapshot {
  const MetricsSnapshot({
    required this.totalApiCalls,
    required this.successCalls,
    required this.failureCalls,
    required this.cacheHits,
    required this.cacheMisses,
    required this.averageLatencyMs,
    required this.cacheHitRate,
    this.perKeyMetrics = const <KeyMetricSummary>[],
  });

  final int totalApiCalls;
  final int successCalls;
  final int failureCalls;
  final int cacheHits;
  final int cacheMisses;
  final int averageLatencyMs;
  final double cacheHitRate;
  final List<KeyMetricSummary> perKeyMetrics;

  double get successRate => totalApiCalls > 0 ? successCalls / totalApiCalls : 0;

  double get failureRate => totalApiCalls > 0 ? failureCalls / totalApiCalls : 0;
}
