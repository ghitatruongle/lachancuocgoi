import '../../analysis/analysis_mode.dart';
import '../../analysis/analysis_result.dart';
import '../../core/risk_level.dart';
import '../../data/alert_history_entry.dart';

/// Immutable state for MonitoringController.
///
/// Named MonitoringPageState to avoid conflict with the
/// [MonitoringState] enum in native_call_shield_bridge.dart.
class MonitoringPageState {
  const MonitoringPageState({
    this.riskLevel = RiskLevel.green,
    this.transcript = '',
    this.elapsedSeconds = 0,
    this.networkAvailable = true,
    this.isFallbackActive = false,
    this.analysisResult,
    this.isAnalyzing = false,
    this.isEndingSession = false,
    this.isSimulationMode = false,
    this.selectedMode = AnalysisMode.normal,
    this.effectiveMode = AnalysisMode.normal,
    this.isCreatorMode = false,
    this.amplitudes = const [],
    this.navigationIntent,
    this.alertHistory = const [],
    // Sprint 2 (C1): banner flag set by the Dart-side monitoring state
    // listener when the native side reports `STT_FALLBACK:VOSK:*`.
    this.isSttFallback = false,
    this.sttFallbackReason,
    this.sttFallbackBannerId = 0,
  });

  final RiskLevel riskLevel;
  final String transcript;
  final int elapsedSeconds;
  final bool networkAvailable;
  final bool isFallbackActive;
  final AnalysisResult? analysisResult;
  final bool isAnalyzing;
  final bool isEndingSession;
  final bool isSimulationMode;
  final AnalysisMode selectedMode;
  final AnalysisMode effectiveMode;
  final bool isCreatorMode;
  /// ⚠️ Intentionally always empty. Waveform bypasses Riverpod via
  /// _AmplitudesNotifier (ChangeNotifier) to avoid excessive rebuilds.
  /// Peak amplitude for noAudio vs sttFailed is tracked in _peakAmplitude.
  final List<double> amplitudes;
  final NavigationIntent? navigationIntent;
  final List<AlertHistoryEntry> alertHistory;
  /// Sprint 2 (C1): true while the user should see a banner explaining
  /// that STT fell back to Vosk.
  final bool isSttFallback;
  /// Sprint 2 (C1): free-form reason from the native side
  /// (e.g. `error12_loop`, `network_errors_3`).
  final String? sttFallbackReason;
  /// Monotonic id incremented every time the banner is (re)shown.
  /// Drives a banner widget keyed off this value so it animates on each
  /// new event instead of being a no-op.
  final int sttFallbackBannerId;

  MonitoringPageState copyWith({
    RiskLevel? riskLevel,
    String? transcript,
    int? elapsedSeconds,
    bool? networkAvailable,
    bool? isFallbackActive,
    AnalysisResult? analysisResult,
    bool clearAnalysisResult = false,
    bool? isAnalyzing,
    bool? isEndingSession,
    bool? isSimulationMode,
    AnalysisMode? selectedMode,
    AnalysisMode? effectiveMode,
    bool? isCreatorMode,
    List<double>? amplitudes,
    NavigationIntent? navigationIntent,
    bool clearNavigationIntent = false,
    List<AlertHistoryEntry>? alertHistory,
    bool? isSttFallback,
    String? sttFallbackReason,
    // Bug #9 fix: sentinel to allow clearing sttFallbackReason to null
    bool clearSttFallbackReason = false,
    int? sttFallbackBannerId,
  }) {
    return MonitoringPageState(
      riskLevel: riskLevel ?? this.riskLevel,
      transcript: transcript ?? this.transcript,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      networkAvailable: networkAvailable ?? this.networkAvailable,
      isFallbackActive: isFallbackActive ?? this.isFallbackActive,
      analysisResult: clearAnalysisResult
          ? null
          : (analysisResult ?? this.analysisResult),
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isEndingSession: isEndingSession ?? this.isEndingSession,
      isSimulationMode: isSimulationMode ?? this.isSimulationMode,
      selectedMode: selectedMode ?? this.selectedMode,
      effectiveMode: effectiveMode ?? this.effectiveMode,
      isCreatorMode: isCreatorMode ?? this.isCreatorMode,
      amplitudes: amplitudes ?? this.amplitudes,
      navigationIntent: clearNavigationIntent
          ? null
          : (navigationIntent ?? this.navigationIntent),
      alertHistory: alertHistory ?? this.alertHistory,
      isSttFallback: isSttFallback ?? this.isSttFallback,
      sttFallbackReason: clearSttFallbackReason
          ? null
          : (sttFallbackReason ?? this.sttFallbackReason),
      sttFallbackBannerId:
          sttFallbackBannerId ?? this.sttFallbackBannerId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonitoringPageState &&
          riskLevel == other.riskLevel &&
          transcript == other.transcript &&
          elapsedSeconds == other.elapsedSeconds &&
          networkAvailable == other.networkAvailable &&
          isFallbackActive == other.isFallbackActive &&
          analysisResult == other.analysisResult &&
          isAnalyzing == other.isAnalyzing &&
          isEndingSession == other.isEndingSession &&
          isSimulationMode == other.isSimulationMode &&
          selectedMode == other.selectedMode &&
          effectiveMode == other.effectiveMode &&
          isCreatorMode == other.isCreatorMode &&
          navigationIntent == other.navigationIntent &&
          _listEquals(alertHistory, other.alertHistory) &&
          isSttFallback == other.isSttFallback &&
          sttFallbackReason == other.sttFallbackReason &&
          sttFallbackBannerId == other.sttFallbackBannerId &&
          _listEquals(amplitudes, other.amplitudes);

  @override
  int get hashCode => Object.hash(
        riskLevel,
        transcript,
        elapsedSeconds,
        networkAvailable,
        isFallbackActive,
        analysisResult,
        isAnalyzing,
        isEndingSession,
        isSimulationMode,
        selectedMode,
        effectiveMode,
        isCreatorMode,
        navigationIntent,
        Object.hashAll(alertHistory),
        isSttFallback,
        sttFallbackReason,
        sttFallbackBannerId,
        Object.hashAll(amplitudes),
      );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Sealed class for navigation intents — replaces direct context.go() calls.
sealed class NavigationIntent {
  const NavigationIntent();
}

/// Navigate to the result page with a specific history ID.
class NavigateToResult extends NavigationIntent {
  const NavigateToResult(this.historyId);
  final int historyId;
}

/// Navigate to the home page.
class NavigateToHome extends NavigationIntent {
  const NavigateToHome();
}
