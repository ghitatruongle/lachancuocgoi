import 'dart:async' show Timer, unawaited;

import 'package:flutter/foundation.dart' show ChangeNotifier, visibleForTesting;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/system_logger.dart';

import '../../analysis/analysis_coordinator.dart';
import '../../analysis/analysis_level.dart';
import '../../analysis/analysis_mode.dart';
import '../../analysis/analysis_mode_policy.dart';
import '../../analysis/analysis_providers.dart';
import '../../analysis/analysis_result.dart';
import '../../analysis/l1/l1_analysis.dart';
import '../../app/settings_controller.dart';
import '../../core/analysis_availability.dart';
import '../../core/risk_level.dart';
import '../../data/app_database.dart';
import '../../services/developer_mode_manager.dart';
import '../../services/native_call_shield_bridge.dart';
import 'alert_manager.dart';
import 'analysis_orchestrator.dart';
import 'audio_amplitude_handler.dart';
import 'health_check_service.dart';
import 'monitoring_event_router.dart';
import 'monitoring_formatters.dart' as formatters;
import 'monitoring_session_manager.dart';
import 'monitoring_simulation_helper.dart';
import 'monitoring_starter.dart';
import 'monitoring_state.dart';
import 'monitoring_stream_handler.dart';
import 'session_ender.dart';

export 'monitoring_state.dart';

// ─── Provider ──────────────────────────────────────────────────────────

final monitoringControllerProvider =
    NotifierProvider<MonitoringController, MonitoringPageState>(
      MonitoringController.new,
    );

// ─── Controller ────────────────────────────────────────────────────────

class MonitoringController extends Notifier<MonitoringPageState> {
  bool _initialized = false;
  bool _disposed = false;

  bool get disposed => _disposed;
  MonitoringPageState get currentState => state;

  // Coordinator — resolved lazily in initAfterFrame.
  AnalysisCoordinator? _coordinatorInstance;
  AnalysisCoordinator get coordinator {
    final instance = _coordinatorInstance;
    if (instance == null) {
      throw StateError(
        'MonitoringController.coordinator accessed before initAfterFrame(). '
        'Ensure initAfterFrame() has completed before reading coordinator.',
      );
    }
    return instance;
  }

  bool get hasTestAnalyzerOverride => _l1AnalyzerOverride != null;

  // Widget parameters
  String? _simulatedScenarioTitle;
  String? _simulatedTranscript;
  List<Map<String, dynamic>>? _simulatedScriptLines;
  L1Analyzer? _l1AnalyzerOverride;

  // Sub-services (delegated responsibilities)
  late final AudioAmplitudeHandler _audioHandler;
  AnalysisOrchestrator? _orchInstance;
  late final AlertManager _alertManager;
  late final HealthCheckService _healthCheckService;
  late final MonitoringSessionManager sessionManager;
  late final MonitoringSimulationHelper simulationHelper;
  late final MonitoringStreamHandler streamHandler;

  // Extracted sub-services
  late final SessionEnder _sessionEnder;
  late final MonitoringStarter _starter;
  late final MonitoringEventRouter _eventRouter;

  // Navigation
  Timer? _timer;

  // Settings listener
  ProviderSubscription<SettingsState>? _settingsSub;

  /// Privacy-safe caller identifier received from the native bridge.
  String? maskedNumber;

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  MonitoringPageState build() {
    _audioHandler = AudioAmplitudeHandler();
    _alertManager = AlertManager(
      getBridge: () => ref.read(nativeBridgeProvider),
    );
    _healthCheckService = HealthCheckService(
      getBridge: () => ref.read(nativeBridgeProvider),
      isCreatorMode: () => _isCreatorMode,
      onServiceDown: () {
        if (!_disposed) {
          state = state.copyWith(
            transcript:
                '${state.transcript}\n[Hệ thống giám sát đã được khôi phục]',
          );
        }
      },
      onRestart: () => _runRestartSequence(),
    );

    // Initialize extracted sub-services
    _sessionEnder = SessionEnder(
      getBridge: () => ref.read(nativeBridgeProvider),
      getDatabase: () => ref.read(appDatabaseFutureProvider.future),
      audioHandler: _audioHandler,
      cleanupAfterSave: (database) async {
        final retention = ref
            .read(settingsControllerProvider)
            .callHistoryRetention;
        await ref
            .read(callHistoryRetentionServiceProvider)
            .cleanup(database, retention);
      },
    );
    _starter = MonitoringStarter(
      getBridge: () => ref.read(nativeBridgeProvider),
      getSettings: () => ref.read(settingsControllerProvider),
      getDevMode: () => ref.read(developerModeProvider),
      isSimulationSession: isSimulationSession,
      hasTestAnalyzerOverride: () => hasTestAnalyzerOverride,
      getState: () => state,
      updateState: (updater) {
        if (!_disposed) state = updater(state);
      },
    );
    _eventRouter = MonitoringEventRouter(
      updateState: (updater) {
        if (!_disposed) state = updater(state);
      },
      getState: () => state,
      onStoppedEvent: () {
        _sessionEnder.onStoppedEvent();
      },
      endSession: () => endSession(),
      onNetworkChanged: (available) {
        _coordinatorInstance?.setNetworkAvailable(available);
      },
    );

    sessionManager = MonitoringSessionManager(this);
    simulationHelper = MonitoringSimulationHelper(this);
    streamHandler = MonitoringStreamHandler(this);

    // Analysis orchestrator is created lazily after coordinator is available
    // (see initAfterFrame).

    ref.onDispose(() {
      _disposeInternal();
    });
    return const MonitoringPageState();
  }

