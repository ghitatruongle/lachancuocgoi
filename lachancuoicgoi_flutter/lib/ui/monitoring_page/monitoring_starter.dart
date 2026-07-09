import '../../app/settings_controller.dart';
import '../../core/system_logger.dart';
import '../../services/developer_mode_manager.dart';
import '../../services/native_call_shield_bridge.dart';
import 'monitoring_state.dart';

// ─── Monitoring Starter ────────────────────────────────────────────────
//
// Handles starting the native monitoring service (creator mode or normal
// mode) based on current settings and developer mode state.
//
// Extracted from [MonitoringController] to reduce class size.

class MonitoringStarter {
  MonitoringStarter({
    required NativeBridgeInterface Function() getBridge,
    required SettingsState Function() getSettings,
    required DeveloperModeState Function() getDevMode,
    required bool Function() isSimulationSession,
    required bool Function() hasTestAnalyzerOverride,
    required void Function(MonitoringPageState Function(MonitoringPageState)
        updater) updateState,
  })  : _getBridge = getBridge,
        _getSettings = getSettings,
        _getDevMode = getDevMode,
        _isSimulationSession = isSimulationSession,
        _hasTestAnalyzerOverride = hasTestAnalyzerOverride,
        _updateState = updateState;

  final NativeBridgeInterface Function() _getBridge;
  final SettingsState Function() _getSettings;
  final DeveloperModeState Function() _getDevMode;
  final bool Function() _isSimulationSession;
  final bool Function() _hasTestAnalyzerOverride;
  final void Function(MonitoringPageState Function(MonitoringPageState)
      updater) _updateState;

  bool _hasAttemptedStart = false;

  bool get hasAttemptedStart => _hasAttemptedStart;

  /// Starts live monitoring if appropriate (not simulation, not already
  /// attempted, not disposed, not in test mode).
  Future<bool> startLiveMonitoringIfNeeded({
    required bool isDisposed,
  }) async {
    if (_isSimulationSession() ||
        _hasAttemptedStart ||
        isDisposed ||
        _hasTestAnalyzerOverride()) {
      return false;
    }
    _hasAttemptedStart = true;

    final bridge = _getBridge();
    final settings = _getSettings();
    final devMode = _getDevMode();

    // Bug #39 fix: re-check permissions at start time. If the user just
    // toggled a permission (or never granted it on the first attempt),
    // _hasAttemptedStart should be reset so the next call can retry after
    // the user fixes the permission.
    final permissionSnapshot = await bridge.getPermissionSnapshot();
    final requiredGranted = permissionSnapshot.recordAudio &&
        permissionSnapshot.phoneState &&
        permissionSnapshot.callLog;
    if (!requiredGranted) {
      SystemLogger.instance.log(
        LogCategory.recording,
        'Chưa đủ quyền — reset attempt flag để thử lại sau khi user cấp quyền.',
        level: LogLevel.warning,
      );
      _hasAttemptedStart = false;
      return false;
    }

    final shouldUseCreatorMode =
        devMode.isActive && settings.creatorAudioCapture;

    SystemLogger.instance.log(
      LogCategory.recording,
      shouldUseCreatorMode
          ? 'Yêu cầu kích hoạt ghi âm ở chế độ Creator (MediaProjection)...'
          : 'Yêu cầu kích hoạt ghi âm ở chế độ nền...',
    );

    if (shouldUseCreatorMode) {
      _updateState((s) => s.copyWith(isCreatorMode: true));
      final alreadyRunning = await bridge.isCreatorMonitoringActive();
      if (alreadyRunning) return true;
      final started = await bridge.startCreatorMonitoring(
        devModeExpiresAtMs: devMode.expiresAtEpochMs,
      );
      if (started) return true;
      _updateState((s) => s.copyWith(isCreatorMode: false));
    }

    final alreadyRunning = await bridge.isMonitoringActive();
    if (!alreadyRunning) {
      await bridge.startMonitoring(
        enableSpeakerphone: settings.autoEnableSpeakerphone,
      );
    }
    return true;
  }

  /// Resets the attempt flag so the next call to [startLiveMonitoringIfNeeded]
  /// will actually try to start.
  void resetAttempt() {
    _hasAttemptedStart = false;
  }

  /// Resets all state for a new session.
  void reset() {
    _hasAttemptedStart = false;
  }
}
