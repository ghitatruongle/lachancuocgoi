/// Tracks how many times each analysis subsystem has fallen back to
/// degraded mode. Surfaced via HealthCheckService so the UI can show
/// a "reduced accuracy" banner when fallbacks accumulate.
class FallbackTracker {
  FallbackTracker._();
  static final FallbackTracker instance = FallbackTracker._();

  final Map<String, int> _counts = {};

  /// Increment the fallback count for [subsystem].
  void increment(String subsystem) {
    _counts[subsystem] = (_counts[subsystem] ?? 0) + 1;
  }

  /// Current fallback count for [subsystem] (0 if never triggered).
  int count(String subsystem) => _counts[subsystem] ?? 0;

  /// Total fallbacks across all subsystems.
  int get total => _counts.values.fold(0, (a, b) => a + b);

  /// All subsystem names that have at least 1 fallback.
  Map<String, int> get allCounts => Map.unmodifiable(_counts);

  /// Reset all counters (called on session start).
  void reset() => _counts.clear();
}
