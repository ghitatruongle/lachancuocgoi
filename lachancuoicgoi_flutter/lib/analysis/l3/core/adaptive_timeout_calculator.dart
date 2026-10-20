import 'dart:math' show max, min;

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

  double get currentRttMs => _currentRttMs;

  int get sampleCount => _sampleCount;

  void recordSample(int latencyMs) {
    if (latencyMs <= 0) return;
    _sampleCount++;
    if (_sampleCount == 1) {
      _currentRttMs = latencyMs.toDouble();
    } else {
      _currentRttMs = alpha * latencyMs + (1.0 - alpha) * _currentRttMs;
    }
  }

  int calculateTimeoutMs() {
    final computed = (_currentRttMs * 1.5 + 200).round();
    return max(minTimeoutMs, min(maxTimeoutMs, computed));
  }

  void reset({int initialTimeoutMs = 1000}) {
    _currentRttMs = initialTimeoutMs.toDouble();
    _sampleCount = 0;
  }
}
