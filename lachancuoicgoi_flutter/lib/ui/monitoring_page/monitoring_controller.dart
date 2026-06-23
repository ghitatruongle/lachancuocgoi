import 'dart:async' show Completer, Timer, unawaited;
import 'dart:convert' show jsonEncode;

import 'package:flutter/foundation.dart'
    show ChangeNotifier, debugPrint, visibleForTesting;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/analysis_coordinator.dart';
import '../../analysis/analysis_level.dart';
import '../../analysis/analysis_mode.dart';
import '../../analysis/analysis_mode_policy.dart';
import '../../analysis/analysis_providers.dart';
import '../../analysis/analysis_result.dart';
import '../../analysis/l1/l1_analysis.dart';
import '../../app/settings_controller.dart';
import '../../core/risk_level.dart';
import '../../data/app_database.dart';
import '../../data/call_history.dart';
import '../../data/session_recovery_store.dart';
import '../../services/developer_mode_manager.dart';
import '../../services/native_call_shield_bridge.dart';
import 'alert_manager.dart';
import 'analysis_orchestrator.dart';
import 'audio_amplitude_handler.dart';
import 'health_check_service.dart';
import 'monitoring_session_manager.dart';
import 'monitoring_simulation_helper.dart';
import 'monitoring_state.dart';
import 'monitoring_stream_handler.dart';

export 'monitoring_state.dart';

// ─── Provider ──────────────────────────────────────────────────────────

final monitoringControllerProvider =
    NotifierProvider<MonitoringController, MonitoringPageState>(
        MonitoringController.new);

// ─── Controller ────────────────────────────────────────────────────────

class MonitoringController extends Notifier<MonitoringPageState> {
  bool _initialized = false;
  bool _disposed = false;

  bool get disposed => _disposed;
  MonitoringPageState get currentState => state;

  // Coordinator — resolved lazily in initAfterFrame.
  AnalysisCoordinator? _coordinatorInstance;
  AnalysisCoordinator get coordinator => _coordinatorInstance!;

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

  // Navigation
  Timer? _timer;
  bool _endSessionInProgress = false;
  bool _stoppedEventReceived = false;
  Completer<void>? _stoppedCompleter;

