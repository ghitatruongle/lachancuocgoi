/// A reentrant concurrency guard with generation counter.
///
/// Combines two common patterns:
/// 1. **Lock/unlock** — prevents concurrent execution of a critical section.
/// 2. **Generation counter** — detects stale results from outdated operations.
///
/// Usage:
/// ```dart
/// final guard = Guard();
///
/// Future<Result> doSomething() async {
///   if (!guard.tryLock()) return lastResult; // already in progress
///   final gen = guard.generation;
///   try {
///     final result = await expensiveWork();
///     // Discard if a newer call superseded this one
///     if (gen != guard.generation) return lastResult;
///     return result;
///   } finally {
///     guard.unlock();
///   }
/// }
/// ```
class Guard {
  bool _locked = false;
  int _generation = 0;

  /// Attempts to acquire the lock. Returns `true` if acquired.
  bool tryLock() {
    if (_locked) return false;
    _locked = true;
    return true;
  }

  /// Releases the lock.
  void unlock() {
    _locked = false;
  }

  /// Whether the lock is currently held.
  bool get isLocked => _locked;

  /// Current generation value (monotonically increasing).
  int get generation => _generation;

  /// Advances generation by one and returns the new value.
  int advanceGeneration() => ++_generation;

  /// Resets both lock and generation (for full cleanup).
  void reset() {
    _locked = false;
    _generation = 0;
  }
}
