import 'analysis_mode.dart';

/// Immutable runtime snapshot of the analysis mode state.
///
/// Mirrors the Kotlin `AnalysisRuntimeState` data class.
class AnalysisRuntimeState {
  const AnalysisRuntimeState({
    required this.selectedMode,
    required this.effectiveMode,
    required this.networkAvailable,
    required this.isFallbackActive,
  });

  /// The mode the user explicitly chose in settings.
  final AnalysisMode selectedMode;

  /// The mode actually used for analysis (may differ from [selectedMode]
  /// when network is unavailable and cloud tiers fall back).
  final AnalysisMode effectiveMode;

  /// Whether the device currently has network connectivity.
  final bool networkAvailable;

  /// Whether a network-driven fallback is active.
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

/// Stateless policy that resolves the effective [AnalysisMode] based on
/// user selection and network availability.
abstract final class AnalysisModePolicy {
  /// Given the user's [selectedMode] and current [networkAvailable] status,
  /// returns the mode that should actually be used for analysis.
  ///
  /// Rules:
  /// - [AnalysisMode.geminiApi] offline → [AnalysisMode.gDetection]
  /// - [AnalysisMode.parallel] offline → stays parallel but L3 is skipped
  ///   by the coordinator (see [shouldSkipCloudTier])
  /// - Otherwise returns [selectedMode] unchanged.
  static AnalysisMode resolveEffectiveMode(
    AnalysisMode selectedMode,
    bool networkAvailable,
  ) {
    if (selectedMode == AnalysisMode.geminiApi && !networkAvailable) {
      return AnalysisMode.gDetection;
    }
    // Parallel stays parallel offline — coordinator runs L1+L2 only.
    return selectedMode;
  }

  /// Whether cloud (L3/Gemini) analysis should be skipped.
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

  /// Creates a full [AnalysisRuntimeState] snapshot from the given inputs.
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