  // ─── Public API ────────────────────────────────────────────────────

  AudioAmplitudeHandler get audioHandler => _audioHandler;
  AnalysisOrchestrator get analysisOrchestrator => _orch;
  AlertManager get alertManager => _alertManager;
  HealthCheckService get healthCheckService => _healthCheckService;

  // Backward-compatible getters for existing callers
  ChangeNotifier get waveformNotifier => _audioHandler.waveformNotifier;
  List<double> get currentAmplitudes => _audioHandler.amplitudes;
  int get currentAmplitudeWriteIndex => _audioHandler.writeIndex;

  NativeBridgeInterface get nativeBridge => ref.read(nativeBridgeProvider);
  Future<AppDatabase> get appDatabase =>
      ref.read(appDatabaseFutureProvider.future);

  /// Initialize the controller with widget parameters.
  void init({
    String? simulatedScenarioTitle,
    String? simulatedTranscript,
    List<Map<String, dynamic>>? simulatedScriptLines,
    L1Analyzer? l1AnalyzerOverride,
  }) {
    SystemLogger.instance.clear();
    SystemLogger.instance.log(
      LogCategory.system,
      'Khởi động phiên giám sát cuộc gọi mới...',
    );
    if (_initialized) {
      _resetForNewSession();
    }
    _initialized = true;
    _disposed = false;

    _l1AnalyzerOverride = l1AnalyzerOverride;
    _simulatedScenarioTitle = simulatedScenarioTitle;
    _simulatedTranscript = simulatedTranscript;
    _simulatedScriptLines = simulatedScriptLines;

    final selectedMode = hasTestAnalyzerOverride
        ? AnalysisMode.normal
        : ref.read(settingsControllerProvider).analysisMode;

    final initialRuntime = AnalysisModePolicy.createRuntimeState(
      selectedMode,
      state.networkAvailable,
    );
    state = state.copyWith(
      selectedMode: initialRuntime.selectedMode,
      effectiveMode: initialRuntime.effectiveMode,
      isFallbackActive: initialRuntime.isFallbackActive,
      phase: MonitoringPhase.idle,
      availability: AnalysisAvailability.pending,
      clearMonitoringErrorMessage: true,
      riskLevel: RiskLevel.green,
      peakRiskLevel: RiskLevel.green,
    );

    if (!hasTestAnalyzerOverride) {
      _settingsSub?.close();
      _settingsSub = ref.listen<SettingsState>(settingsControllerProvider, (
        previous,
        next,
      ) {
        if (_disposed) return;
        final runtime = AnalysisModePolicy.createRuntimeState(
          next.analysisMode,
          state.networkAvailable,
        );
        state = state.copyWith(
          selectedMode: runtime.selectedMode,
          effectiveMode: runtime.effectiveMode,
          isFallbackActive: runtime.isFallbackActive,
        );
      });
    }

    final initialTranscript = _simulatedTranscript?.trim() ?? '';
    final hasStructuredScript =
        _simulatedScriptLines != null && _simulatedScriptLines!.isNotEmpty;
    final isSimulation =
        hasStructuredScript ||
        initialTranscript.isNotEmpty ||
        (_simulatedScenarioTitle?.trim().isNotEmpty ?? false);

    if (isSimulation) {
      state = state.copyWith(
        isSimulationMode: true,
        phase: MonitoringPhase.active,
      );
    } else if (hasTestAnalyzerOverride) {
      state = state.copyWith(phase: MonitoringPhase.active);
    }

    if (hasStructuredScript) {
      simulationHelper.startSimulationPlayback(_simulatedScriptLines!);
    } else if (initialTranscript.isNotEmpty) {
      state = state.copyWith(transcript: initialTranscript);
      if (hasTestAnalyzerOverride) {
        state = state.copyWith(
          analysisResult: const AnalysisResult(
            overallRiskLevel: RiskLevel.red,
            matches: <KeywordMatch>[
              KeywordMatch(
                keyword: 'OTP',
                level: RiskLevel.red,
                category: 'Test',
              ),
            ],
            reason: 'OTP',
            analysisLevel: AnalysisLevel.l1,
            alertEnabled: true,
          ),
          riskLevel: RiskLevel.red,
          peakRiskLevel: RiskLevel.red,
          availability: AnalysisAvailability.sufficient,
        );
      }
    }

    sessionManager.sessionStartEpochSeconds =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _startTimer();
    sessionManager.startSnapshotTimer();

    if (initialTranscript.isNotEmpty &&
        !hasTestAnalyzerOverride &&
        !hasStructuredScript &&
        _coordinatorInstance != null) {
      _orch.scheduleRealTimeAnalysis(initialTranscript);
    }
  }

