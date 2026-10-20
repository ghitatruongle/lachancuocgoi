import 'analysis_mode.dart';

class AnalysisRuntimeState {
  const AnalysisRuntimeState({
    required this.selectedMode,
    required this.effectiveMode,
    required this.networkAvailable,
    required this.isFallbackActive,
  });

  final AnalysisMode selectedMode;

  final AnalysisMode effectiveMode;

  final bool networkAvailable;

  final bool isFallbackActive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisRuntimeState &&
          selectedMode == other.selectedMode &&
          effectiveMode == other.effectiveMode &&
          networkAvailable == other.networkAvailable &&
          isFallbackActive == other.isFallbackActive;

  @override
  int get hashCode => Object.hash(
    selectedMode,
    effectiveMode,
    networkAvailable,
    isFallbackActive,
  );

  @override
  String toString() =>
      'AnalysisRuntimeState('
      'selectedMode: $selectedMode, '
      'effectiveMode: $effectiveMode, '
      'networkAvailable: $networkAvailable, '
      'isFallbackActive: $isFallbackActive)';
}

abstract final class AnalysisModePolicy {
  static AnalysisMode resolveEffectiveMode(
    AnalysisMode selectedMode,
    bool networkAvailable,
  ) {
    if (selectedMode == AnalysisMode.geminiApi && !networkAvailable) {
      return AnalysisMode.gDetection;
    }

    return selectedMode;
  }

  static bool shouldSkipCloudTier(
    AnalysisMode effectiveMode,
    bool networkAvailable,
  ) {
    if (!networkAvailable) {
      return effectiveMode == AnalysisMode.parallel ||
          effectiveMode == AnalysisMode.geminiApi;
    }
    return false;
  }

  static AnalysisRuntimeState createRuntimeState(
    AnalysisMode selectedMode,
    bool networkAvailable,
  ) {
    final effectiveMode = resolveEffectiveMode(selectedMode, networkAvailable);
    final fallbackActive =
        (selectedMode == AnalysisMode.geminiApi &&
            effectiveMode != AnalysisMode.geminiApi) ||
        (selectedMode == AnalysisMode.parallel && !networkAvailable);
    return AnalysisRuntimeState(
      selectedMode: selectedMode,
      effectiveMode: effectiveMode,
      networkAvailable: networkAvailable,
      isFallbackActive: fallbackActive,
    );
  }
}
