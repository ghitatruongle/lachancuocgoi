import 'dart:async' show unawaited;

import 'package:flutter/services.dart' show HapticFeedback;

import '../../analysis/analysis_result.dart';
import '../../core/risk_level.dart';
import '../../data/alert_history_entry.dart';
import '../../services/native_call_shield_bridge.dart';

class AlertManager {
  AlertManager({required NativeBridgeInterface Function() getBridge})
    : _getBridge = getBridge;

  final NativeBridgeInterface Function() _getBridge;

  bool reduceMotion = false;

  static const int _suppressionWindowMs = 15000;

  static const int _maxAlerts = 100;

  final Map<RiskLevel, int> _lastNativeAlertTime = {};
  final Map<RiskLevel, int> _lastHapticTime = {};
  List<AlertHistoryEntry> _alertHistory = const [];

  List<AlertHistoryEntry> get alertHistory =>
      List<AlertHistoryEntry>.unmodifiable(_alertHistory);

  List<AlertHistoryEntry> processResult(AnalysisResult result) {
    if (!result.alertEnabled) return _alertHistory;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final riskLevel = result.overallRiskLevel.storageName;
    final reason = result.reason ?? 'Cảnh báo rủi ro';

    final currentHistory = List<AlertHistoryEntry>.from(_alertHistory);

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

    if (currentHistory.length > _maxAlerts) {
      currentHistory.removeRange(0, currentHistory.length - _maxAlerts);
    }

    _alertHistory = currentHistory;
    return _alertHistory;
  }

  void triggerNativeAlert(AnalysisResult result) {
    final level = result.overallRiskLevel;

    _triggerHaptic(level);

    if (!result.alertEnabled) return;
    if (!level.shouldAlert) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _lastNativeAlertTime[level];
    if (lastTime != null && (nowMs - lastTime) < _suppressionWindowMs) {
      return;
    }
    _lastNativeAlertTime[level] = nowMs;

    final bridge = _getBridge();
    if (level == RiskLevel.red) {
      unawaited(bridge.showRedAlert(result.reason ?? 'Cảnh báo lừa đảo!'));
    } else if (level == RiskLevel.orange) {
      unawaited(bridge.showOrangeAlert(result.reason ?? 'Nội dung đáng ngờ!'));
    }
  }

  void _triggerHaptic(RiskLevel level) {
    if (reduceMotion) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _lastHapticTime[level];
    if (lastTime != null && (nowMs - lastTime) < _suppressionWindowMs) {
      return;
    }
    _lastHapticTime[level] = nowMs;

    switch (level) {
      case RiskLevel.red:
        unawaited(HapticFeedback.heavyImpact());
      case RiskLevel.orange:
        unawaited(HapticFeedback.mediumImpact());
      case RiskLevel.yellow:
        unawaited(HapticFeedback.lightImpact());
      case RiskLevel.green:
        break;
    }
  }

  void reset() {
    _lastNativeAlertTime.clear();
    _lastHapticTime.clear();
    _alertHistory = const [];
  }
}
