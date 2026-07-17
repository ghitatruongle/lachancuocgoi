class GeminiMetrics {
  GeminiMetrics._();

  /// Singleton instance used throughout the app.
  static final GeminiMetrics instance = GeminiMetrics._();

  int _totalCalls = 0;
  int _successCalls = 0;
  int _failureCalls = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _totalLatencyMs = 0;
  final Map<int, int> _callsPerKey = <int, int>{};
  final Map<int, int> _errorsPerKey = <int, int>{};
  final List<String> _errorLogs = <String>[];

  List<String> get recentErrors => List<String>.unmodifiable(_errorLogs);

  void addErrorLog(String log) {
    _errorLogs.add(log);
    if (_errorLogs.length > 100) {
      _errorLogs.removeAt(0);
    }
  }

  void recordCall({
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

  void recordCacheHit() {
    _cacheHits++;
  }

  void recordCacheMiss() {
    _cacheMisses++;
  }

  MetricsSnapshot getSnapshot() {
    final totalRequests = _cacheHits + _cacheMisses;
    final summaries =
        _callsPerKey.entries
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
      recentErrors: recentErrors,
    );
  }

  /// Create a fresh instance for testing isolation.
  /// Tests should call this in setUp() instead of reset().
  static void resetForTesting() {
    instance._totalCalls = 0;
    instance._successCalls = 0;
    instance._failureCalls = 0;
    instance._cacheHits = 0;
    instance._cacheMisses = 0;
    instance._totalLatencyMs = 0;
    instance._callsPerKey.clear();
    instance._errorsPerKey.clear();
    instance._errorLogs.clear();
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
    this.recentErrors = const <String>[],
  });

  final int totalApiCalls;
  final int successCalls;
  final int failureCalls;
  final int cacheHits;
  final int cacheMisses;
  final int averageLatencyMs;
  final double cacheHitRate;
  final List<KeyMetricSummary> perKeyMetrics;
  final List<String> recentErrors;

  double get successRate =>
      totalApiCalls > 0 ? successCalls / totalApiCalls : 0;

  double get failureRate =>
      totalApiCalls > 0 ? failureCalls / totalApiCalls : 0;
}
