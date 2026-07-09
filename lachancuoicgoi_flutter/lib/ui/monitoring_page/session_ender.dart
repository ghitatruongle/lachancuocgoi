import 'dart:async' show Completer;
import 'dart:convert' show jsonEncode;

import '../../analysis/analysis_result.dart';
import '../../core/system_logger.dart';
import '../../data/alert_history_entry.dart';
import '../../data/app_database.dart';
import '../../data/call_history.dart';
import '../../services/native_call_shield_bridge.dart';
import 'analysis_orchestrator.dart';
import 'audio_amplitude_handler.dart';
import 'monitoring_formatters.dart';
import 'monitoring_state.dart';

// ─── Session Ender ──────────────────────────────────────────────────────
//
// Handles end-of-session logic: stops native monitoring, waits for the
// stopped event, runs final analysis, persists the result to the database,
// and emits a [NavigationIntent].
//
// Extracted from [MonitoringController] to reduce class size.

class SessionEnder {
  SessionEnder({
    required NativeBridgeInterface Function() getBridge,
    required Future<AppDatabase> Function() getDatabase,
    required AudioAmplitudeHandler audioHandler,
  })  : _getBridge = getBridge,
        _getDb = getDatabase,
        _audioHandler = audioHandler;

  final NativeBridgeInterface Function() _getBridge;
  final Future<AppDatabase> Function() _getDb;
  final AudioAmplitudeHandler _audioHandler;

  bool _endSessionInProgress = false;
  bool _stoppedEventReceived = false;
  Completer<void>? _stoppedCompleter;

  bool get endSessionInProgress => _endSessionInProgress;
  bool get stoppedEventReceived => _stoppedEventReceived;

  /// Called when a [MonitoringState.stopped] event arrives from native.
  void onStoppedEvent() {
    _stoppedEventReceived = true;
    _stoppedCompleter?.complete();
    _stoppedCompleter = null;
  }

  /// Ensures the stopped completer is created if we haven't received the
  /// stopped event yet (for non-simulation sessions).
  void prepareForStop({required bool isSimulationSession}) {
    if (!_stoppedEventReceived && !isSimulationSession) {
      _stoppedCompleter = Completer<void>();
    }
  }

  /// Ends the monitoring session, persists the result, and returns a
  /// [NavigationIntent] (either [NavigateToResult] or [NavigateToHome]).
  Future<NavigationIntent?> endSession({
    required MonitoringPageState state,
    required bool isCreatorMode,
    required bool isSimulationSession,
    required bool isDisposed,
    required AnalysisResult? Function() getAnalysisResult,
    required List<AlertHistoryEntry> Function() getAlertHistory,
    required AnalysisOrchestrator? Function() getOrchestrator,
    required bool Function() hasCoordinator,
  }) async {
    if (_endSessionInProgress) return null;
    _endSessionInProgress = true;

    SystemLogger.instance.log(
      LogCategory.system,
      'Yêu cầu kết thúc cuộc gọi và lưu kết quả...',
    );

    prepareForStop(isSimulationSession: isSimulationSession);

    try {
      final bridge = _getBridge();
      if (isCreatorMode) {
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

      if (isDisposed) return null;

      // Guard: orchestrator may not be ready if initAfterFrame wasn't called
      // (e.g. test with overridden analyzer). Proceed without analysis if so.
      final orch = getOrchestrator();
      if (hasCoordinator() && orch != null) {
        await orch.ensureAnalysisComplete();
      }
      if (isDisposed) return null;

      final risk = state.peakRiskLevel.index > state.riskLevel.index
          ? state.peakRiskLevel
          : state.riskLevel;
      final result = getAnalysisResult();
      final reason = result?.reason?.trim();
      final summaryParts = <String>[];
      if (isSimulationSession) {
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
          'Không thu được âm thanh — kiểm tra quyền micro hoặc nguồn âm thanh',
        );
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
        alertHistory: CallHistory.alertHistoryToJson(getAlertHistory()),
        recordingError: recordingError,
      );

      final db = await _getDb();
      if (isDisposed) return null;
      final id = await db.insert(history);
      if (isDisposed) return null;
      _endSessionInProgress = false;
      return NavigateToResult(id);
    } on Object catch (e) {
      SystemLogger.instance.log(LogCategory.system, 'End monitoring / save result failed: $e', level: LogLevel.error);
      _endSessionInProgress = false;
      if (!isDisposed) {
        return const NavigateToHome();
      }
      return null;
    }
  }

  /// Resets all state for a new session.
  void reset() {
    _endSessionInProgress = false;
    _stoppedEventReceived = false;
    _stoppedCompleter = null;
  }
}
