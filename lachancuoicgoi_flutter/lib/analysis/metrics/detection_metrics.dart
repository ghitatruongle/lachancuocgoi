/// Local-only detection metrics counters for field validation (v1.6.5).
///
/// No network upload — developer/export use only. Protocol notes:
/// `docs/eval_field_protocol.md` (optional).
class DetectionMetrics {
  int l1Calls = 0;
  int l2Calls = 0;
  int l3Calls = 0;
  int l3Fallbacks = 0;
  int l3Timeouts = 0;
  final List<int> l3LatencyMs = <int>[];

  void recordL1() => l1Calls++;
  void recordL2() => l2Calls++;

  void recordL3Success(int latencyMs) {
    l3Calls++;
    if (latencyMs >= 0) l3LatencyMs.add(latencyMs);
  }

  void recordL3Fallback({bool timeout = false}) {
    l3Fallbacks++;
    if (timeout) l3Timeouts++;
  }

  int? get l3LatencyP50 {
    if (l3LatencyMs.isEmpty) return null;
    final sorted = List<int>.from(l3LatencyMs)..sort();
    return sorted[sorted.length ~/ 2];
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'l1Calls': l1Calls,
    'l2Calls': l2Calls,
    'l3Calls': l3Calls,
    'l3Fallbacks': l3Fallbacks,
    'l3Timeouts': l3Timeouts,
    'l3LatencyP50Ms': l3LatencyP50,
    'l3LatencySamples': l3LatencyMs.length,
  };

  void reset() {
    l1Calls = 0;
    l2Calls = 0;
    l3Calls = 0;
    l3Fallbacks = 0;
    l3Timeouts = 0;
    l3LatencyMs.clear();
  }
}
