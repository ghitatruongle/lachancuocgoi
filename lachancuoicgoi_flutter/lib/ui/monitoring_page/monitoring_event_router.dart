import '../../analysis/analysis_mode_policy.dart';
import '../../services/native_call_shield_bridge.dart';
import 'monitoring_state.dart';

// ─── Monitoring Event Router ───────────────────────────────────────────
//
// Interprets [MonitoringState] events from the native bridge and updates
// the [MonitoringPageState] accordingly (network, STT, degraded modes).

typedef StateUpdater = void Function(
  MonitoringPageState Function(MonitoringPageState) updater,
);

class MonitoringEventRouter {
  MonitoringEventRouter({
    required StateUpdater updateState,
    required MonitoringPageState Function() getState,
    required void Function() onStoppedEvent,
    required void Function() endSession,
    void Function(bool networkAvailable)? onNetworkChanged,
  }) : _updateState = updateState,
       _getState = getState,
       _onStoppedEvent = onStoppedEvent,
       _endSession = endSession,
       _onNetworkChanged = onNetworkChanged;

  final StateUpdater _updateState;
  final MonitoringPageState Function() _getState;
  final void Function() _onStoppedEvent;
  final void Function() _endSession;
  final void Function(bool networkAvailable)? _onNetworkChanged;

  /// Routes a monitoring state event to the appropriate handler.
  void handleMonitoringStateEvent((MonitoringState, int?, String?) stateData) {
    final monitoringState = stateData.$1;
    switch (monitoringState) {
      case MonitoringState.networkAvailable:
      case MonitoringState.networkLost:
        _handleNetworkChange(monitoringState);
      case MonitoringState.sttFallbackVosk:
        _handleSttFallback(stateData.$3);
      case MonitoringState.sttUnavailable:
        _handleSttUnavailable(stateData.$3);
      case MonitoringState.degradedNoNotification:
        _handleDegradedNoNotification();
      case MonitoringState.watchdogRestartFailed:
        _handleWatchdogRestartFailed();
      case MonitoringState.stopped:
        _handleStopped(stateData.$3);
      case MonitoringState.idle:
      case MonitoringState.started:
        break;
    }
  }

  void _handleNetworkChange(MonitoringState monitoringState) {
    final isAvailable = monitoringState == MonitoringState.networkAvailable;
    final currentState = _getState();
    final runtime = AnalysisModePolicy.createRuntimeState(
      currentState.selectedMode,
      isAvailable,
    );
    _onNetworkChanged?.call(isAvailable);
    _updateState(
      (s) => s.copyWith(
        networkAvailable: runtime.networkAvailable,
        effectiveMode: runtime.effectiveMode,
        isFallbackActive: runtime.isFallbackActive,
      ),
    );
  }

  void _handleSttFallback(String? reason) {
    _updateState(
      (s) => s.copyWith(
        isSttFallback: true,
        sttFallbackReason: reason,
        sttFallbackBannerId: s.sttFallbackBannerId + 1,
        isSttUnavailable: false,
        clearSttUnavailableReason: true,
      ),
    );
  }

  void _handleSttUnavailable(String? reason) {
    _updateState(
      (s) => s.copyWith(
        isSttUnavailable: true,
        sttUnavailableReason: reason,
        isSttFallback: false,
        clearSttFallbackReason: true,
      ),
    );
  }

  void _handleDegradedNoNotification() {
    _updateState((s) => s.copyWith(isDegradedNoNotification: true));
  }

  void _handleWatchdogRestartFailed() {
    _updateState((s) => s.copyWith(isWatchdogRestartFailed: true));
  }

  void _handleStopped(String? finalTranscript) {
    final trimmed = finalTranscript?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      _updateState((s) => s.copyWith(transcript: trimmed));
    }
    _onStoppedEvent();
    final currentState = _getState();
    if (!currentState.isEndingSession) {
      _endSession();
    }
  }
}
