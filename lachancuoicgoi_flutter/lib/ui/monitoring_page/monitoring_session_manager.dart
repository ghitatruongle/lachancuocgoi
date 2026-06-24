import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/risk_level.dart';
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
    if (controller.hasTestAnalyzerOverride || controller.isSimulationSession())
      return;
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
    if (controller.currentState.transcript.trim().isEmpty &&
        controller.currentState.elapsedSeconds < 5)
      return;

    unawaited(
      SessionRecoveryStore.save(
        SessionSnapshot(
          phoneNumber: controller.phoneNumber ?? '',
          transcript: controller.currentState.transcript,
          elapsedSeconds: controller.currentState.elapsedSeconds,
          riskLevel: controller.currentState.riskLevel.storageName,
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
      debugPrint('Session recovery failed: $e');
    } finally {
      await SessionRecoveryStore.clear();
    }
  }
}
