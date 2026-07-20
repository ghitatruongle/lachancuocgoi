import 'dart:async';

import '../services/bridge_models.dart';

typedef NativeCallNavigation = void Function(NativeCallEvent event);
typedef NativeCallLifecycle = void Function(NativeCallEvent event);

/// Keeps native call navigation events alive while application settings and
/// the router are still starting.
///
/// Native already buffers events until an EventChannel listener connects. This
/// coordinator adds the application-level half of that contract: it subscribes
/// before the first route is built, de-duplicates replayed events and only
/// dispatches navigation after onboarding/settings are ready.
class NativeCallEventCoordinator {
  NativeCallEventCoordinator({
    required Stream<NativeCallEvent> events,
    required NativeCallNavigation onNavigateToMonitoring,
    this.onMonitoringAccepted,
    this.onSessionEnded,
    this.maxBufferedEvents = 50,
    this.maxDeduplicationKeys = 100,
  }) : _events = events,
       _onNavigateToMonitoring = onNavigateToMonitoring;

  final Stream<NativeCallEvent> _events;
  final NativeCallNavigation _onNavigateToMonitoring;
  final NativeCallLifecycle? onMonitoringAccepted;
  final NativeCallLifecycle? onSessionEnded;
  final int maxBufferedEvents;
  final int maxDeduplicationKeys;

  final List<NativeCallEvent> _pending = <NativeCallEvent>[];
  final Set<String> _seenKeys = <String>{};
  final List<String> _seenOrder = <String>[];
  StreamSubscription<NativeCallEvent>? _subscription;
  bool _ready = false;
  bool _disposed = false;

  void start() {
    if (_disposed || _subscription != null) return;
    _subscription = _events.listen(_handleEvent);
  }

  void setReady(bool ready) {
    if (_disposed || _ready == ready) return;
    _ready = ready;
    if (!_ready || _pending.isEmpty) return;

    final pending = List<NativeCallEvent>.of(_pending);
    _pending.clear();
    for (final event in pending) {
      _dispatch(event);
    }
  }

  void _handleEvent(NativeCallEvent event) {
    if (_disposed || !_remember(event)) return;
    if (!_ready) {
      if (_pending.length >= maxBufferedEvents) _pending.removeAt(0);
      _pending.add(event);
      return;
    }
    _dispatch(event);
  }

  bool _remember(NativeCallEvent event) {
    final key = '${event.type}|${event.timestampMs}';
    if (!_seenKeys.add(key)) return false;
    _seenOrder.add(key);
    if (_seenOrder.length > maxDeduplicationKeys) {
      _seenKeys.remove(_seenOrder.removeAt(0));
    }
    return true;
  }

  void _dispatch(NativeCallEvent event) {
    final type = event.type.trim().toUpperCase();
    final reason = event.reason?.trim().toLowerCase();
    if (type == 'MONITORING_ACCEPTED') {
      onMonitoringAccepted?.call(event);
      return;
    }
    if (type == 'CALL_SESSION_ENDED') {
      onSessionEnded?.call(event);
      return;
    }
    if (type == 'NAVIGATE_TO_MONITORING' ||
        reason == 'notification_navigation') {
      _onNavigateToMonitoring(event);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pending.clear();
    await _subscription?.cancel();
    _subscription = null;
  }
}
