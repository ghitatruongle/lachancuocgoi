import '../../analysis/analysis_mode.dart';
import '../../analysis/analysis_result.dart';
import '../../core/analysis_availability.dart';
import '../../core/risk_level.dart';
import '../../data/alert_history_entry.dart';

/// Single source of truth for the monitoring-session lifecycle.
enum MonitoringPhase { idle, starting, active, stopping, saved, failed }

/// Immutable state for MonitoringController.
///
/// Named MonitoringPageState to avoid conflict with the
/// [MonitoringState] enum in native_call_shield_bridge.dart.
class MonitoringPageState {
  const MonitoringPageState({
    MonitoringPhase phase = MonitoringPhase.idle,
    bool? isEndingSession,
    this.availability = AnalysisAvailability.pending,
    this.monitoringErrorMessage,
    this.riskLevel = RiskLevel.green,
    this.peakRiskLevel = RiskLevel.green,
    this.transcript = '',
    this.elapsedSeconds = 0,
    this.networkAvailable = true,
    this.isFallbackActive = false,
    this.analysisResult,
    this.isAnalyzing = false,
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
  }) : phase = isEndingSession == true ? MonitoringPhase.stopping : phase;

  final MonitoringPhase phase;
  final AnalysisAvailability availability;
  final String? monitoringErrorMessage;
  final RiskLevel riskLevel;
  final RiskLevel peakRiskLevel;
  final String transcript;
  final int elapsedSeconds;
  final bool networkAvailable;
  final bool isFallbackActive;
  final AnalysisResult? analysisResult;
  final bool isAnalyzing;

  /// Compatibility getter for existing widgets and tests. New code should use
  /// [phase] directly.
  bool get isEndingSession => phase == MonitoringPhase.stopping;

  bool get isStarting => phase == MonitoringPhase.starting;
  bool get isMonitoring => phase == MonitoringPhase.active;
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
    MonitoringPhase? phase,
    AnalysisAvailability? availability,
    String? monitoringErrorMessage,
    bool clearMonitoringErrorMessage = false,
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
    final resolvedPhase =
        phase ??
        (isEndingSession == true ? MonitoringPhase.stopping : this.phase);
    return MonitoringPageState(
      phase: resolvedPhase,
      availability: availability ?? this.availability,
      monitoringErrorMessage: clearMonitoringErrorMessage
          ? null
          : (monitoringErrorMessage ?? this.monitoringErrorMessage),
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
          phase == other.phase &&
          availability == other.availability &&
          monitoringErrorMessage == other.monitoringErrorMessage &&
          riskLevel == other.riskLevel &&
          peakRiskLevel == other.peakRiskLevel &&
          transcript == other.transcript &&
          elapsedSeconds == other.elapsedSeconds &&
          networkAvailable == other.networkAvailable &&
          isFallbackActive == other.isFallbackActive &&
          analysisResult == other.analysisResult &&
          isAnalyzing == other.isAnalyzing &&
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
    phase,
    availability,
    monitoringErrorMessage,
    riskLevel,
    peakRiskLevel,
    transcript,
    elapsedSeconds,
    networkAvailable,
    isFallbackActive,
    analysisResult,
    isAnalyzing,
    isSimulationMode,
    selectedMode,
    effectiveMode,
    isCreatorMode,
    navigationIntent,
    Object.hashAll(alertHistory),
    Object.hash(
      isSttFallback,
      sttFallbackReason,
      sttFallbackBannerId,
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
