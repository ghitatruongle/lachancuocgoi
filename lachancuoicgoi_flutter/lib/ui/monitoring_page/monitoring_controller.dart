import 'dart:async' show Completer, StreamSubscription, Timer, unawaited;
import 'dart:convert' show jsonEncode;
import 'dart:math';

import 'package:flutter/foundation.dart' show ChangeNotifier, ValueListenable, debugPrint;
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
import '../../data/alert_history_entry.dart';
import '../../data/app_database.dart';
import '../../data/call_history.dart';
import '../../data/session_recovery_store.dart';
import '../../services/developer_mode_manager.dart';
import '../../services/native_call_shield_bridge.dart';
import 'monitoring_state.dart';

export 'monitoring_state.dart';

// ─── Provider ──────────────────────────────────────────────────────────

final monitoringControllerProvider =
    NotifierProvider<MonitoringController, MonitoringPageState>(
        MonitoringController.new);

// ─── Controller ────────────────────────────────────────────────────────

class MonitoringController extends Notifier<MonitoringPageState> {
  bool _initialized = false;
  bool _disposed = false;

  // Nullable — initialized in postFrameCallback to avoid blocking first frame.
  AnalysisCoordinator? _coordinatorInstance;
  AnalysisCoordinator get _coordinator => _coordinatorInstance!;


  bool get _hasTestAnalyzerOverride => _l1AnalyzerOverride != null;

  // Widget parameters
  String? _simulatedScenarioTitle;
  String? _simulatedTranscript;
  List<Map<String, dynamic>>? _simulatedScriptLines;
  L1Analyzer? _l1AnalyzerOverride;

  // Timers and subscriptions
  Timer? _timer;
  Timer? _analysisDebounce;
  String? _pendingReanalysisText;
  Timer? _healthCheckTimer;
  Timer? _simulationPlaybackTimer;
  Timer? _snapshotTimer;
  // Alert suppression: track last native alert timestamp per risk level.
  // Suppress duplicate native alerts (same level) within 15 seconds.
  final Map<RiskLevel, int> _lastNativeAlertTime = {};
  int _currentScriptLineIndex = 0;
  // Fixed seed for reproducible simulation waveforms.
  final Random _simRandom = Random(42);
  Future<void>? _l1AnalysisFuture;
  // Sprint 2 (C4): consecutive-failed health-check counter. Reset to 0
  // when monitoring is healthy. Backs off and eventually stops hammering
  // when the service is clearly not coming back.
  int _healthCheckRetryCount = 0;
  // Sprint 2 (B5): monotonic counter that drives snapshot timer cadence
  // and helps debug stale snapshots during recovery.
  int _sessionStartEpochSeconds = 0;

  StreamSubscription<TranscriptUpdate>? _transcriptSub;
  StreamSubscription<double>? _rmsSub;
  StreamSubscription<(MonitoringState, int?, String?)>? _stateSub;
  StreamSubscription<CallEvent>? _callEventSub;
  // Sprint 2: phone number captured from native callEventStream.
  String? _phoneNumber;
  // Sprint 2 (C4): set when any of the bridge subscriptions emits
  // a `done` event (e.g. the EventChannel detached). _initStreams()
  // checks this to know when it is safe to re-subscribe instead of
  // being blocked by the "already subscribed" guard.
  bool _streamsDead = false;
  Completer<void>? _stoppedCompleter;
  bool _stoppedEventReceived = false;

  // Circular buffer for RMS amplitudes
  static const int _amplitudeBufferSize = 30;
  final List<double> _amplitudes = List<double>.filled(_amplitudeBufferSize, 0.1);
  int _amplitudeWriteIndex = 0;
  DateTime? _lastAmplitudeUpdate;
  // Bug #2 fix: track peak amplitude from rmsStream directly instead of
  // reading state.amplitudes (which is always [] — waveform bypasses state
  // via _AmplitudesNotifier to avoid excessive Riverpod rebuilds).
  double _peakAmplitude = 0.0;
  _AmplitudesNotifier? _amplitudesNotifier;

  /// Exposed for waveform widget — uses ChangeNotifier for high-frequency updates.
  ValueListenable<List<double>> get amplitudesListenable => _amplitudesNotifier!;

