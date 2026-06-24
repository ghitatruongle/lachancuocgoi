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
  /// when network is unavailable and Gemini falls back to gDetection).
  final AnalysisMode effectiveMode;

  /// Whether the device currently has network connectivity.
  final bool networkAvailable;

  /// Whether a fallback from [AnalysisMode.geminiApi] to
  /// [AnalysisMode.gDetection] is active due to network loss.
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
///
/// Extracted from inline logic in [MonitoringController] so it can be
/// unit-tested independently and reused across the codebase.
///
/// Mirrors the Kotlin `AnalysisModePolicy` object.
abstract final class AnalysisModePolicy {
  /// Given the user's [selectedMode] and current [networkAvailable] status,
  /// returns the mode that should actually be used for analysis.
  ///
  /// Rules:
  /// - If [selectedMode] is [AnalysisMode.geminiApi] and network is
  ///   unavailable, falls back to [AnalysisMode.gDetection].
  /// - In all other cases, returns [selectedMode] unchanged.
  static AnalysisMode resolveEffectiveMode(
    AnalysisMode selectedMode,
    bool networkAvailable,
  ) {
    if (selectedMode == AnalysisMode.geminiApi && !networkAvailable) {
      return AnalysisMode.gDetection;
    }
    return selectedMode;
  }

  /// Creates a full [AnalysisRuntimeState] snapshot from the given inputs.
  ///
  /// This is the single source of truth for computing all four runtime
  /// fields at once, ensuring [isFallbackActive] is always consistent
  /// with [selectedMode] and [effectiveMode].
  static AnalysisRuntimeState createRuntimeState(
    AnalysisMode selectedMode,
    bool networkAvailable,
  ) {
    final effectiveMode = resolveEffectiveMode(selectedMode, networkAvailable);
    return AnalysisRuntimeState(
      selectedMode: selectedMode,
      effectiveMode: effectiveMode,
      networkAvailable: networkAvailable,
      isFallbackActive:
          selectedMode == AnalysisMode.geminiApi &&
          effectiveMode != AnalysisMode.geminiApi,
    );
  }
}
