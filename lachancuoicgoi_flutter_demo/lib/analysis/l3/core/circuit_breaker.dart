// ─── Circuit Breaker ────────────────────────────────────────────────────
//
// A configurable circuit breaker that tracks request failures using a
// sliding window. When the error rate exceeds the threshold, the circuit
// opens and blocks requests for a cooldown period.
//
// Extracted from [L3Analyzer] and [GeminiClient] to unify the two
// separate circuit breaker implementations into one shared class.

class CircuitBreaker {
  CircuitBreaker({
    this.failureThreshold = 5,
    this.errorRateThreshold = 0.6,
    this.windowSize = const Duration(minutes: 10),
    this.cooldown = const Duration(minutes: 2),
    this.minRequestsForRateCheck = 5,
  });

  /// Number of consecutive failures to trip the breaker (GeminiClient style).
  final int failureThreshold;

  /// Error rate threshold (0.0-1.0) to trip the breaker (L3Analyzer style).
  final double errorRateThreshold;

  /// Sliding window size for error rate calculation.
  final Duration windowSize;

  /// How long the circuit stays open after tripping.
  final Duration cooldown;

  /// Minimum number of requests in the window before rate check applies.
  final int minRequestsForRateCheck;

  int _consecutiveErrors = 0;
  DateTime? _circuitOpenUntil;
  DateTime? _lastErrorTime;
  final List<DateTime> _requestTimestamps = [];
  final List<DateTime> _errorTimestamps = [];

  /// Whether the circuit is currently open (blocking requests).
  bool get isOpen {
    if (_circuitOpenUntil == null) return false;
    if (DateTime.now().isBefore(_circuitOpenUntil!)) return true;
    // Cooldown expired — reset
    _circuitOpenUntil = null;
    _consecutiveErrors = 0;
    return false;
  }

  /// The time when the circuit will next allow requests, or null if closed.
  DateTime? get openUntil => _circuitOpenUntil;

  /// Number of consecutive errors since last success.
  int get consecutiveErrors => _consecutiveErrors;

  /// The most recent error time, or null if no errors recorded.
  DateTime? get lastErrorTime => _lastErrorTime;

  /// Whether a request should be allowed through.
  bool get shouldAllowRequest => !isOpen;

  /// Records a successful request.
  void recordSuccess() {
    _consecutiveErrors = 0;
    _circuitOpenUntil = null;
    _recordTimestamp(isError: false);
  }

  /// Records a failed request. May trip the circuit breaker.
  void recordFailure() {
    _consecutiveErrors++;
    _lastErrorTime = DateTime.now();
    _recordTimestamp(isError: true);
    _checkTrip();
  }

  /// Gets the error rate as a formatted percentage string.
  String getErrorRateString() {
    if (_requestTimestamps.isEmpty) return '0%';
    final rate = (_errorTimestamps.length / _requestTimestamps.length) * 100;
    return '${rate.toStringAsFixed(1)}%';
  }

  /// Resets all circuit breaker state.
  void reset() {
    _consecutiveErrors = 0;
    _circuitOpenUntil = null;
    _lastErrorTime = null;
    _requestTimestamps.clear();
    _errorTimestamps.clear();
  }

  void _recordTimestamp({required bool isError}) {
    final now = DateTime.now();
    _requestTimestamps.add(now);
    if (isError) {
      _errorTimestamps.add(now);
    }

    // Trim to sliding window
    final windowStart = now.subtract(windowSize);
    _requestTimestamps.removeWhere((t) => t.isBefore(windowStart));
    _errorTimestamps.removeWhere((t) => t.isBefore(windowStart));
  }

  void _checkTrip() {
    final now = DateTime.now();

    // Consecutive failures check (GeminiClient style)
    if (_consecutiveErrors >= failureThreshold) {
      _circuitOpenUntil = now.add(cooldown);
      return;
    }

    // Error rate check (L3Analyzer style)
    if (_requestTimestamps.length >= minRequestsForRateCheck) {
      final errorRate = _errorTimestamps.length / _requestTimestamps.length;
      if (errorRate > errorRateThreshold) {
        _circuitOpenUntil = now.add(cooldown);
      }
    }
  }
}
