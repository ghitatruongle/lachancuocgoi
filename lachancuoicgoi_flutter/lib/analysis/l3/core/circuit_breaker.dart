class CircuitBreaker {
  CircuitBreaker({
    this.failureThreshold = 5,
    this.errorRateThreshold = 0.6,
    this.windowSize = const Duration(minutes: 10),
    this.cooldown = const Duration(minutes: 2),
    this.minRequestsForRateCheck = 5,
  });

  final int failureThreshold;

  final double errorRateThreshold;

  final Duration windowSize;

  final Duration cooldown;

  final int minRequestsForRateCheck;

  int _consecutiveErrors = 0;
  DateTime? _circuitOpenUntil;
  DateTime? _lastErrorTime;
  final List<DateTime> _requestTimestamps = [];
  final List<DateTime> _errorTimestamps = [];

  bool get isOpen {
    if (_circuitOpenUntil == null) return false;
    if (DateTime.now().isBefore(_circuitOpenUntil!)) return true;

    _circuitOpenUntil = null;
    _consecutiveErrors = 0;
    return false;
  }

  DateTime? get openUntil => _circuitOpenUntil;

  int get consecutiveErrors => _consecutiveErrors;

  DateTime? get lastErrorTime => _lastErrorTime;

  bool get shouldAllowRequest => !isOpen;

  void recordSuccess() {
    _consecutiveErrors = 0;
    _circuitOpenUntil = null;
    _recordTimestamp(isError: false);
  }

  void recordFailure() {
    _consecutiveErrors++;
    _lastErrorTime = DateTime.now();
    _recordTimestamp(isError: true);
    _checkTrip();
  }

  String getErrorRateString() {
    if (_requestTimestamps.isEmpty) return '0%';
    final rate = (_errorTimestamps.length / _requestTimestamps.length) * 100;
    return '${rate.toStringAsFixed(1)}%';
  }

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

    final windowStart = now.subtract(windowSize);
    _requestTimestamps.removeWhere((t) => t.isBefore(windowStart));
    _errorTimestamps.removeWhere((t) => t.isBefore(windowStart));
  }

  void _checkTrip() {
    final now = DateTime.now();

    if (_consecutiveErrors >= failureThreshold) {
      _circuitOpenUntil = now.add(cooldown);
      return;
    }

    if (_requestTimestamps.length >= minRequestsForRateCheck) {
      final errorRate = _errorTimestamps.length / _requestTimestamps.length;
      if (errorRate > errorRateThreshold) {
        _circuitOpenUntil = now.add(cooldown);
      }
    }
  }
}
