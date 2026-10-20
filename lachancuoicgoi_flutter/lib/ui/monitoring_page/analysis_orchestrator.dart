import 'dart:async' show Completer, Timer, Future;

import '../../analysis/analysis_coordinator.dart';
import '../../analysis/analysis_level.dart';
import '../../analysis/analysis_mode.dart';
import '../../analysis/analysis_result.dart';
import '../../core/risk_level.dart';
import '../../core/system_logger.dart';

class AnalysisOrchestrator {
  AnalysisOrchestrator({
    required this.coordinator,
    required AnalysisMode Function() getEffectiveMode,
    required String Function() getTranscript,
    required void Function(AnalysisResult result, AnalysisMode mode) onResult,
    required void Function(AnalysisResult fallback) onError,
  }) : _getEffectiveMode = getEffectiveMode,
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
  bool _disposed = false;

  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;
  bool get disposed => _disposed;

  Future<void> ensureAnalysisComplete() async {
    if (_disposed) return;
    final text = _getTranscript();
    if (text.trim().isEmpty) return;
    _analysisDebounce?.cancel();

    final existing = _analysisCompleter;
    if (existing != null && !existing.isCompleted) {
      try {
        await existing.future;
      } on Exception {
        assert(true);
      }

      if (_disposed) return;
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

  void scheduleRealTimeAnalysis(String text) {
    if (_disposed) return;
    _analysisDebounce?.cancel();
    _analysisDebounce = Timer(const Duration(milliseconds: 1200), () async {
      if (_disposed) return;
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

        if (_disposed || myGeneration != _analysisGeneration) return;

        _onResult(result, effectiveMode);

        final pendingText = _pendingReanalysisText;
        _pendingReanalysisText = null;
        if (pendingText != null) {
          scheduleRealTimeAnalysis(pendingText);
        }
      } on Object catch (e) {
        if (_disposed) return;
        SystemLogger.instance.log(
          LogCategory.analysis,
          'AnalysisOrchestrator._runRealTimeAnalysis failed: $e',
          level: LogLevel.error,
        );

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
    if (_disposed) return;
    final myGeneration = ++_analysisGeneration;
    _isAnalyzing = true;
    try {
      final result = await coordinator.analyze(
        _getTranscript(),
        _getEffectiveMode(),
      );
      if (_disposed || myGeneration != _analysisGeneration) return;
      _onResult(result, _getEffectiveMode());
    } on Object catch (e) {
      if (_disposed) return;
      SystemLogger.instance.log(
        LogCategory.analysis,
        'AnalysisOrchestrator._runAnalysis failed: $e',
        level: LogLevel.error,
      );
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

  void cancelDebounce() {
    _analysisDebounce?.cancel();
    _analysisDebounce = null;
  }

  void resetGeneration() {
    _analysisGeneration = 0;
    _pendingReanalysisText = null;
    _analysisCompleter = null;
    _isAnalyzing = false;
  }

  void dispose() {
    _disposed = true;
    _analysisDebounce?.cancel();
    _analysisDebounce = null;
  }
}
