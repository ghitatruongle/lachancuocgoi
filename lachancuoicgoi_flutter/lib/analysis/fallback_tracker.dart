class FallbackTracker {
  FallbackTracker._();
  static final FallbackTracker instance = FallbackTracker._();

  final Map<String, int> _counts = {};

  void increment(String subsystem) {
    _counts[subsystem] = (_counts[subsystem] ?? 0) + 1;
  }

  int count(String subsystem) => _counts[subsystem] ?? 0;

  int get total => _counts.values.fold(0, (a, b) => a + b);

  Map<String, int> get allCounts => Map.unmodifiable(_counts);

  void reset() => _counts.clear();
}