  void initAfterFrame({bool nativeMonitoringAlreadyStarted = false}) {
    if (_disposed || hasTestAnalyzerOverride) return;
    _coordinatorInstance = ref.read(analysisCoordinatorProvider);
    _coordinatorInstance?.setNetworkAvailable(state.networkAvailable);

    // Create orchestrator now that coordinator is available.
    _ensureOrchestratorCreated();

    final hasStructuredScript =
        _simulatedScriptLines != null && _simulatedScriptLines!.isNotEmpty;
    if (!hasStructuredScript && !hasTestAnalyzerOverride) {
      streamHandler.initStreams();
    }

    if (nativeMonitoringAlreadyStarted) {
      state = state.copyWith(
        phase: MonitoringPhase.active,
        clearMonitoringErrorMessage: true,
      );
      _healthCheckService.start();
    } else if (!hasTestAnalyzerOverride) {
      unawaited(_recoverAndStartMonitoring());
    } else {
      unawaited(_startLiveMonitoringIfNeeded());
    }
  }

  void updateTranscriptFromSimulation(String newTranscript) {
    _updateSpeechRate(newTranscript);
    state = state.copyWith(
      transcript: newTranscript,
      availability: AnalysisAvailability.pending,
    );
    _orch.scheduleRealTimeAnalysis(state.transcript);
  }

  void updateTranscriptFromStream(String newTranscript) {
    _updateSpeechRate(newTranscript);
    state = state.copyWith(
      transcript: newTranscript,
      availability: AnalysisAvailability.pending,
    );
    _orch.scheduleRealTimeAnalysis(newTranscript);
  }

  DateTime? _lastSpeechSampleAt;
  int _lastSpeechLength = 0;

  void _updateSpeechRate(String newTranscript) {
    final now = DateTime.now();
    final prevAt = _lastSpeechSampleAt;
    final prevLen = _lastSpeechLength;
    _lastSpeechSampleAt = now;
    _lastSpeechLength = newTranscript.length;
    if (prevAt == null || prevLen <= 0) return;
    final elapsedSec = now.difference(prevAt).inMilliseconds / 1000.0;
    if (elapsedSec <= 0.05) return;
    final deltaChars = (newTranscript.length - prevLen).clamp(0, 10000);
    final rate = deltaChars / elapsedSec;
    _coordinatorInstance?.setSpeechRate(rate);
  }

  void handleRmsEvent(double rms) => _audioHandler.handleRmsEvent(rms);

  void handleMonitoringStateEvent((MonitoringState, int?, String?) stateData) {
    _eventRouter.handleMonitoringStateEvent(stateData);
  }

