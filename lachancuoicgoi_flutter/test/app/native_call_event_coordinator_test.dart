import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/app/native_call_event_coordinator.dart';
import 'package:lachancuocgoi_flutter/services/bridge_models.dart';

void main() {
  test('buffers navigation until the application is ready', () async {
    final events = StreamController<NativeCallEvent>.broadcast();
    final navigated = <NativeCallEvent>[];
    final coordinator = NativeCallEventCoordinator(
      events: events.stream,
      onNavigateToMonitoring: navigated.add,
    )..start();

    const event = NativeCallEvent(
      type: 'NAVIGATE_TO_MONITORING',
      timestampMs: 10,
      reason: 'notification_navigation',
      numberAvailable: true,
      maskedNumber: '••••1234',
    );
    events.add(event);
    await Future<void>.delayed(Duration.zero);
    expect(navigated, isEmpty);

    coordinator.setReady(true);
    expect(navigated, <NativeCallEvent>[event]);

    await coordinator.dispose();
    await events.close();
  });

  test('deduplicates by type and timestamp', () async {
    final events = StreamController<NativeCallEvent>.broadcast();
    final navigated = <NativeCallEvent>[];
    final coordinator =
        NativeCallEventCoordinator(
            events: events.stream,
            onNavigateToMonitoring: navigated.add,
          )
          ..start()
          ..setReady(true);

    const event = NativeCallEvent(
      type: 'NAVIGATE_TO_MONITORING',
      timestampMs: 20,
      reason: 'notification_navigation',
    );
    events
      ..add(event)
      ..add(event);
    await Future<void>.delayed(Duration.zero);

    expect(navigated, hasLength(1));
    await coordinator.dispose();
    await events.close();
  });

  test('does not navigate for ordinary call-state events', () async {
    final events = StreamController<NativeCallEvent>.broadcast();
    final navigated = <NativeCallEvent>[];
    final coordinator =
        NativeCallEventCoordinator(
            events: events.stream,
            onNavigateToMonitoring: navigated.add,
          )
          ..start()
          ..setReady(true);

    events.add(
      const NativeCallEvent(
        type: 'RINGING',
        timestampMs: 30,
        reason: 'phone_state',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(navigated, isEmpty);
    await coordinator.dispose();
    await events.close();
  });

  test('dispatches accepted and ended lifecycle without navigation', () async {
    final events = StreamController<NativeCallEvent>.broadcast();
    final navigated = <NativeCallEvent>[];
    final accepted = <NativeCallEvent>[];
    final ended = <NativeCallEvent>[];
    final coordinator =
        NativeCallEventCoordinator(
            events: events.stream,
            onNavigateToMonitoring: navigated.add,
            onMonitoringAccepted: accepted.add,
            onSessionEnded: ended.add,
          )
          ..start()
          ..setReady(true);

    const acceptedEvent = NativeCallEvent(
      type: 'MONITORING_ACCEPTED',
      timestampMs: 40,
    );
    const endedEvent = NativeCallEvent(
      type: 'CALL_SESSION_ENDED',
      timestampMs: 41,
    );
    events
      ..add(acceptedEvent)
      ..add(endedEvent);
    await Future<void>.delayed(Duration.zero);

    expect(accepted, <NativeCallEvent>[acceptedEvent]);
    expect(ended, <NativeCallEvent>[endedEvent]);
    expect(navigated, isEmpty);
    await coordinator.dispose();
    await events.close();
  });
}
