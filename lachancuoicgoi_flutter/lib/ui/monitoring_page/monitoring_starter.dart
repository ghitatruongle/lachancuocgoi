import '../../app/settings_controller.dart';
import '../../core/system_logger.dart';
import '../../services/developer_mode_manager.dart';
import '../../services/native_call_shield_bridge.dart';
import 'monitoring_state.dart';

class MonitoringStarter {
  MonitoringStarter({
    required NativeBridgeInterface Function() getBridge,
    required SettingsState Function() getSettings,
    required DeveloperModeState Function() getDevMode,
    required bool Function() isSimulationSession,
    required bool Function() hasTestAnalyzerOverride,
    required MonitoringPageState Function() getState,
    required void Function(
      MonitoringPageState Function(MonitoringPageState) updater,
    )
    updateState,
  }) : _getBridge = getBridge,
       _getSettings = getSettings,
       _getDevMode = getDevMode,
       _isSimulationSession = isSimulationSession,
       _hasTestAnalyzerOverride = hasTestAnalyzerOverride,
       _getState = getState,
       _updateState = updateState;

  final NativeBridgeInterface Function() _getBridge;
  final SettingsState Function() _getSettings;
  final DeveloperModeState Function() _getDevMode;
  final bool Function() _isSimulationSession;
  final bool Function() _hasTestAnalyzerOverride;
  final MonitoringPageState Function() _getState;
  final void Function(MonitoringPageState Function(MonitoringPageState) updater)
  _updateState;

  Future<bool>? _startOperation;

  Future<bool> startLiveMonitoringIfNeeded({required bool isDisposed}) {
    if (isDisposed) return Future.value(false);
    if (_isSimulationSession() || _hasTestAnalyzerOverride()) {
      _updateState(
        (s) => s.copyWith(
          phase: MonitoringPhase.active,
          clearMonitoringErrorMessage: true,
        ),
      );
      return Future.value(true);
    }

    final currentPhase = _getState().phase;
    if (currentPhase == MonitoringPhase.active ||
        currentPhase == MonitoringPhase.saved) {
      return Future.value(true);
    }
    final runningOperation = _startOperation;
    if (runningOperation != null) return runningOperation;

    final operation = _performStart();
    _startOperation = operation;
    return operation.whenComplete(() {
      if (identical(_startOperation, operation)) _startOperation = null;
    });
  }

  Future<bool> _performStart() async {
    _updateState(
      (s) => s.copyWith(
        phase: MonitoringPhase.starting,
        clearMonitoringErrorMessage: true,
      ),
    );

    final bridge = _getBridge();
    final settings = _getSettings();
    final devMode = _getDevMode();

    final permissionSnapshot = await bridge.getPermissionSnapshot();
    final requiredGranted =
        permissionSnapshot.recordAudio &&
        permissionSnapshot.phoneState &&
        permissionSnapshot.callLog;
    if (!requiredGranted) {
      SystemLogger.instance.log(
        LogCategory.recording,
        'Chưa đủ quyền để bắt đầu giám sát.',
        level: LogLevel.warning,
      );
      _applyStartResult(
        const MonitoringStartResult(
          MonitoringStartStatus.permissionDenied,
          message: 'Chưa cấp đủ quyền micro, điện thoại và nhật ký cuộc gọi.',
        ),
      );
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
      if (alreadyRunning) {
        _applyStartResult(
          const MonitoringStartResult(MonitoringStartStatus.alreadyRunning),
        );
        return true;
      }
      final started = await bridge.startCreatorMonitoring(
        devModeExpiresAtMs: devMode.expiresAtEpochMs,
      );
      if (started) {
        _applyStartResult(
          const MonitoringStartResult(MonitoringStartStatus.started),
        );
        return true;
      }
      _updateState((s) => s.copyWith(isCreatorMode: false));
    }

    final alreadyRunning = await bridge.isMonitoringActive();
    final result = alreadyRunning
        ? const MonitoringStartResult(MonitoringStartStatus.alreadyRunning)
        : await bridge.startMonitoringWithResult(
            enableSpeakerphone: settings.autoEnableSpeakerphone,
          );
    _applyStartResult(result);
    if (!result.isSuccess) {
      SystemLogger.instance.log(
        LogCategory.recording,
        'Không thể bắt đầu giám sát: ${result.status.name}',
        level: LogLevel.error,
      );
    }
    return result.isSuccess;
  }

  void _applyStartResult(MonitoringStartResult result) {
    _updateState(
      (s) => s.copyWith(
        phase: result.isSuccess
            ? MonitoringPhase.active
            : MonitoringPhase.failed,
        monitoringErrorMessage: result.isSuccess
            ? null
            : (result.message ?? 'Không thể bắt đầu giám sát.'),
        clearMonitoringErrorMessage: result.isSuccess,
      ),
    );
  }

  void resetAttempt() {
    if (_startOperation == null) {
      _updateState((s) => s.copyWith(phase: MonitoringPhase.idle));
    }
  }

  void reset() {
    _startOperation = null;
  }
}
