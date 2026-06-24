import 'dart:async' show unawaited;

import 'package:flutter/services.dart' show HapticFeedback;

import '../../analysis/analysis_result.dart';
import '../../core/risk_level.dart';
import '../../data/alert_history_entry.dart';
import '../../services/native_call_shield_bridge.dart';

/// Manages alert history, native alert suppression, and haptic feedback.
///
/// Extracted from [MonitoringController] to reduce class size.
class AlertManager {
  AlertManager({required NativeBridgeInterface Function() getBridge})
    : _getBridge = getBridge;

  final NativeBridgeInterface Function() _getBridge;

  /// Per-risk-level suppression window (ms) to avoid spam.
  static const int _suppressionWindowMs = 15000;

  /// Maximum number of alert history entries.
  static const int _maxAlerts = 100;

  final Map<RiskLevel, int> _lastNativeAlertTime = {};
  List<AlertHistoryEntry> _alertHistory = const [];

  /// Read-only snapshot of the alert history.
  List<AlertHistoryEntry> get alertHistory =>
      List<AlertHistoryEntry>.unmodifiable(_alertHistory);

  /// Processes an analysis result and triggers alerts if needed.
  /// Returns the updated alert history.
  List<AlertHistoryEntry> processResult(AnalysisResult result) {
    if (!result.alertEnabled) return _alertHistory;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final riskLevel = result.overallRiskLevel.storageName;
    final reason = result.reason ?? 'Cảnh báo rủi ro';

    final currentHistory = List<AlertHistoryEntry>.from(_alertHistory);

    // Merge with last entry if same level within suppression window
    if (currentHistory.isNotEmpty) {
      final last = currentHistory.last;
      if (last.riskLevel == riskLevel &&
          (timestamp - last.timestamp) < _suppressionWindowMs) {
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
        _alertHistory = currentHistory;
        return _alertHistory;
      }
    }

    currentHistory.add(
      AlertHistoryEntry(
        timestamp: timestamp,
        analysisLevel: result.analysisLevel.id,
        riskLevel: riskLevel,
        alertCount: 1,
        displayedReason: reason,
        allReasons: [reason],
      ),
    );

    // Bound the history size
    if (currentHistory.length > _maxAlerts) {
      currentHistory.removeRange(0, currentHistory.length - _maxAlerts);
    }

    _alertHistory = currentHistory;
    return _alertHistory;
  }

  /// Triggers native alerts (red/orange) with haptic feedback and
  /// suppression window (15s between same level).
  void triggerNativeAlert(AnalysisResult result) {
    if (!result.alertEnabled) return;

    final level = result.overallRiskLevel;
    if (!level.shouldAlert) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _lastNativeAlertTime[level];
    if (lastTime != null && (nowMs - lastTime) < _suppressionWindowMs) {
      return;
    }
    _lastNativeAlertTime[level] = nowMs;

    final bridge = _getBridge();
    if (level == RiskLevel.red) {
      unawaited(HapticFeedback.heavyImpact());
      unawaited(bridge.showRedAlert(result.reason ?? 'Cảnh báo lừa đảo!'));
    } else if (level == RiskLevel.orange) {
      unawaited(HapticFeedback.vibrate());
      unawaited(bridge.showOrangeAlert(result.reason ?? 'Nội dung đáng ngờ!'));
    }
  }

  /// Clears all alert state for a new session.
  void reset() {
    _lastNativeAlertTime.clear();
    _alertHistory = const [];
  }
}
