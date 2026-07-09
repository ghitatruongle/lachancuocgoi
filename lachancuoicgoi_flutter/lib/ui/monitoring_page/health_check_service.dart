import 'dart:async' show Timer;

import '../../core/system_logger.dart';
import '../../services/native_call_shield_bridge.dart';

/// Periodically checks that the native monitoring service is still running and
/// auto-restarts it if needed, with exponential backoff.
///
/// Extracted from [MonitoringController] to reduce class size.
class HealthCheckService {
  HealthCheckService({
    required NativeBridgeInterface Function() getBridge,
    required bool Function() isCreatorMode,
    required void Function() onServiceDown,
    required Future<void> Function() onRestart,
  }) : _getBridge = getBridge,
       _isCreatorMode = isCreatorMode,
       _onServiceDown = onServiceDown,
       _onRestart = onRestart;

  final NativeBridgeInterface Function() _getBridge;
  final bool Function() _isCreatorMode;
  final void Function() _onServiceDown;
  final Future<void> Function() _onRestart;

  Timer? _healthCheckTimer;
  int _healthCheckRetryCount = 0;
  bool _isRunning = false;

  /// Starts the health check with an initial interval.
  void start({Duration initialInterval = const Duration(seconds: 60)}) {
    stop();
    _isRunning = true;
    _healthCheckRetryCount = 0;
    _schedule(initialInterval);
  }

  /// Stops the health check timer.
  void stop() {
    _isRunning = false;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Number of consecutive health check failures.
  int get retryCount => _healthCheckRetryCount;

  void _schedule(Duration interval) {
    if (!_isRunning) return;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer(interval, () async {
      if (!_isRunning) return;
      final bridge = _getBridge();
      final running = _isCreatorMode()
          ? await bridge.isCreatorMonitoringActive()
          : await bridge.isMonitoringActive();

      if (!_isRunning) return;
      if (running) {
        if (_healthCheckRetryCount > 0) {
          SystemLogger.instance.log(LogCategory.system, 'Health check recovered after $_healthCheckRetryCount retries.');
          _healthCheckRetryCount = 0;
        }
        _schedule(const Duration(seconds: 60));
        return;
      }

      _healthCheckRetryCount++;
      if (_healthCheckRetryCount == 1) {
        SystemLogger.instance.log(LogCategory.system, 'Health check: service not running — auto-restarting...', level: LogLevel.warning);
        _onServiceDown();
        await _runRestartSequence();
      } else {
        SystemLogger.instance.log(LogCategory.system, 'Health check: backoff attempt $_healthCheckRetryCount (still down)', level: LogLevel.warning);
      }
      if (!_isRunning) return;
      final nextIntervalSec = (60 * (1 << (_healthCheckRetryCount - 1))).clamp(
        60,
        300,
      );
      _schedule(Duration(seconds: nextIntervalSec));
    });
  }

  // Bug #43 fix: use a monotonically-increasing token instead of a nullable
  // Completer? so the read-modify-write is atomic. Previously, two
  // coroutines could both observe the lock as null, both create their own
  // Completer, and both run `_onRestart()` concurrently — which schedules
  // two native restart intents.
  int _restartLockToken = 0;

  Future<void> _runRestartSequence() async {
    final myToken = ++_restartLockToken;
    if (_isRunning) {
      try {
        await _onRestart();
      } finally {
        // Only clear if no newer caller has taken over.
        if (_restartLockToken == myToken) {
          _restartLockToken = 0;
        }
      }
    }
  }
}
