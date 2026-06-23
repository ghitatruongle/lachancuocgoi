import 'dart:async' show Timer, Completer;

import 'package:flutter/foundation.dart' show debugPrint;

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
  })  : _getBridge = getBridge,
        _isCreatorMode = isCreatorMode,
        _onServiceDown = onServiceDown,
        _onRestart = onRestart;

  final NativeBridgeInterface Function() _getBridge;
  final bool Function() _isCreatorMode;
  final void Function() _onServiceDown;
  final Future<void> Function() _onRestart;

  Timer? _healthCheckTimer;
  int _healthCheckRetryCount = 0;
  Completer<void>? _restartLock;

  /// Starts the health check with an initial interval.
  void start({Duration initialInterval = const Duration(seconds: 60)}) {
    stop();
    _healthCheckRetryCount = 0;
    _schedule(initialInterval);
  }

  /// Stops the health check timer.
  void stop() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Number of consecutive health check failures.
  int get retryCount => _healthCheckRetryCount;

  void _schedule(Duration interval) {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer(interval, () async {
      final bridge = _getBridge();
      final running = _isCreatorMode()
          ? await bridge.isCreatorMonitoringActive()
          : await bridge.isMonitoringActive();

      if (running) {
        if (_healthCheckRetryCount > 0) {
          debugPrint(
            'Health check recovered after $_healthCheckRetryCount retries.',
          );
          _healthCheckRetryCount = 0;
        }
        _schedule(const Duration(seconds: 60));
        return;
      }

      _healthCheckRetryCount++;
      if (_healthCheckRetryCount == 1) {
        debugPrint('Health check: service not running — auto-restarting...');
        _onServiceDown();
        await _runRestartSequence();
      } else {
        debugPrint(
          'Health check: backoff attempt $_healthCheckRetryCount (still down)',
        );
      }
      final nextIntervalSec =
          (60 * (1 << (_healthCheckRetryCount - 1))).clamp(60, 300);
      _schedule(Duration(seconds: nextIntervalSec));
    });
  }

  Future<void> _runRestartSequence() async {
    final existing = _restartLock;
    if (existing != null) {
      await existing.future;
      return;
    }
    final completer = Completer<void>();
    _restartLock = completer;
    try {
      await _onRestart();
    } finally {
      _restartLock = null;
      completer.complete();
    }
  }
}