  void onLifecycleChanged(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed &&
        state.phase != MonitoringPhase.stopping &&
        state.phase != MonitoringPhase.saved) {
      if (!isSimulationSession() && !hasTestAnalyzerOverride) {
        unawaited(_startLiveMonitoringIfNeeded());
      }
    }
  }

  Future<void> endSession() async {
    if (state.phase == MonitoringPhase.stopping ||
        state.phase == MonitoringPhase.saved) {
      return;
    }
    final availability = _availabilityAtSessionEnd();
    state = state.copyWith(
      phase: MonitoringPhase.stopping,
      availability: availability,
      clearMonitoringErrorMessage: true,
    );
    _timer?.cancel();
    sessionManager.stopSnapshotTimer();
    final intent = await _sessionEnder.endSession(
      getState: () => state,
      isCreatorMode: _isCreatorMode,
      isSimulationSession: isSimulationSession(),
      isDisposed: _disposed,
      getAnalysisResult: () => state.analysisResult,
      getAlertHistory: () => state.alertHistory,
      getOrchestrator: () => _orchInstance,
      hasCoordinator: () => _coordinatorInstance != null,
    );
    if (intent != null && !_disposed) {
      state = state.copyWith(
        phase: intent is NavigateToResult
            ? MonitoringPhase.saved
            : MonitoringPhase.failed,
        navigationIntent: intent,
      );
    } else if (!_disposed) {
      state = state.copyWith(
        phase: MonitoringPhase.failed,
        monitoringErrorMessage: 'Không thể lưu kết quả giám sát.',
      );
    }
  }

  AnalysisAvailability _availabilityAtSessionEnd() {
    if (state.transcript.trim().isEmpty) {
      if (state.isSttUnavailable || _audioHandler.hasReceivedAnyAudio) {
        return AnalysisAvailability.sttUnavailable;
      }
      return AnalysisAvailability.noAudio;
    }
    final result = state.analysisResult;
    if (result == null || result.isError) {
      return AnalysisAvailability.interrupted;
    }
    return AnalysisAvailability.sufficient;
  }

  void clearNavigationIntent() {
    state = state.copyWith(clearNavigationIntent: true);
  }

  void dismissSttFallbackBanner() {
    state = state.copyWith(isSttFallback: false, clearSttFallbackReason: true);
  }

  void dismissSttUnavailableBanner() {
    state = state.copyWith(
      isSttUnavailable: false,
      clearSttUnavailableReason: true,
    );
  }

  void dismissDegradedNotificationBanner() {
    state = state.copyWith(isDegradedNoNotification: false);
  }

  void dismissWatchdogBanner() {
    state = state.copyWith(isWatchdogRestartFailed: false);
  }

  void dismissMonitoringError() {
    state = state.copyWith(clearMonitoringErrorMessage: true);
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  bool isSimulationSession() {
    final title = _simulatedScenarioTitle?.trim() ?? '';
    final script = _simulatedTranscript?.trim() ?? '';
    final hasStructured =
        _simulatedScriptLines != null && _simulatedScriptLines!.isNotEmpty;
    return hasStructured || title.isNotEmpty || script.isNotEmpty;
  }

  // Backward-compatible static/instance methods delegating to formatters.
  static String modeLabel(AnalysisMode mode) => formatters.modeLabel(mode);
  String formatSessionDateTime() => formatters.formatSessionDateTime();
  static String formatElapsedTime(int seconds) =>
      formatters.formatElapsedTime(seconds);
  String formatElapsedTimeHelper(int seconds) =>
      formatters.formatElapsedTime(seconds);
  String formatDateTime(DateTime value) => formatters.formatDateTime(value);

  // ─── Private ────────────────────────────────────────────────────────

  void _ensureOrchestratorCreated() {
    if (_orchInstance != null) return;
    if (_coordinatorInstance == null) return; // coordinator not ready yet
    _orchInstance = AnalysisOrchestrator(
      coordinator: coordinator,
      getEffectiveMode: () => state.effectiveMode,
      getTranscript: () => state.transcript,
      onResult: _onAnalysisResult,
      onError: _onAnalysisError,
    );
  }

  AnalysisOrchestrator get _orch {
    _ensureOrchestratorCreated();
    // Should not happen in normal flow, but guard against it.
    assert(
      _orchInstance != null,
      'AnalysisOrchestrator accessed before coordinator is ready',
    );
    return _orchInstance!;
  }

  bool get _isCreatorMode => state.isCreatorMode;

  Future<void> _recoverAndStartMonitoring() async {
    await sessionManager.recoverFromKillIfAny();
    if (_disposed) return;
    await _startLiveMonitoringIfNeeded();
  }

  Future<void> _startLiveMonitoringIfNeeded() async {
    final started = await _starter.startLiveMonitoringIfNeeded(
      isDisposed: _disposed,
    );
    if (_disposed) return;
    if (started && !isSimulationSession() && !hasTestAnalyzerOverride) {
      _healthCheckService.start();
    } else if (!started) {
      _healthCheckService.stop();
    }
  }

  Future<void> _runRestartSequence() async {
    if (_disposed) return;
    _starter.resetAttempt();
    await _startLiveMonitoringIfNeeded();
    if (!_disposed) streamHandler.initStreams();
  }

  void _onAnalysisResult(AnalysisResult result, AnalysisMode effectiveMode) {
    if (_disposed) return;
    if (state.phase == MonitoringPhase.stopping ||
        state.phase == MonitoringPhase.saved) {
      return;
    }

    final resultLevel = result.analysisLevel;
    if (resultLevel == AnalysisLevel.l2 &&
        effectiveMode == AnalysisMode.geminiApi) {
      state = state.copyWith(
        effectiveMode: AnalysisMode.gDetection,
        isFallbackActive: true,
      );
    }

    final newPeak = result.overallRiskLevel.index > state.peakRiskLevel.index
        ? result.overallRiskLevel
        : state.peakRiskLevel;
    state = state.copyWith(
      analysisResult: result,
      riskLevel: result.overallRiskLevel,
      peakRiskLevel: newPeak,
      availability: state.transcript.trim().isEmpty
          ? AnalysisAvailability.pending
          : (result.isError
                ? AnalysisAvailability.interrupted
                : AnalysisAvailability.sufficient),
      isAnalyzing: false,
    );

    // Phase 2 (P2-7): trigger haptic for ALL risk levels (including yellow),
    // not just alertEnabled. The AlertManager internally gates haptics by
    // risk level and reduceMotion.
    _alertManager.triggerNativeAlert(result);

    if (result.alertEnabled) {
      _alertManager.processResult(result);
      // Sync alert history from AlertManager to state for persistence.
      state = state.copyWith(alertHistory: _alertManager.alertHistory);
    }
  }

  void _onAnalysisError(AnalysisResult fallback) {
    if (_disposed) return;
    state = state.copyWith(
      analysisResult: fallback,
      riskLevel: RiskLevel.green,
      availability: state.transcript.trim().isEmpty
          ? AnalysisAvailability.pending
          : AnalysisAvailability.interrupted,
      isAnalyzing: false,
    );
  }

  void _startTimer() {
    if (hasTestAnalyzerOverride) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      if (state.phase != MonitoringPhase.active) return;
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void _resetForNewSession() {
    _timer?.cancel();
    _healthCheckService.stop();
    sessionManager.stopSnapshotTimer();
    sessionManager.recoveryAttempted = false;
    sessionManager.sessionStartEpochSeconds = 0;
    simulationHelper.stopSimulationPlayback();
    simulationHelper.currentScriptLineIndex = 0;
    streamHandler.cancelStreams();
    streamHandler.streamsDead = false;
    _settingsSub?.close();
    _settingsSub = null;
    maskedNumber = null;
    _simulatedScenarioTitle = null;
    _simulatedTranscript = null;
    _simulatedScriptLines = null;
    _l1AnalyzerOverride = null;
    // Reset singleton analyzer state (L1/L2/L3 + WFSA + GDetection) so stale
    // scores from the previous call/simulation don't leak into the new session.
    _coordinatorInstance?.reset();
    _coordinatorInstance = null;
    _orchInstance?.dispose();
    _orchInstance = null;
    _starter.reset();
    _sessionEnder.reset();
    _audioHandler.reset();
    _alertManager.reset();
    state = const MonitoringPageState();
  }

  void _disposeInternal() {
    _disposed = true;
    _timer?.cancel();
    _healthCheckService.stop();
    sessionManager.stopSnapshotTimer();
    _orchInstance?.dispose();
    _audioHandler.dispose();
    simulationHelper.stopSimulationPlayback();
    streamHandler.cancelStreams();
    // Bug #44 fix: null out _disposed marker BEFORE closing _settingsSub
    // so any in-flight settings listener callback (Riverpod may invoke
    // callbacks synchronously on close) sees _disposed=true and bails
    // out instead of trying to update state on a disposed controller.
    _settingsSub?.close();
    _settingsSub = null;
  }

  @visibleForTesting
  void debugSetAudioState({
    required double peakAmplitude,
    required bool hasReceivedAnyAudio,
  }) {
    _audioHandler.debugSetAudioState(
      peakAmplitude: peakAmplitude,
      hasReceivedAnyAudio: hasReceivedAnyAudio,
    );
  }
}
