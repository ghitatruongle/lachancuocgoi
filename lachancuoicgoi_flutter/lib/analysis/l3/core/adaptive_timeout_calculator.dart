import 'dart:math' show max, min;

/// Calculates dynamic L3 Cloud AI timeouts based on measured physical RTT.
///
/// Uses Exponential Moving Average (EMA) to smooth out network latency spikes:
/// RTT_new = alpha * RTT_sample + (1 - alpha) * RTT_current
class AdaptiveTimeoutCalculator {
  AdaptiveTimeoutCalculator({
    int initialTimeoutMs = 1000,
    this.minTimeoutMs = 600,
    this.maxTimeoutMs = 2500,
    this.alpha = 0.3,
  }) : _currentRttMs = initialTimeoutMs.toDouble();

  final int minTimeoutMs;
  final int maxTimeoutMs;
  final double alpha;
  double _currentRttMs;
  int _sampleCount = 0;

  /// Returns the estimated physical Round-Trip Time in milliseconds.
  double get currentRttMs => _currentRttMs;

  /// Returns total network samples recorded.
  int get sampleCount => _sampleCount;

  /// Records a successful Gemini request latency sample.
  void recordSample(int latencyMs) {
    if (latencyMs <= 0) return;
    _sampleCount++;
    if (_sampleCount == 1) {
      _currentRttMs = latencyMs.toDouble();
    } else {
      _currentRttMs = alpha * latencyMs + (1.0 - alpha) * _currentRttMs;
    }
  }

  /// Calculates the dynamic L3 timeout for the next cloud request.
  int calculateTimeoutMs() {
    final computed = (_currentRttMs * 1.5 + 200).round();
    return max(minTimeoutMs, min(maxTimeoutMs, computed));
  }

  /// Resets the calculator to default initial state.
  void reset({int initialTimeoutMs = 1000}) {
    _currentRttMs = initialTimeoutMs.toDouble();
    _sampleCount = 0;
  }
}