  // Settings listener
  ProviderSubscription<SettingsState>? _settingsSub;
  String? phoneNumber;

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
      riskLevel: RiskLevel.green,
      peakRiskLevel: RiskLevel.green,
    );

    if (!hasTestAnalyzerOverride) {
      _settingsSub?.close();
      _settingsSub = ref.listen<SettingsState>(
        settingsControllerProvider,
        (previous, next) {
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
        },
      );
    }

    final initialTranscript = _simulatedTranscript?.trim() ?? '';
    final hasStructuredScript =
        _simulatedScriptLines != null && _simulatedScriptLines!.isNotEmpty;
    final isSimulation = hasStructuredScript ||
        initialTranscript.isNotEmpty ||
        (_simulatedScenarioTitle?.trim().isNotEmpty ?? false);

    if (isSimulation) {
      state = state.copyWith(isSimulationMode: true);
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
        );
      }
    }

    sessionManager.sessionStartEpochSeconds =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _startTimer();
    if (!hasTestAnalyzerOverride && !isSimulation) {
      _healthCheckService.start();
    }
    sessionManager.startSnapshotTimer();

	    if (initialTranscript.isNotEmpty &&
	        !hasTestAnalyzerOverride &&
	        !hasStructuredScript &&
	        _coordinatorInstance != null) {
	      _orch.scheduleRealTimeAnalysis(initialTranscript);
	    }
  }

  void initAfterFrame() {
    if (_disposed || hasTestAnalyzerOverride) return;
    _coordinatorInstance = ref.read(analysisCoordinatorProvider);

    // Create orchestrator now that coordinator is available.
    _ensureOrchestratorCreated();

    final hasStructuredScript =
        _simulatedScriptLines != null && _simulatedScriptLines!.isNotEmpty;
    if (!hasStructuredScript && !hasTestAnalyzerOverride) {
      streamHandler.initStreams();
    }

    if (!hasTestAnalyzerOverride) {
      unawaited(_recoverAndStartMonitoring());
    } else {
      unawaited(_startLiveMonitoringIfNeeded());
    }
  }

  void updateTranscriptFromSimulation(String newTranscript) {
    state = state.copyWith(transcript: newTranscript);
    _orch.scheduleRealTimeAnalysis(state.transcript);
  }

  void updateTranscriptFromStream(String newTranscript) {
    state = state.copyWith(transcript: newTranscript);
    _orch.scheduleRealTimeAnalysis(newTranscript);
  }

  void handleRmsEvent(double rms) => _audioHandler.handleRmsEvent(rms);

  void handleMonitoringStateEvent(
      (MonitoringState, int?, String?) stateData) {
    final monitoringState = stateData.$1;
    if (monitoringState == MonitoringState.networkAvailable ||
        monitoringState == MonitoringState.networkLost) {
      final isAvailable =
          monitoringState == MonitoringState.networkAvailable;
      final runtime = AnalysisModePolicy.createRuntimeState(
        state.selectedMode,
        isAvailable,
      );
      state = state.copyWith(
        networkAvailable: runtime.networkAvailable,
        effectiveMode: runtime.effectiveMode,
        isFallbackActive: runtime.isFallbackActive,
      );
    } else if (monitoringState == MonitoringState.sttFallbackVosk) {
      state = state.copyWith(
        isSttFallback: true,
        sttFallbackReason: stateData.$3,
        sttFallbackBannerId: state.sttFallbackBannerId + 1,
      );
    } else if (monitoringState == MonitoringState.stopped) {
      final finalTranscript = stateData.$3?.trim();
      if (finalTranscript != null && finalTranscript.isNotEmpty) {
        state = state.copyWith(transcript: finalTranscript);
      }
      _stoppedEventReceived = true;
      _stoppedCompleter?.complete();
      _stoppedCompleter = null;
      if (!state.isEndingSession && !_disposed) {
        endSession();
      }
    }
  }

  void onLifecycleChanged(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed && !state.isEndingSession) {
      if (!isSimulationSession() && !hasTestAnalyzerOverride) {
        unawaited(_startLiveMonitoringIfNeeded());
      }
    }
  }

  Future<void> endSession() async {
    if (_endSessionInProgress) return;
    _endSessionInProgress = true;

    if (!_stoppedEventReceived && !isSimulationSession()) {
      _stoppedCompleter = Completer<void>();
    }

    state = state.copyWith(isEndingSession: true);
    unawaited(SessionRecoveryStore.clear());
    try {
      final bridge = nativeBridge;
      if (_isCreatorMode) {
        await bridge.stopCreatorMonitoring();
      } else {
        await bridge.stopMonitoring();
      }

      if (_stoppedCompleter != null) {
        await _stoppedCompleter!.future.timeout(
          const Duration(milliseconds: 1000),
          onTimeout: () => null,
        );
      }

      if (_disposed) return;
      // Guard: orchestrator may not be ready if initAfterFrame wasn't called
      // (e.g. test with overridden analyzer). Proceed without analysis if so.
      if (_coordinatorInstance != null) {
        await _orch.ensureAnalysisComplete();
      }
      if (_disposed) return;

      final risk = state.peakRiskLevel.index > state.riskLevel.index
          ? state.peakRiskLevel
          : state.riskLevel;
      final result = state.analysisResult;
      final reason = result?.reason?.trim();
      final summaryParts = <String>[];
      if (isSimulationSession()) {
        summaryParts.add('[Mô phỏng]');
      }

      RecordingError? recordingError;
      if (state.transcript.trim().isEmpty) {
        recordingError = _audioHandler.hasReceivedAnyAudio
            ? RecordingError.sttFailed
            : RecordingError.noAudio;
      }
      if (recordingError == RecordingError.noAudio) {
        summaryParts.add(
            'Không thu được âm thanh — kiểm tra quyền micro hoặc nguồn âm thanh');
      } else if (recordingError == RecordingError.sttFailed) {
        summaryParts.add('Không nhận diện được giọng nói (STT không khả dụng)');
      } else if (reason != null && reason.isNotEmpty) {
        summaryParts.add(reason);
      } else {
        summaryParts.add(risk.vietnameseName);
      }
      final summary = summaryParts.join(' ');

      final flagCount = result?.matches.length ?? 0;
      final history = CallHistory.withRecordingError(
        dateTime: formatSessionDateTime(),
        riskLevel: risk.storageName,
        summary: summary,
        duration: formatElapsedTime(state.elapsedSeconds),
        flagCount: flagCount,
        transcript: state.transcript,
        audioPath: null,
        analysisResult:
            result != null ? jsonEncode(result.toJson()) : null,
        analysisType: state.effectiveMode.name,
        alertHistory: CallHistory.alertHistoryToJson(state.alertHistory),
        recordingError: recordingError,
      );

      final db = await appDatabase;
      if (_disposed) return;
      final id = await db.insert(history);
      if (_disposed) return;
      _endSessionInProgress = false;
      state = state.copyWith(
        navigationIntent: NavigateToResult(id),
      );
    } on Object catch (e, st) {
      debugPrint('End monitoring / save result failed: $e\n$st');
      _endSessionInProgress = false;
      if (!_disposed) {
        state = state.copyWith(
          isEndingSession: false,
          navigationIntent: const NavigateToHome(),
        );
      }
    }
  }

  void clearNavigationIntent() {
    state = state.copyWith(clearNavigationIntent: true);
  }

  void dismissSttFallbackBanner() {
    state =
        state.copyWith(isSttFallback: false, clearSttFallbackReason: true);
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  bool isSimulationSession() {
    final title = _simulatedScenarioTitle?.trim() ?? '';
    final script = _simulatedTranscript?.trim() ?? '';
    final hasStructured =
        _simulatedScriptLines != null && _simulatedScriptLines!.isNotEmpty;
    return hasStructured || title.isNotEmpty || script.isNotEmpty;
  }

  static String modeLabel(AnalysisMode mode) {
    return switch (mode) {
      AnalysisMode.normal => 'L1',
      AnalysisMode.gDetection => 'L2',
      AnalysisMode.geminiApi => 'L3',
      AnalysisMode.parallel => 'Parallel',
    };
  }

  String formatSessionDateTime() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)} '
        '${two(now.day)}/${two(now.month)}/${now.year}';
  }

  static String formatElapsedTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String formatElapsedTimeHelper(int seconds) => formatElapsedTime(seconds);

  /// Formats a [DateTime] as "HH:mm:ss DD/MM/YYYY".
  String formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)} '
        '${two(value.day)}/${two(value.month)}/${value.year}';
  }

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
    assert(_orchInstance != null,
        'AnalysisOrchestrator accessed before coordinator is ready');
    return _orchInstance!;
  }

  bool _hasAttemptedStart = false;

  bool get _isCreatorMode => state.isCreatorMode;

  Future<void> _recoverAndStartMonitoring() async {
    await sessionManager.recoverFromKillIfAny();
    if (_disposed) return;
    await _startLiveMonitoringIfNeeded();
  }

  Future<void> _startLiveMonitoringIfNeeded() async {
    if (isSimulationSession() || _hasAttemptedStart || _disposed ||
        hasTestAnalyzerOverride) {
      return;
    }
    _hasAttemptedStart = true;

    final bridge = nativeBridge;
    final settings = ref.read(settingsControllerProvider);
    final devMode = ref.read(developerModeProvider);

    final shouldUseCreatorMode =
        devMode.isActive && settings.creatorAudioCapture;

    if (shouldUseCreatorMode) {
      state = state.copyWith(isCreatorMode: true);
      final alreadyRunning = await bridge.isCreatorMonitoringActive();
      if (alreadyRunning) return;
      final started = await bridge.startCreatorMonitoring(
        devModeExpiresAtMs: devMode.expiresAtEpochMs,
      );
      if (started) return;
      state = state.copyWith(isCreatorMode: false);
    }

    final alreadyRunning = await bridge.isMonitoringActive();
    if (!alreadyRunning) {
      await bridge.startMonitoring(
        enableSpeakerphone: settings.autoEnableSpeakerphone,
      );
    }
  }

  Future<void> _runRestartSequence() async {
    if (_disposed) return;
    _hasAttemptedStart = false;
    await _startLiveMonitoringIfNeeded();
    if (!_disposed) streamHandler.initStreams();
  }

  void _onAnalysisResult(AnalysisResult result, AnalysisMode effectiveMode) {
    if (_disposed) return;
    if (state.isEndingSession) return;

    final resultLevel = result.analysisLevel;
    if (resultLevel == AnalysisLevel.l2 &&
        effectiveMode == AnalysisMode.geminiApi) {
      state = state.copyWith(
        effectiveMode: AnalysisMode.gDetection,
        isFallbackActive: true,
      );
    }

    final newPeak =
        result.overallRiskLevel.index > state.peakRiskLevel.index
            ? result.overallRiskLevel
            : state.peakRiskLevel;
    state = state.copyWith(
      analysisResult: result,
      riskLevel: result.overallRiskLevel,
      peakRiskLevel: newPeak,
      isAnalyzing: false,
    );

    if (result.alertEnabled) {
      _alertManager.processResult(result);
      _alertManager.triggerNativeAlert(result);
      // Sync alert history from AlertManager to state for persistence.
      state = state.copyWith(alertHistory: _alertManager.alertHistory);
    }
  }

  void _onAnalysisError(AnalysisResult fallback) {
    if (_disposed) return;
    state = state.copyWith(
      analysisResult: fallback,
      riskLevel: RiskLevel.green,
      isAnalyzing: false,
    );
  }

  void _startTimer() {
    if (hasTestAnalyzerOverride) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
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
    phoneNumber = null;
    _simulatedScenarioTitle = null;
    _simulatedTranscript = null;
    _simulatedScriptLines = null;
    _l1AnalyzerOverride = null;
	    _coordinatorInstance = null;
	    _orchInstance?.cancelDebounce();
	    _orchInstance = null;
    _hasAttemptedStart = false;
    _endSessionInProgress = false;
    _stoppedEventReceived = false;
    _stoppedCompleter = null;
    _audioHandler.reset();
    _alertManager.reset();
    state = const MonitoringPageState();
  }

  void _disposeInternal() {
    _disposed = true;
    _timer?.cancel();
    _healthCheckService.stop();
    sessionManager.stopSnapshotTimer();
    _orchInstance?.cancelDebounce();
    simulationHelper.stopSimulationPlayback();
    streamHandler.cancelStreams();
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
