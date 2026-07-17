import 'dart:async';
import '../../core/risk_level.dart';
import '../../core/system_logger.dart';
import '../../data/call_history.dart';
import '../../data/session_recovery_store.dart';
import 'monitoring_controller.dart';

class MonitoringSessionManager {
  MonitoringSessionManager(this.controller);

  final MonitoringController controller;
  Timer? _snapshotTimer;
  int sessionStartEpochSeconds = 0;
  bool recoveryAttempted = false;

  void startSnapshotTimer() {
    if (controller.hasTestAnalyzerOverride ||
        controller.isSimulationSession()) {
      return;
    }
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => saveSnapshot(),
    );
  }

  void stopSnapshotTimer() {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
  }

  void saveSnapshot() {
    if (controller.disposed || controller.currentState.isEndingSession) return;
    if (controller.currentState.isSimulationMode) return;
    // Bug #40 fix: if there is no transcript AND no elapsed time, skip —
    // nothing meaningful to recover. The previous code skipped only when
    // transcript-empty AND elapsed < 5s, so after 5s of silence it would
    // save an empty snapshot every 5s. The recovery code then sees
    // transcript="" and saves a CallHistory with that empty transcript,
    // which the UI displays as a blank row in History.
    final state = controller.currentState;
    if (state.transcript.trim().isEmpty && state.elapsedSeconds < 10) {
      return;
    }
    // Also skip if the user just hasn't spoken yet but monitoring is
    // genuinely running — we still want the snapshot, but only if there
    // is SOME signal (RMS, partial). Without any signal there's nothing
    // useful to recover. Use audioHandler.hasReceivedAnyAudio instead of
    // state.peakAmplitude (which doesn't exist on MonitoringPageState).
    if (state.transcript.trim().isEmpty && !controller.audioHandler.hasReceivedAnyAudio) {
      return;
    }

    unawaited(
      SessionRecoveryStore.save(
        SessionSnapshot(
          phoneNumber: controller.phoneNumber ?? '',
          transcript: state.transcript,
          elapsedSeconds: state.elapsedSeconds,
          riskLevel: state.riskLevel.storageName,
          analysisResultJson: null,
          recordingError: null,
          startedAt: DateTime.fromMillisecondsSinceEpoch(
            sessionStartEpochSeconds * 1000,
          ),
        ),
      ),
    );
  }

  Future<void> recoverFromKillIfAny() async {
    if (controller.hasTestAnalyzerOverride) return;
    if (recoveryAttempted) return;
    recoveryAttempted = true;

    final snapshot = await SessionRecoveryStore.load();
    if (snapshot == null) return;
    final age = DateTime.now().difference(snapshot.startedAt);
    if (age >= SessionRecoveryStore.maxAge) {
      await SessionRecoveryStore.clear();
      return;
    }

    try {
      final bridge = controller.nativeBridge;
      if (await bridge.isMonitoringActive()) {
        await SessionRecoveryStore.clear();
        return;
      }
    } on Exception {
      // Fall through on error
    }

    try {
      final db = await controller.appDatabase;
      if (controller.disposed) return;
      final history = CallHistory.withRecordingError(
        dateTime: controller.formatDateTime(snapshot.startedAt),
        riskLevel: snapshot.riskLevel ?? RiskLevel.green.storageName,
        summary: 'Phiên bản giám sát bị hệ thống dừng đột ngột',
        duration: controller.formatElapsedTimeHelper(snapshot.elapsedSeconds),
        flagCount: 0,
        transcript: snapshot.transcript,
        audioPath: null,
        analysisType: controller.currentState.effectiveMode.name,
        recordingError: RecordingError.killed,
      );
      await db.insert(history);
    } on Object catch (e) {
      SystemLogger.instance.log(LogCategory.system, 'Session recovery failed: $e', level: LogLevel.error);
    } finally {
      await SessionRecoveryStore.clear();
    }
  }
}
