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
    this.peakRiskLevel = RiskLevel.green,
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
    this.navigationIntent,
    this.alertHistory = const [],
    this.isSttFallback = false,
    this.sttFallbackReason,
    this.sttFallbackBannerId = 0,
    this.isSttUnavailable = false,
    this.sttUnavailableReason,
    this.isDegradedNoNotification = false,
    this.isWatchdogRestartFailed = false,
  });

  final RiskLevel riskLevel;
  final RiskLevel peakRiskLevel;
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
  final NavigationIntent? navigationIntent;
  final List<AlertHistoryEntry> alertHistory;

  /// STT fell back to Vosk offline.
  final bool isSttFallback;
  final String? sttFallbackReason;
  final int sttFallbackBannerId;

  /// Both STT engines failed — monitoring is blind.
  final bool isSttUnavailable;
  final String? sttUnavailableReason;

  /// Missing POST_NOTIFICATIONS on Android 13+.
  final bool isDegradedNoNotification;

  /// Watchdog could not restart the foreground service.
  final bool isWatchdogRestartFailed;

  MonitoringPageState copyWith({
    RiskLevel? riskLevel,
    RiskLevel? peakRiskLevel,
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
    NavigationIntent? navigationIntent,
    bool clearNavigationIntent = false,
    List<AlertHistoryEntry>? alertHistory,
    bool? isSttFallback,
    String? sttFallbackReason,
    bool clearSttFallbackReason = false,
    int? sttFallbackBannerId,
    bool? isSttUnavailable,
    String? sttUnavailableReason,
    bool clearSttUnavailableReason = false,
    bool? isDegradedNoNotification,
    bool? isWatchdogRestartFailed,
  }) {
    return MonitoringPageState(
      riskLevel: riskLevel ?? this.riskLevel,
      peakRiskLevel: peakRiskLevel ?? this.peakRiskLevel,
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
      navigationIntent: clearNavigationIntent
          ? null
          : (navigationIntent ?? this.navigationIntent),
      alertHistory: alertHistory ?? this.alertHistory,
      isSttFallback: isSttFallback ?? this.isSttFallback,
      sttFallbackReason: clearSttFallbackReason
          ? null
          : (sttFallbackReason ?? this.sttFallbackReason),
      sttFallbackBannerId: sttFallbackBannerId ?? this.sttFallbackBannerId,
      isSttUnavailable: isSttUnavailable ?? this.isSttUnavailable,
      sttUnavailableReason: clearSttUnavailableReason
          ? null
          : (sttUnavailableReason ?? this.sttUnavailableReason),
      isDegradedNoNotification:
          isDegradedNoNotification ?? this.isDegradedNoNotification,
      isWatchdogRestartFailed:
          isWatchdogRestartFailed ?? this.isWatchdogRestartFailed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonitoringPageState &&
          riskLevel == other.riskLevel &&
          peakRiskLevel == other.peakRiskLevel &&
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
          isSttUnavailable == other.isSttUnavailable &&
          sttUnavailableReason == other.sttUnavailableReason &&
          isDegradedNoNotification == other.isDegradedNoNotification &&
          isWatchdogRestartFailed == other.isWatchdogRestartFailed;

  @override
  int get hashCode => Object.hash(
    riskLevel,
    peakRiskLevel,
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
    Object.hash(
      isSttUnavailable,
      sttUnavailableReason,
      isDegradedNoNotification,
      isWatchdogRestartFailed,
    ),
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
