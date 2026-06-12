import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeveloperModeState {
  const DeveloperModeState({
    this.isActive = false,
    this.remainingSeconds = -1,
    this.expiresAtEpochMs = 0,
  });

  final bool isActive;
  final int remainingSeconds;
  final int expiresAtEpochMs;

  DeveloperModeState copyWith({
    bool? isActive,
    int? remainingSeconds,
    int? expiresAtEpochMs,
  }) {
    return DeveloperModeState(
      isActive: isActive ?? this.isActive,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      expiresAtEpochMs: expiresAtEpochMs ?? this.expiresAtEpochMs,
    );
  }
}

enum DeveloperTapResult { nothing, showPassword, deactivated }

class DeveloperModeController extends Notifier<DeveloperModeState> {
  static const int _requiredTaps = 10;
  static const int _deactivateTaps = 3;
  static const int _tapTimeoutMs = 2000;
  static const int _durationMs = 600000;
  static const String _password = '110210';
  static const String _prefsKeyActivatedAt = 'DEV_MODE_ACTIVATED_AT_MS';

  int _tapCount = 0;
  int _deactivateTapCount = 0;
  int _lastTapMs = 0;
  int _lastDeactivateTapMs = 0;
  int _activatedAtMs = 0;
  bool _restored = false;
  Timer? _ticker;

  @override
  DeveloperModeState build() {
    _restore();
    ref.onDispose(() => _ticker?.cancel());
    return const DeveloperModeState();
  }

  Future<void> _restore() async {
    if (_restored) return; // Prevent double restore.
    final prefs = await SharedPreferences.getInstance();
    _activatedAtMs = prefs.getInt(_prefsKeyActivatedAt) ?? 0;
    _restored = true;
    _refreshState();
  }

  DeveloperTapResult onTitleTap() {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (isActive) {
      if (now - _lastDeactivateTapMs > _tapTimeoutMs) {
        _deactivateTapCount = 0;
      }
      _lastDeactivateTapMs = now;
      _deactivateTapCount++;

      if (_deactivateTapCount >= _deactivateTaps) {
        deactivate();
        return DeveloperTapResult.deactivated;
      }
      return DeveloperTapResult.nothing;
    }

    if (now - _lastTapMs > _tapTimeoutMs) {
      _tapCount = 0;
    }
    _lastTapMs = now;
    _tapCount++;

    if (_tapCount >= _requiredTaps) {
      _tapCount = 0;
      return DeveloperTapResult.showPassword;
    }
    return DeveloperTapResult.nothing;
  }

  bool verifyPassword(String input) => input.trim() == _password;

  Future<void> activate() async {
    _activatedAtMs = DateTime.now().millisecondsSinceEpoch;
    _deactivateTapCount = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyActivatedAt, _activatedAtMs);
    } catch (e) {
      // If persist fails, revert in-memory state to avoid contradiction
      // between isActive (reads _activatedAtMs) and persisted state.
      _activatedAtMs = 0;
      debugPrint('DeveloperMode.activate() persist failed: $e');
    }
    _refreshState();
  }

  Future<void> deactivate() async {
    _activatedAtMs = 0;
    _tapCount = 0;
    _deactivateTapCount = 0;
    _ticker?.cancel();
    state = const DeveloperModeState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyActivatedAt);
    } catch (e) {
      // Non-fatal — in-memory state is already cleared. On next restart
      // the restore will see an expired activation and deactivate.
      debugPrint('DeveloperMode.deactivate() persist failed: $e');
    }
  }

  bool get isActive {
    final remaining = _remainingSeconds();
    return remaining >= 0;
  }

  int get remainingSeconds => _remainingSeconds();

  int get expiresAtEpochMs {
    if (_activatedAtMs == 0 || _remainingSeconds() < 0) return 0;
    return _activatedAtMs + _durationMs;
  }

  int _remainingSeconds() {
    if (_activatedAtMs == 0) return -1;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - _activatedAtMs;
    final remainingMs = _durationMs - elapsedMs;
    if (remainingMs <= 0) {
      return -1;
    }
    return remainingMs ~/ 1000;
  }

  void _refreshState() {
    final remaining = _remainingSeconds();
    if (remaining < 0) {
      // Only deactivate if we were previously active (not a fresh start).
      // This prevents calling deactivate() on first restore when expired.
      if (state.isActive) {
        unawaited(deactivate());
      } else {
        state = const DeveloperModeState();
      }
      return;
    }

    state = DeveloperModeState(
      isActive: true,
      remainingSeconds: remaining,
      expiresAtEpochMs: expiresAtEpochMs,
    );
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    // 10s interval — reduces rebuilds from 600 to 60 over 10 minutes.
    // Countdown display can round to nearest 10s without hurting UX.
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      final remaining = _remainingSeconds();
      if (remaining < 0) {
        unawaited(deactivate());
        return;
      }
      state = state.copyWith(
        isActive: true,
        remainingSeconds: remaining,
        expiresAtEpochMs: expiresAtEpochMs,
      );
    });
  }
}

final developerModeProvider =
    NotifierProvider<DeveloperModeController, DeveloperModeState>(
      DeveloperModeController.new,
    );