  @override
  MonitoringPageState build() {
    _amplitudesNotifier ??= _AmplitudesNotifier(List.from(_amplitudes));
    ref.onDispose(() {
      _disposeInternal();
    });
    return const MonitoringPageState();
  }

  /// Initialize the controller with widget parameters.
  /// Called from MonitoringPage.initState(). Handles re-initialization
  /// by resetting all state from previous sessions.
  void init({
    String? simulatedScenarioTitle,
    String? simulatedTranscript,
    List<Map<String, dynamic>>? simulatedScriptLines,
    L1Analyzer? l1AnalyzerOverride,
  }) {
    // If re-initializing (e.g. simulation → real monitoring), tear down old state first.
    if (_initialized) {
      _resetForNewSession();
    }
    _initialized = true;
    _disposed = false;

    _l1AnalyzerOverride = l1AnalyzerOverride; // Set FIRST — before any _hasTestAnalyzerOverride check
    _simulatedScenarioTitle = simulatedScenarioTitle;
    _simulatedTranscript = simulatedTranscript;
    _simulatedScriptLines = simulatedScriptLines;

    final selectedMode = _hasTestAnalyzerOverride
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
    );

    if (!_hasTestAnalyzerOverride) {
      ref.listen<SettingsState>(
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
      _startSimulationPlayback(_simulatedScriptLines!);
    } else if (initialTranscript.isNotEmpty) {
      state = state.copyWith(transcript: initialTranscript);
      if (_hasTestAnalyzerOverride) {
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
        );
      }
    }

