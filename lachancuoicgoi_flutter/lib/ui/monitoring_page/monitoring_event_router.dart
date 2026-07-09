import '../../analysis/analysis_mode_policy.dart';
import '../../services/native_call_shield_bridge.dart';
import 'monitoring_state.dart';

// ─── Monitoring Event Router ───────────────────────────────────────────
//
// Interprets [MonitoringState] events from the native bridge and updates
// the [MonitoringPageState] accordingly (network changes, STT fallback,
// stopped events).
//
// Extracted from [MonitoringController] to reduce class size.

typedef StateUpdater = void Function(
    MonitoringPageState Function(MonitoringPageState) updater);

class MonitoringEventRouter {
  MonitoringEventRouter({
    required StateUpdater updateState,
    required MonitoringPageState Function() getState,
    required void Function() onStoppedEvent,
    required void Function() endSession,
  })  : _updateState = updateState,
        _getState = getState,
        _onStoppedEvent = onStoppedEvent,
        _endSession = endSession;

  final StateUpdater _updateState;
  final MonitoringPageState Function() _getState;
  final void Function() _onStoppedEvent;
  final void Function() _endSession;

  /// Routes a monitoring state event to the appropriate handler.
  void handleMonitoringStateEvent((MonitoringState, int?, String?) stateData) {
    final monitoringState = stateData.$1;
    if (monitoringState == MonitoringState.networkAvailable ||
        monitoringState == MonitoringState.networkLost) {
      _handleNetworkChange(monitoringState);
    } else if (monitoringState == MonitoringState.sttFallbackVosk) {
      _handleSttFallback(stateData.$3);
    } else if (monitoringState == MonitoringState.stopped) {
      _handleStopped(stateData.$3);
    }
  }

  void _handleNetworkChange(MonitoringState monitoringState) {
    final isAvailable = monitoringState == MonitoringState.networkAvailable;
    final currentState = _getState();
    final runtime = AnalysisModePolicy.createRuntimeState(
      currentState.selectedMode,
      isAvailable,
    );
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
      ),
    );
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
