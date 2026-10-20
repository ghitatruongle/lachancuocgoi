import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/system_logger.dart';

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

  static const String _passwordHash =
      '252342c7f49f80e619a9ddfd621e2cfeceac60db0973176004613350842e02c0';
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
    if (_restored) return;
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    _activatedAtMs = prefs.getInt(_prefsKeyActivatedAt) ?? 0;
    _restored = true;
    _refreshState();
  }

  DeveloperTapResult onTitleTap() {
    final now = clock.now().millisecondsSinceEpoch;

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

  bool verifyPassword(String input) {
    final digest = sha256.convert(utf8.encode(input.trim()));
    return digest.toString() == _passwordHash;
  }

  Future<void> activate() async {
    _activatedAtMs = clock.now().millisecondsSinceEpoch;
    _deactivateTapCount = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyActivatedAt, _activatedAtMs);
    } on Object catch (e) {
      _activatedAtMs = 0;
      SystemLogger.instance.log(
        LogCategory.system,
        'DeveloperMode.activate() persist failed: $e',
        level: LogLevel.error,
      );
    }
    if (!ref.mounted) return;
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
    } on Object catch (e) {
      SystemLogger.instance.log(
        LogCategory.system,
        'DeveloperMode.deactivate() persist failed: $e',
        level: LogLevel.error,
      );
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
    final elapsedMs = clock.now().millisecondsSinceEpoch - _activatedAtMs;
    final remainingMs = _durationMs - elapsedMs;
    if (remainingMs <= 0) {
      return -1;
    }
    return remainingMs ~/ 1000;
  }

  void _refreshState() {
    final remaining = _remainingSeconds();
    if (remaining < 0) {
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
