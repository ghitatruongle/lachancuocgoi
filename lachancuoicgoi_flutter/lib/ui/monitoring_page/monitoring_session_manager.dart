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
    if (controller.disposed ||
        controller.currentState.phase != MonitoringPhase.active) {
      return;
    }
    if (controller.currentState.isSimulationMode) return;

    final state = controller.currentState;
    if (state.transcript.trim().isEmpty && state.elapsedSeconds < 10) {
      return;
    }

    if (state.transcript.trim().isEmpty &&
        !controller.audioHandler.hasReceivedAnyAudio) {
      return;
    }

    unawaited(
      SessionRecoveryStore.save(
        SessionSnapshot(
          phoneNumber: controller.maskedNumber ?? '',
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
    if (snapshot.elapsedSeconds <= 0 && snapshot.transcript.trim().isEmpty) {
      await SessionRecoveryStore.clear();
      return;
    }
    final age = DateTime.now().difference(snapshot.startedAt);
    if (age >= SessionRecoveryStore.maxAge) {
      await SessionRecoveryStore.clear();
      return;
    }

    try {
      final bridge = controller.nativeBridge;
      if (await bridge.isMonitoringActive()) {
        return;
      }
    } on Exception {
      assert(true);
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
      await SessionRecoveryStore.clear();
    } on Object catch (e) {
      SystemLogger.instance.log(
        LogCategory.system,
        'Session recovery failed: $e',
        level: LogLevel.error,
      );
    }
  }
}
