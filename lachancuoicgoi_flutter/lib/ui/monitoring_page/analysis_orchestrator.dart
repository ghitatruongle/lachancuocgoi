import 'dart:async' show Completer, Timer, Future;

import 'package:flutter/foundation.dart' show debugPrint;

import '../../analysis/analysis_coordinator.dart';
import '../../analysis/analysis_level.dart';
import '../../analysis/analysis_mode.dart';
import '../../analysis/analysis_result.dart';
import '../../core/risk_level.dart';

/// Manages analysis debouncing, execution, and re-analysis queue.
///
/// Encapsulates:
/// - Debounce timer for real-time analysis
/// - Generation counter to discard stale results
/// - Pending re-analysis tracking when analysis is already in-flight
/// - Completer pattern for end-of-call analysis deduplication
class AnalysisOrchestrator {
  AnalysisOrchestrator({
    required this.coordinator,
    required AnalysisMode Function() getEffectiveMode,
    required String Function() getTranscript,
    required void Function(AnalysisResult result, AnalysisMode mode) onResult,
    required void Function(AnalysisResult fallback) onError,
  })  : _getEffectiveMode = getEffectiveMode,
        _getTranscript = getTranscript,
        _onResult = onResult,
        _onError = onError;

  final AnalysisCoordinator coordinator;
  final AnalysisMode Function() _getEffectiveMode;
  final String Function() _getTranscript;
  final void Function(AnalysisResult result, AnalysisMode mode) _onResult;
  final void Function(AnalysisResult fallback) _onError;

  Timer? _analysisDebounce;
  String? _pendingReanalysisText;
  Completer<void>? _analysisCompleter;
  int _analysisGeneration = 0;

  /// Whether an analysis is currently in-flight.
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  /// Runs a single full analysis of the current transcript.
  /// Uses Completer to deduplicate concurrent calls.
  Future<void> ensureAnalysisComplete() async {
    final text = _getTranscript();
    if (text.trim().isEmpty) return;
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
      await _runFullAnalysis();
      if (!completer.isCompleted) completer.complete();
    } catch (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    } finally {
      if (identical(_analysisCompleter, completer)) {
        _analysisCompleter = null;
      }
    }
  }

  /// Schedules debounced real-time incremental analysis.
  void scheduleRealTimeAnalysis(String text) {
    _analysisDebounce?.cancel();
    _analysisDebounce = Timer(const Duration(milliseconds: 1200), () async {
      final textForRun = text;
      final effectiveMode = _getEffectiveMode();
      if (textForRun.trim().isEmpty) return;

      if (_isAnalyzing) {
        _pendingReanalysisText = textForRun;
        return;
      }
      _pendingReanalysisText = null;
      final myGeneration = ++_analysisGeneration;
      _isAnalyzing = true;
      try {
        final result = await coordinator.analyzeIncremental(
          textForRun,
          effectiveMode,
        );

        if (myGeneration != _analysisGeneration) return;

        _onResult(result, effectiveMode);

        // Process pending reanalysis
        final pendingText = _pendingReanalysisText;
        _pendingReanalysisText = null;
        if (pendingText != null) {
          scheduleRealTimeAnalysis(pendingText);
        }
      } on Object catch (e) {
        debugPrint('AnalysisOrchestrator._runRealTimeAnalysis failed: $e');
        // Propagate fallback result on error
        _onError(
          const AnalysisResult(
            overallRiskLevel: RiskLevel.green,
            matches: <KeywordMatch>[],
            reason: 'Lỗi khi chạy phân tích.',
            analysisLevel: AnalysisLevel.l1,
            isError: true,
          ),
        );
        final pendingText = _pendingReanalysisText;
        _pendingReanalysisText = null;
        if (pendingText != null) {
          scheduleRealTimeAnalysis(pendingText);
        }
      } finally {
        _isAnalyzing = false;
      }
    });
  }

  Future<void> _runFullAnalysis() async {
    final myGeneration = ++_analysisGeneration;
    _isAnalyzing = true;
    try {
      final result = await coordinator.analyze(
        _getTranscript(),
        _getEffectiveMode(),
      );
      if (myGeneration == _analysisGeneration) {
        _onResult(result, _getEffectiveMode());
      }
    } on Object catch (e) {
      debugPrint('AnalysisOrchestrator._runAnalysis failed: $e');
      if (myGeneration == _analysisGeneration) {
        _onError(
          const AnalysisResult(
            overallRiskLevel: RiskLevel.green,
            matches: <KeywordMatch>[],
            reason: 'Lỗi khi chạy phân tích.',
            analysisLevel: AnalysisLevel.l1,
            isError: true,
          ),
        );
      }
    } finally {
      _isAnalyzing = false;
    }
  }

  /// Cancels any pending debounced analysis.
  void cancelDebounce() {
    _analysisDebounce?.cancel();
    _analysisDebounce = null;
  }

  /// Resets the generation counter (e.g. on session reset).
  void resetGeneration() {
    _analysisGeneration = 0;
    _pendingReanalysisText = null;
    _analysisCompleter = null;
    _isAnalyzing = false;
  }
}
