import 'dart:async' show Completer, Timer, unawaited;
import 'dart:convert' show jsonEncode;
import 'dart:math';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint, visibleForTesting;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter/services.dart' show HapticFeedback;
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
import '../../data/alert_history_entry.dart';
import '../../data/app_database.dart';
import '../../data/call_history.dart';
import '../../data/session_recovery_store.dart';
import '../../services/developer_mode_manager.dart';
import '../../services/native_call_shield_bridge.dart';
import 'monitoring_state.dart';
import 'monitoring_session_manager.dart';
import 'monitoring_simulation_helper.dart';
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

  // Nullable — initialized in postFrameCallback to avoid blocking first frame.
  AnalysisCoordinator? _coordinatorInstance;
  AnalysisCoordinator get coordinator => _coordinatorInstance!;

  bool get hasTestAnalyzerOverride => _l1AnalyzerOverride != null;

  // Widget parameters
  String? _simulatedScenarioTitle;
  String? _simulatedTranscript;
  List<Map<String, dynamic>>? _simulatedScriptLines;
  L1Analyzer? _l1AnalyzerOverride;

  // Timers and helpers
  Timer? _timer;
  Timer? _analysisDebounce;
  String? _pendingReanalysisText;
  Timer? _healthCheckTimer;
  final Map<RiskLevel, int> _lastNativeAlertTime = {};
  Completer<void>? _analysisCompleter;
  int _analysisGeneration = 0;
  Completer<void>? _restartLock;
  int _healthCheckRetryCount = 0;

  // Helpers
  late final MonitoringSessionManager sessionManager;
  late final MonitoringSimulationHelper simulationHelper;
  late final MonitoringStreamHandler streamHandler;

  ProviderSubscription<SettingsState>? _settingsSub;
  String? phoneNumber;

  Completer<void>? _stoppedCompleter;
  bool _stoppedEventReceived = false;

  // Circular buffer for RMS amplitudes
  static const int amplitudeBufferSize = 30;
  final List<double> _amplitudes = List<double>.filled(amplitudeBufferSize, 0.1);
  int _amplitudeWriteIndex = 0;
  DateTime? _lastAmplitudeUpdate;
  double _peakAmplitude = 0.0;
  bool _hasReceivedAnyAudio = false;

  _WaveformNotifier? _waveformNotifier;

  /// Exposed for waveform widget & helpers.
  ChangeNotifier get waveformNotifier => _waveformNotifier!;
  List<double> get amplitudes => _amplitudes;
  int get amplitudeWriteIndex => _amplitudeWriteIndex;

  // Backward compatibility getters
  List<double> get currentAmplitudes => _amplitudes;
  int get currentAmplitudeWriteIndex => _amplitudeWriteIndex;

  NativeBridgeInterface get nativeBridge => ref.read(nativeBridgeProvider);
  Future<AppDatabase> get appDatabase => ref.read(appDatabaseFutureProvider.future);

  @override
  MonitoringPageState build() {
    _waveformNotifier ??= _WaveformNotifier();
    sessionManager = MonitoringSessionManager(this);
    simulationHelper = MonitoringSimulationHelper(this);
    streamHandler = MonitoringStreamHandler(this);

    ref.onDispose(() {
      _disposeInternal();
    });
    return const MonitoringPageState();
  }

  void notifyWaveform() {
    _waveformNotifier?.notify();
  }

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
    final hasStructuredScript = _simulatedScriptLines != null &&
        _simulatedScriptLines!.isNotEmpty;
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
    _startHealthCheckTimer();
    sessionManager.startSnapshotTimer();

    if (initialTranscript.isNotEmpty &&
        !hasTestAnalyzerOverride &&
        !hasStructuredScript) {
      _analysisDebounce = Timer(const Duration(milliseconds: 1), () {
        unawaited(_ensureAnalysisComplete());
      });
    }
  }

  void _resetForNewSession() {
    _timer?.cancel();
    _healthCheckTimer?.cancel();
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
    _hasAttemptedStart = false;
    _endSessionInProgress = false;
    _analysisCompleter = null;
    _pendingReanalysisText = null;
    for (var i = 0; i < amplitudeBufferSize; i++) {
      _amplitudes[i] = 0.1;
    }
    _amplitudeWriteIndex = 0;
    _lastAmplitudeUpdate = null;
    _peakAmplitude = 0.0;
    _hasReceivedAnyAudio = false;
    _stoppedEventReceived = false;
    _stoppedCompleter = null;
    state = const MonitoringPageState();
  }

  void initAfterFrame() {
    if (_disposed || hasTestAnalyzerOverride) return;
    _coordinatorInstance = ref.read(analysisCoordinatorProvider);

    final hasStructuredScript = _simulatedScriptLines != null &&
        _simulatedScriptLines!.isNotEmpty;
    if (!hasStructuredScript && !hasTestAnalyzerOverride) {
      streamHandler.initStreams();
    }

    if (!hasTestAnalyzerOverride) {
      unawaited(_recoverAndStartMonitoring());
    } else {
      unawaited(_startLiveMonitoringIfNeeded());
    }
  }

  Future<void> _recoverAndStartMonitoring() async {
    await sessionManager.recoverFromKillIfAny();
    if (_disposed) return;
    await _startLiveMonitoringIfNeeded();
  }

  void _disposeInternal() {
    _disposed = true;
    _timer?.cancel();
    _healthCheckTimer?.cancel();
    sessionManager.stopSnapshotTimer();
    _analysisDebounce?.cancel();
    simulationHelper.stopSimulationPlayback();
    streamHandler.cancelStreams();
    _settingsSub?.close();
    _settingsSub = null;
    _waveformNotifier?.dispose();
  }

  void _startTimer() {
    if (hasTestAnalyzerOverride) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  static String formatElapsedTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String formatElapsedTimeHelper(int seconds) => formatElapsedTime(seconds);

  String formatDateTime(DateTime value) => _formatDateTime(value);

  static String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)} '
        '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  bool isSimulationSession() {
    final title = _simulatedScenarioTitle?.trim() ?? '';
    final script = _simulatedTranscript?.trim() ?? '';
    final hasStructured = _simulatedScriptLines != null &&
        _simulatedScriptLines!.isNotEmpty;
    return hasStructured || title.isNotEmpty || script.isNotEmpty;
  }

  bool _hasAttemptedStart = false;

  Future<void> _startLiveMonitoringIfNeeded() async {
    if (isSimulationSession() || _hasAttemptedStart || _disposed || hasTestAnalyzerOverride) return;
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

  void _startHealthCheckTimer() {
    if (hasTestAnalyzerOverride || isSimulationSession()) return;
    _healthCheckTimer?.cancel();
    _healthCheckRetryCount = 0;
    _scheduleHealthCheck(const Duration(seconds: 60));
  }

  void _scheduleHealthCheck(Duration interval) {
    if (_disposed) return;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer(interval, () async {
      if (_disposed || state.isEndingSession) return;
      final bridge = nativeBridge;
      final running = state.isCreatorMode
          ? await bridge.isCreatorMonitoringActive()
          : await bridge.isMonitoringActive();
      if (_disposed) return;
      if (running) {
        if (_healthCheckRetryCount > 0) {
          debugPrint('Health check recovered after $_healthCheckRetryCount retries.');
          _healthCheckRetryCount = 0;
        }
        _scheduleHealthCheck(const Duration(seconds: 60));
        return;
      }
      _healthCheckRetryCount++;
      if (_healthCheckRetryCount == 1) {
        debugPrint('Health check: service not running — auto-restarting...');
        state = state.copyWith(
          transcript: '${state.transcript}\n[Hệ thống giám sát đã được khôi phục]',
        );
        _analysisCompleter = null;
        _hasAttemptedStart = false;
        await _runRestartSequence();
      } else {
        debugPrint('Health check: backoff attempt $_healthCheckRetryCount (still down)');
      }
      final nextIntervalSec = (60 * (1 << (_healthCheckRetryCount - 1))).clamp(60, 300);
      _scheduleHealthCheck(Duration(seconds: nextIntervalSec));
    });
  }

  Future<void> _runRestartSequence() async {
    if (_disposed) return;
    final existing = _restartLock;
    if (existing != null) {
      await existing.future;
      return;
    }
    final completer = Completer<void>();
    _restartLock = completer;
    try {
      await _startLiveMonitoringIfNeeded();
      if (!_disposed) streamHandler.initStreams();
    } finally {
      _restartLock = null;
      completer.complete();
    }
  }

  void onLifecycleChanged(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed && !state.isEndingSession) {
      if (!isSimulationSession() && !hasTestAnalyzerOverride) {
        unawaited(_runRestartSequence());
      }
    }
  }

  void updateTranscriptFromSimulation(String newTranscript) {
    state = state.copyWith(transcript: newTranscript);
    _analysisCompleter = null;
    _runRealTimeAnalysis(state.transcript);
  }

  void updateTranscriptFromStream(String newTranscript) {
    state = state.copyWith(transcript: newTranscript);
    _analysisCompleter = null;
    _runRealTimeAnalysis(newTranscript);
  }

  void handleRmsEvent(double rms) {
    final now = DateTime.now();
    if (_lastAmplitudeUpdate != null &&
        now.difference(_lastAmplitudeUpdate!).inMilliseconds < 100) {
      return;
    }
    _lastAmplitudeUpdate = now;
    if (rms > _peakAmplitude) _peakAmplitude = rms;
    _hasReceivedAnyAudio = true;
    final normalized = ((rms + 2.0) / 12.0).clamp(0.0, 1.0);
    _amplitudes[_amplitudeWriteIndex] = max(0.1, normalized);
    _amplitudeWriteIndex = (_amplitudeWriteIndex + 1) % amplitudeBufferSize;
    _waveformNotifier?.notify();
  }

  void handleMonitoringStateEvent((MonitoringState, int?, String?) stateData) {
    final monitoringState = stateData.$1;
    if (monitoringState == MonitoringState.networkAvailable ||
        monitoringState == MonitoringState.networkLost) {
      final isAvailable = monitoringState == MonitoringState.networkAvailable;
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
        _analysisCompleter = null;
      }
      _stoppedEventReceived = true;
      _stoppedCompleter?.complete();
      _stoppedCompleter = null;
      if (!state.isEndingSession && !_disposed) {
        endSession();
      }
    }
  }

  Future<void> _ensureAnalysisComplete() async {
    if (state.transcript.trim().isEmpty) return;
    if (_coordinatorInstance == null) return;
    _analysisDebounce?.cancel();

    final existing = _analysisCompleter;
    if (existing != null && !existing.isCompleted) {
      try {
        await existing.future;
      } on Exception {
        // Swallow
      }
      return;
    }
    final completer = Completer<void>();
    _analysisCompleter = completer;
    try {
      await _runAnalysis();
      if (!completer.isCompleted) completer.complete();
    } catch (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    } finally {
      if (identical(_analysisCompleter, completer)) {
        _analysisCompleter = null;
      }
    }
  }

  bool _endSessionInProgress = false;

  @visibleForTesting
  void debugSetAudioState({
    required double peakAmplitude,
    required bool hasReceivedAnyAudio,
  }) {
    _peakAmplitude = peakAmplitude;
    _hasReceivedAnyAudio = hasReceivedAnyAudio;
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
      if (state.isCreatorMode) {
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
      await _ensureAnalysisComplete();
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
        recordingError =
            _hasReceivedAnyAudio ? RecordingError.sttFailed : RecordingError.noAudio;
      }
      if (recordingError == RecordingError.noAudio) {
        summaryParts.add('Không thu được âm thanh — kiểm tra quyền micro hoặc nguồn âm thanh');
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
        analysisResult: result != null ? jsonEncode(result.toJson()) : null,
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
    state = state.copyWith(isSttFallback: false, clearSttFallbackReason: true);
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

  Future<void> _runAnalysis() async {
    final myGeneration = ++_analysisGeneration;
    state = state.copyWith(isAnalyzing: true);
    try {
      final result =
          await coordinator.analyze(state.transcript, state.effectiveMode);
      if (_disposed) return;
      if (myGeneration != _analysisGeneration) return;
      final newPeak = result.overallRiskLevel.index > state.peakRiskLevel.index
          ? result.overallRiskLevel
          : state.peakRiskLevel;
      state = state.copyWith(
        analysisResult: result,
        riskLevel: result.overallRiskLevel,
        peakRiskLevel: newPeak,
        isAnalyzing: false,
      );
    } on Object catch (e) {
      debugPrint('_runAnalysis failed: $e');
      if (_disposed) return;
      if (myGeneration != _analysisGeneration) return;
      state = state.copyWith(
        analysisResult: const AnalysisResult(
          overallRiskLevel: RiskLevel.green,
          matches: [],
          reason: 'Lỗi khi chạy phân tích trên kịch bản mô phỏng.',
          analysisLevel: AnalysisLevel.l1,
          alertEnabled: false,
          isError: true,
        ),
        riskLevel: RiskLevel.green,
        isAnalyzing: false,
      );
    }
  }

  void _runRealTimeAnalysis(String text) {
    if (_coordinatorInstance == null) return;
    _analysisDebounce?.cancel();
    _analysisDebounce = Timer(const Duration(milliseconds: 1200), () async {
      final textForRun = text;
      if (_disposed || textForRun.trim().isEmpty || state.isEndingSession) return;
      if (state.isAnalyzing) {
        _pendingReanalysisText = textForRun;
        return;
      }
      _pendingReanalysisText = null;
      final myGeneration = ++_analysisGeneration;
      state = state.copyWith(isAnalyzing: true);
      try {
        final AnalysisResult result =
            await coordinator.analyzeIncremental(textForRun, state.effectiveMode);
        if (_disposed) return;
        if (myGeneration != _analysisGeneration) return;
        if (state.isEndingSession) return;

        final resultLevel = result.analysisLevel;
        if (resultLevel == AnalysisLevel.l2 &&
            state.effectiveMode == AnalysisMode.geminiApi) {
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
          isAnalyzing: false,
        );

        if (result.alertEnabled) {
          _updateAlertHistory(result);
          final level = result.overallRiskLevel;
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final lastTime = _lastNativeAlertTime[level];
          const suppressionWindowMs = 15000;
          if (lastTime == null || (nowMs - lastTime) >= suppressionWindowMs) {
            _lastNativeAlertTime[level] = nowMs;
            final bridge = nativeBridge;
             if (level == RiskLevel.red) {
              unawaited(HapticFeedback.heavyImpact());
              unawaited(bridge.showRedAlert(result.reason ?? 'Cảnh báo lừa đảo!'));
            } else if (level == RiskLevel.orange) {
              unawaited(HapticFeedback.vibrate());
              unawaited(bridge.showOrangeAlert(result.reason ?? 'Nội dung đáng ngờ!'));
            }
          }
        }

        final pendingText = _pendingReanalysisText;
        _pendingReanalysisText = null;
        if (pendingText != null && !state.isEndingSession) {
          _runRealTimeAnalysis(pendingText);
        }
      } on Object catch (e) {
        debugPrint('_runRealTimeAnalysis failed: $e');
        if (!_disposed) {
          state = state.copyWith(isAnalyzing: false);
        }
        final pendingText = _pendingReanalysisText;
        _pendingReanalysisText = null;
        if (pendingText != null && !_disposed && !state.isEndingSession) {
          _runRealTimeAnalysis(pendingText);
        }
      }
    });
  }

  void _updateAlertHistory(AnalysisResult result) {
    if (!result.alertEnabled) return;

    const int maxAlerts = 100;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final riskLevel = result.overallRiskLevel.storageName;
    final reason = result.reason ?? 'Cảnh báo rủi ro';

    final currentHistory = List<AlertHistoryEntry>.from(state.alertHistory);

    if (currentHistory.isNotEmpty) {
      final last = currentHistory.last;
      if (last.riskLevel == riskLevel && (timestamp - last.timestamp) < 10000) {
        final allReasons = List<String>.from(last.allReasons ?? []);
        if (!allReasons.contains(reason)) {
          allReasons.add(reason);
        }

        currentHistory[currentHistory.length - 1] = AlertHistoryEntry(
          timestamp: last.timestamp,
          analysisLevel: result.analysisLevel.id,
          riskLevel: riskLevel,
          alertCount: last.alertCount + 1,
          displayedReason: reason,
          allReasons: allReasons,
        );
        state = state.copyWith(alertHistory: currentHistory);
        return;
      }
    }

    currentHistory.add(AlertHistoryEntry(
      timestamp: timestamp,
      analysisLevel: result.analysisLevel.id,
      riskLevel: riskLevel,
      alertCount: 1,
      displayedReason: reason,
      allReasons: [reason],
    ));
    if (currentHistory.length > maxAlerts) {
      currentHistory.removeRange(0, currentHistory.length - maxAlerts);
    }
    state = state.copyWith(alertHistory: currentHistory);
  }
}

class _WaveformNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