    _sessionStartEpochSeconds =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _startTimer();
    _startHealthCheckTimer();
    _startSnapshotTimer();
    if (initialTranscript.isNotEmpty &&
        !_hasTestAnalyzerOverride &&
        !hasStructuredScript) {
      _analysisDebounce = Timer(const Duration(milliseconds: 1), () {
        unawaited(_ensureAnalysisComplete());
      });
    }
  }

  /// Reset all internal state for a fresh session.
  /// Called when the MonitoringPage is re-entered (e.g. simulation → real).
  void _resetForNewSession() {
    _timer?.cancel();
    _healthCheckTimer?.cancel();
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    _healthCheckRetryCount = 0;
    _streamsDead = false;
    _analysisDebounce?.cancel();
    _simulationPlaybackTimer?.cancel();
    _transcriptSub?.cancel();
    _transcriptSub = null;
    _rmsSub?.cancel();
    _rmsSub = null;
    _stateSub?.cancel();
    _stateSub = null;
    _callEventSub?.cancel();
    _callEventSub = null;
    _phoneNumber = null;
    _simulatedScenarioTitle = null;
    _simulatedTranscript = null;
    _simulatedScriptLines = null;
    _l1AnalyzerOverride = null;
    _coordinatorInstance = null;
    _hasAttemptedStart = false;
    _endSessionInProgress = false;
    _l1AnalysisFuture = null;
    _pendingReanalysisText = null;
    _currentScriptLineIndex = 0;
    for (var i = 0; i < _amplitudeBufferSize; i++) {
      _amplitudes[i] = 0.1;
    }
    _amplitudeWriteIndex = 0;
    _lastAmplitudeUpdate = null;
    _peakAmplitude = 0.0;
    _stoppedEventReceived = false;
    _stoppedCompleter = null;
    state = const MonitoringPageState();
  }

  /// Deferred initialization — call from addPostFrameCallback.
  void initAfterFrame() {
    if (_disposed || _hasTestAnalyzerOverride) return;
    _coordinatorInstance = ref.read(analysisCoordinatorProvider);

    final hasStructuredScript = _simulatedScriptLines != null &&
        _simulatedScriptLines!.isNotEmpty;
    if (!hasStructuredScript && !_hasTestAnalyzerOverride) _initStreams();

    if (!_hasTestAnalyzerOverride) {
      unawaited(_recoverAndStartMonitoring());
    } else {
      unawaited(_startLiveMonitoringIfNeeded());
    }
  }

  Future<void> _recoverAndStartMonitoring() async {
    await _recoverFromKillIfAny();
    if (_disposed) return;
    await _startLiveMonitoringIfNeeded();
  }

  void _disposeInternal() {
    _disposed = true;
    _timer?.cancel();
    _healthCheckTimer?.cancel();
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    _analysisDebounce?.cancel();
    _simulationPlaybackTimer?.cancel();
    _transcriptSub?.cancel();
    _transcriptSub = null;
    _rmsSub?.cancel();
    _rmsSub = null;
    _stateSub?.cancel();
    _stateSub = null;
    _callEventSub?.cancel();
    _callEventSub = null;
    _amplitudesNotifier?.dispose();
  }

  // ── Timer ────────────────────────────────────────────────────────────

  void _startTimer() {
    if (_hasTestAnalyzerOverride) return;
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

  // ── Streams ──────────────────────────────────────────────────────────

  void _initStreams() {
    if (_isSimulationSession()) return;

    // Guard: if subscriptions are alive, skip recreation. This prevents
    // unnecessary cancel+recreate on every app resume.
    //
    // Sprint 2 (C4): the guard also allows re-subscription when the
    // previous subscriptions are dead (e.g. the EventChannel was torn
    // down after the app was backgrounded and the OS reclaimed the
    // isolate). [_streamsDead] is set by the `onDone` callbacks below.
    if (!_streamsDead &&
        (_transcriptSub != null || _rmsSub != null || _stateSub != null || _callEventSub != null)) {
      return;
    }
    _streamsDead = false;

    final bridge = ref.read(nativeBridgeProvider);

    _transcriptSub = bridge.transcriptStream.listen(
      (update) {
        if (_disposed) return;
        state = state.copyWith(transcript: update.text);
        _l1AnalysisFuture = null;
        _runRealTimeAnalysis(update.text);
      },
      onDone: () {
        if (_disposed) return;
        debugPrint('transcriptStream done — marking subscriptions dead.');
        _streamsDead = true;
      },
      onError: (Object e, StackTrace st) {
        debugPrint('transcriptStream error: $e');
      },
    );

    // RMS stream with optimized circular buffer
    _rmsSub = bridge.rmsStream.listen(
      (rms) {
        if (_disposed) return;
        final now = DateTime.now();
        if (_lastAmplitudeUpdate != null &&
            now.difference(_lastAmplitudeUpdate!).inMilliseconds < 100) {
          return;
        }
        _lastAmplitudeUpdate = now;
        // Bug #2 fix: record peak amplitude for noAudio vs sttFailed detection.
        if (rms > _peakAmplitude) _peakAmplitude = rms;
        _amplitudes[_amplitudeWriteIndex] = max(0.1, rms);
        // Build ordered list BEFORE incrementing write index — avoids
        // the new value being shifted to the end of the waveform.
        final ordered = List<double>.filled(_amplitudeBufferSize, 0.0);
        for (var i = 0; i < _amplitudeBufferSize; i++) {
          ordered[i] =
              _amplitudes[(_amplitudeWriteIndex + i) % _amplitudeBufferSize];
        }
        _amplitudeWriteIndex =
            (_amplitudeWriteIndex + 1) % _amplitudeBufferSize;
        _amplitudesNotifier!.updateAndNotify(ordered);
      },
      onDone: () {
        if (_disposed) return;
        debugPrint('rmsStream done — marking subscriptions dead.');
        _streamsDead = true;
      },
      onError: (Object e, StackTrace st) {
        debugPrint('rmsStream error: $e');
      },
    );

    _stateSub = bridge.monitoringStateStream.listen(
      (stateData) {
        if (_disposed) return;
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
          // Sprint 2 (C1): the native side reported it switched to the
          // Vosk fallback. Surface this as a banner flag in state so the
          // UI can render a "STT đã chuyển sang chế độ offline" notice.
          state = state.copyWith(
            isSttFallback: true,
            sttFallbackReason: stateData.$3,
            sttFallbackBannerId: state.sttFallbackBannerId + 1,
          );
                } else if (monitoringState == MonitoringState.stopped) {
          final finalTranscript = stateData.$3?.trim();
          if (finalTranscript != null && finalTranscript.isNotEmpty) {
            state = state.copyWith(transcript: finalTranscript);
            _l1AnalysisFuture = null;
          }
          _stoppedEventReceived = true;
          _stoppedCompleter?.complete();
          _stoppedCompleter = null;
          if (!state.isEndingSession && !_disposed) {
            endSession();
          }
        }
      },
      onDone: () {
        if (_disposed) return;
        debugPrint('monitoringStateStream done — marking subscriptions dead.');
        _streamsDead = true;
      },
      onError: (Object e, StackTrace st) {
        debugPrint('monitoringStateStream error: $e');
      },
    );

    // Capture phone number from native call events.
    _callEventSub = bridge.callEventStream.listen(
      (event) {
        if (_disposed) return;
        if (event.phoneNumber != null && event.phoneNumber!.isNotEmpty) {
          _phoneNumber = event.phoneNumber;
        }
      },
      onDone: () {
        if (_disposed) return;
        debugPrint('callEventStream done — marking subscriptions dead.');
        _streamsDead = true;
      },
      onError: (Object e, StackTrace st) {
        debugPrint('callEventStream error: $e');
      },
    );
  }

  // ── Health Check ─────────────────────────────────────────────────────

  void _startHealthCheckTimer() {
    if (_hasTestAnalyzerOverride || _isSimulationSession()) return;
    _healthCheckTimer?.cancel();
    _healthCheckRetryCount = 0;
    _scheduleHealthCheck(const Duration(seconds: 60));
  }

  /// Schedule a single health check. Reschedules itself after each check.
  /// Backs off to longer intervals after repeated failures but never stops.
  void _scheduleHealthCheck(Duration interval) {
    if (_disposed) return;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer(interval, () async {
      if (_disposed || state.isEndingSession) return;
      final bridge = ref.read(nativeBridgeProvider);
      final running = state.isCreatorMode
          ? await bridge.isCreatorMonitoringActive()
          : await bridge.isMonitoringActive();
      if (_disposed) return;
      if (running) {
        // Healthy — clear retry counter, next check in 60s.
        if (_healthCheckRetryCount > 0) {
          debugPrint(
              'Health check recovered after $_healthCheckRetryCount retries.');
          _healthCheckRetryCount = 0;
        }
        _scheduleHealthCheck(const Duration(seconds: 60));
        return;
      }
      // Not running. Backoff so we don't spam the bridge.
      _healthCheckRetryCount++;
      if (_healthCheckRetryCount == 1) {
        debugPrint('Health check: service not running — auto-restarting...');
        state = state.copyWith(
          transcript:
              '${state.transcript}\n[Hệ thống giám sát đã được khôi phục]',
        );
        _l1AnalysisFuture = null;
        _hasAttemptedStart = false;
        await _startLiveMonitoringIfNeeded();
        if (!_disposed) _initStreams();
      } else {
        debugPrint(
            'Health check: backoff attempt $_healthCheckRetryCount (still down)');
      }
      // Back off: 60s → 120s → 240s → cap at 300s (5 min).
      // Never stops permanently — always schedules the next check.
      final nextIntervalSec = (60 * (1 << (_healthCheckRetryCount - 1))).clamp(60, 300);
      _scheduleHealthCheck(Duration(seconds: nextIntervalSec));
    });
  }

  // ── Session Recovery (B5) ────────────────────────────────────────────

  /// Persist a snapshot of the live session every 5s so that an OS kill
  /// can be recovered on next app start.
  void _startSnapshotTimer() {
    if (_hasTestAnalyzerOverride || _isSimulationSession()) return;
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _saveSnapshot(),
    );
  }

  void _saveSnapshot() {
    if (_disposed || state.isEndingSession) return;
    if (state.isSimulationMode) return;
    if (state.transcript.trim().isEmpty && state.elapsedSeconds < 5) return;
    unawaited(
      SessionRecoveryStore.save(
        SessionSnapshot(
          phoneNumber: _phoneNumber ?? '',
          transcript: state.transcript,
          elapsedSeconds: state.elapsedSeconds,
          riskLevel: state.riskLevel.storageName,
          analysisResultJson: null,
          recordingError: null,
          startedAt:
              DateTime.fromMillisecondsSinceEpoch(_sessionStartEpochSeconds * 1000),
        ),
      ),
    );
  }

  /// On first build, look for a snapshot from a previous, killed
  /// session. If fresh (< 30min) and the service isn't running, write
  /// the snapshot to `CallHistory` with `recordingError = 'killed'`
  /// and clear the snapshot.
  Future<void> _recoverFromKillIfAny() async {
    if (_hasTestAnalyzerOverride) return;
    final snapshot = await SessionRecoveryStore.load();
    if (snapshot == null) return;
    final age = DateTime.now().difference(snapshot.startedAt);
    if (age >= SessionRecoveryStore.maxAge) {
      await SessionRecoveryStore.clear();
      return;
    }
    // Don't recover if a fresh monitoring service is already running.
    try {
      final bridge = ref.read(nativeBridgeProvider);
      if (await bridge.isMonitoringActive()) {
        await SessionRecoveryStore.clear();
        return;
      }
    } on Exception {
      // If the bridge call fails, fall through and try to recover.
    }

    try {
      final db = await ref.read(appDatabaseFutureProvider.future);
      if (_disposed) return;
      final history = CallHistory(
        dateTime: MonitoringController._formatDateTime(
          snapshot.startedAt,
        ),
        riskLevel: snapshot.riskLevel ?? RiskLevel.green.storageName,
        summary: 'Phiên bản giám sát bị hệ thống dừng đột ngột',
        duration: MonitoringController.formatElapsedTime(
          snapshot.elapsedSeconds,
        ),
        flagCount: 0,
        transcript: snapshot.transcript,
        audioPath: null,
        analysisType: state.effectiveMode.name,
        // Sprint 2 (B5): new recordingError value. Indicates that
        // endSession() never ran because the app was killed.
        recordingError: 'killed',
      );
      await db.insert(history);
    } catch (e) {
      debugPrint('Session recovery failed: $e');
    } finally {
      await SessionRecoveryStore.clear();
    }
  }

  static String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)} '
        '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  // ── Lifecycle ────────────────────────────────────────────────────────

  void onLifecycleChanged(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed && !state.isEndingSession) {
      if (!_isSimulationSession() && !_hasTestAnalyzerOverride) {
        _initStreams();
        unawaited(_startLiveMonitoringIfNeeded());
      }
    }
  }

  // ── Simulation ───────────────────────────────────────────────────────

  bool _isSimulationSession() {
    final title = _simulatedScenarioTitle?.trim() ?? '';
    final script = _simulatedTranscript?.trim() ?? '';
    final hasStructured = _simulatedScriptLines != null &&
        _simulatedScriptLines!.isNotEmpty;
    return hasStructured || title.isNotEmpty || script.isNotEmpty;
  }

  void _startSimulationPlayback(List<Map<String, dynamic>> scriptLines) {
    _currentScriptLineIndex = 0;
    _simulationPlaybackTimer?.cancel();

    void scheduleNext() {
      if (_currentScriptLineIndex >= scriptLines.length || _disposed) return;

      final line = scriptLines[_currentScriptLineIndex];
      final delay = (line['delay'] as num?)?.toInt() ?? 2000;
      final speaker = line['speaker'] as String? ?? '';
      final text = line['line'] as String? ?? '';

      _simulationPlaybackTimer = Timer(
        Duration(milliseconds: max(delay, 100)),
        () {
          if (_disposed) return;
          final current = state.transcript;
          final lineText = '$speaker: $text';
          state = state.copyWith(
            transcript: current.isEmpty ? lineText : '$current\n$lineText',
          );
          _l1AnalysisFuture = null;
          _updateSimulationWaveform();
          _runRealTimeAnalysis(state.transcript);
          _currentScriptLineIndex++;
          scheduleNext();
        },
      );
    }

    scheduleNext();
  }

  void _updateSimulationWaveform() {
    for (var i = 0; i < _amplitudeBufferSize; i++) {
      _amplitudes[i] = _simRandom.nextDouble() * 0.6 + 0.2;
    }
    _amplitudesNotifier!.updateAndNotify(List.from(_amplitudes));
  }

  // ── Live Monitoring ──────────────────────────────────────────────────

  bool _hasAttemptedStart = false;

  Future<void> _startLiveMonitoringIfNeeded() async {
    if (_isSimulationSession() || _hasAttemptedStart || _disposed || _hasTestAnalyzerOverride) return;
    _hasAttemptedStart = true;

    final bridge = ref.read(nativeBridgeProvider);
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

  // ── Analysis ─────────────────────────────────────────────────────────

  String formatSessionDateTime() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)} '
        '${two(now.day)}/${two(now.month)}/${now.year}';
  }

  Future<void> _ensureAnalysisComplete() async {
    if (state.transcript.trim().isEmpty) return;
    if (_coordinatorInstance == null) return;
    // Bug #1 fix: cancel any pending debounce timer so it cannot fire
    // concurrently and overwrite state after endSession has started.
    _analysisDebounce?.cancel();
    // Bug #3 fix: capture the future into a local variable BEFORE awaiting.
    // If a concurrent transcript event nulls _l1AnalysisFuture between the
    // ??= assignment and the await, awaiting null would skip the final
    // analysis entirely. Capturing the reference avoids that race.
    final analysisToAwait = _l1AnalysisFuture ??= _runAnalysis();
    await analysisToAwait;
  }

  bool _endSessionInProgress = false;

  /// End the current monitoring session.
  Future<void> endSession() async {
    if (_endSessionInProgress) return;
    _endSessionInProgress = true;

    if (!_stoppedEventReceived && !_isSimulationSession()) {
      _stoppedCompleter = Completer<void>();
    }

    state = state.copyWith(isEndingSession: true);
    // Sprint 2 (B5): the session ended cleanly — discard any pending
    // snapshot so a future app start doesn't re-recover this row.
    unawaited(SessionRecoveryStore.clear());
    try {
      final bridge = ref.read(nativeBridgeProvider);
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

      final risk = state.riskLevel;
      final result = state.analysisResult;
      final reason = result?.reason?.trim();
      final summaryParts = <String>[];
      if (_isSimulationSession()) {
        summaryParts.add('[Mô phỏng]');
      }
      // Sprint 1 (A7): if the transcript is empty, mark why so the history
      // card can show a meaningful reason instead of a blank GREEN row.
      String? recordingError;
      if (state.transcript.trim().isEmpty) {
        final maxStateAmp = state.amplitudes.isNotEmpty ? state.amplitudes.reduce(max) : 0.0;
        final maxAmp = max(_peakAmplitude, maxStateAmp);
        recordingError = maxAmp < 0.5 ? 'noAudio' : 'sttFailed';
      }
      if (recordingError == 'noAudio') {
        summaryParts
            .add('Không thu được âm thanh — kiểm tra quyền micro hoặc nguồn âm thanh');
      } else if (recordingError == 'sttFailed') {
        summaryParts.add('Không nhận diện được giọng nói (STT không khả dụng)');
      } else if (reason != null && reason.isNotEmpty) {
        summaryParts.add(reason);
      } else {
        summaryParts.add(risk.vietnameseName);
      }
      final summary = summaryParts.join(' ');

      final flagCount = result?.matches.length ?? 0;
      final history = CallHistory(
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

      final db = await ref.read(appDatabaseFutureProvider.future);
      if (_disposed) return;
      final id = await db.insert(history);
      if (_disposed) return;
      _endSessionInProgress = false; // Reset flag now that the session is saved.
      state = state.copyWith(
        navigationIntent: NavigateToResult(id),
      );
    } catch (e, st) {
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

  /// Clear the navigation intent after the page has handled it.
  void clearNavigationIntent() {
    state = state.copyWith(clearNavigationIntent: true);
  }

  /// Dismiss the STT fallback banner.
  void dismissSttFallbackBanner() {
    // Bug #9 fix: use clearSttFallbackReason to actually null the old reason.
    state = state.copyWith(isSttFallback: false, clearSttFallbackReason: true);
  }

  static String modeLabel(AnalysisMode mode) {
    return switch (mode) {
      AnalysisMode.normal => 'L1',
      AnalysisMode.gDetection => 'L2',
      AnalysisMode.geminiApi => 'L3',
    };
  }

  Future<void> _runAnalysis() async {
    state = state.copyWith(isAnalyzing: true);
    try {
      final result =
          await _coordinator.analyze(state.transcript, state.effectiveMode);
      if (_disposed) return;
      state = state.copyWith(
        analysisResult: result,
        riskLevel: result.overallRiskLevel,
        isAnalyzing: false,
      );
    } catch (e) {
      debugPrint('_runAnalysis failed: $e');
      if (_disposed) return;
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
      // Use the latest transcript from state, not the captured closure
      // variable which may be stale after 1200ms debounce.
      final latestText = state.transcript;
      if (_disposed || latestText.trim().isEmpty) return;
      if (state.isAnalyzing) {
        // Save latest text for retry after current analysis completes.
        _pendingReanalysisText = latestText;
        return;
      }
      _pendingReanalysisText = null;
      state = state.copyWith(isAnalyzing: true);
      try {
        AnalysisResult result =
            await _coordinator.analyzeIncremental(latestText, state.effectiveMode);
        if (_disposed) return;

        final resultLevel = result.analysisLevel;
        // Dual fallback: AnalysisCoordinator internally falls back from
        // L3→L2 when Gemini is unavailable (network/API error). This
        // Dart-side code mirrors that by updating effectiveMode so the
        // UI shows the correct mode badge and avoids re-triggering L3
        // on the next incremental call.
        if (resultLevel == AnalysisLevel.l2 &&
            state.effectiveMode == AnalysisMode.geminiApi) {
          state = state.copyWith(
            effectiveMode: AnalysisMode.gDetection,
            isFallbackActive: true,
          );
        }

        state = state.copyWith(
          analysisResult: result,
          riskLevel: result.overallRiskLevel,
          isAnalyzing: false,
        );

        if (result.alertEnabled) {
          _updateAlertHistory(result);
          // Suppress duplicate native alerts: only show if same level not shown in last 15s.
          final level = result.overallRiskLevel;
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final lastTime = _lastNativeAlertTime[level];
          const suppressionWindowMs = 15000; // 15 seconds
          if (lastTime == null || (nowMs - lastTime) >= suppressionWindowMs) {
            _lastNativeAlertTime[level] = nowMs;
            final bridge = ref.read(nativeBridgeProvider);
            if (level == RiskLevel.red) {
              unawaited(
                bridge.showRedAlert(result.reason ?? 'Cảnh báo lừa đảo!'),
              );
            } else if (level == RiskLevel.orange) {
              unawaited(
                bridge.showOrangeAlert(
                    result.reason ?? 'Nội dung đáng ngờ!'),
              );
            }
          }
        }

        // If a newer transcript arrived while we were analyzing, re-run.
        final pendingText = _pendingReanalysisText;
        _pendingReanalysisText = null;
        if (pendingText != null) {
          _runRealTimeAnalysis(pendingText);
        }
      } catch (e) {
        debugPrint('_runRealTimeAnalysis failed: $e');
        if (!_disposed) {
          state = state.copyWith(isAnalyzing: false);
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

    // Check if we should merge with last alert or create new
    if (currentHistory.isNotEmpty) {
      final last = currentHistory.last;
      // If same level and close in time (within 10s), merge or update
      if (last.riskLevel == riskLevel && 
          (timestamp - last.timestamp) < 10000) {
        
        final allReasons = List<String>.from(last.allReasons ?? []);
        if (!allReasons.contains(reason)) {
          allReasons.add(reason);
        }

        currentHistory[currentHistory.length - 1] = AlertHistoryEntry(
          timestamp: last.timestamp, // Keep original timestamp
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

    // Add new entry, capped at maxAlerts
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

/// ChangeNotifier that always notifies on [notifyListeners] — unlike
/// [ValueNotifier] which skips when the same reference is assigned.
/// Used for the amplitude list where in-place mutation + forced rebuild
/// avoids creating a new List every 100ms.
class _AmplitudesNotifier extends ChangeNotifier
    implements ValueListenable<List<double>> {
  _AmplitudesNotifier(this._amplitudes);

  List<double> _amplitudes;

  List<double> get amplitudes => _amplitudes;

  /// Update the amplitudes list and notify listeners.
  void updateAndNotify(List<double> newAmplitudes) {
    _amplitudes = newAmplitudes;
    notifyListeners();
  }

  @override
  List<double> get value => _amplitudes;
}
