import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/native_call_shield_bridge.dart';
import 'monitoring_controller.dart';

class MonitoringStreamHandler {
  MonitoringStreamHandler(this.controller);

  final MonitoringController controller;

  StreamSubscription<TranscriptUpdate>? transcriptSub;
  StreamSubscription<double>? rmsSub;
  StreamSubscription<(MonitoringState, int?, String?)>? stateSub;
  StreamSubscription<CallEvent>? callEventSub;
  bool streamsDead = false;

  void initStreams() {
    if (controller.isSimulationSession()) return;

    if (!streamsDead &&
        (transcriptSub != null || rmsSub != null || stateSub != null || callEventSub != null)) {
      return;
    }
    streamsDead = false;

    cancelStreams();

    final bridge = controller.nativeBridge;

    transcriptSub = bridge.transcriptStream.listen(
      (update) {
        if (controller.disposed) return;
        controller.updateTranscriptFromStream(update.text);
      },
      onDone: () {
        if (controller.disposed) return;
        debugPrint('transcriptStream done — marking subscriptions dead.');
        streamsDead = true;
        transcriptSub?.cancel();
        transcriptSub = null;
      },
      onError: (Object e, StackTrace st) {
        debugPrint('transcriptStream error: $e');
        streamsDead = true;
        transcriptSub?.cancel();
        transcriptSub = null;
      },
    );

    rmsSub = bridge.rmsStream.listen(
      (rms) {
        if (controller.disposed) return;
        controller.handleRmsEvent(rms);
      },
      onDone: () {
        if (controller.disposed) return;
        debugPrint('rmsStream done — marking subscriptions dead.');
        streamsDead = true;
        rmsSub?.cancel();
        rmsSub = null;
      },
      onError: (Object e, StackTrace st) {
        debugPrint('rmsStream error: $e');
        streamsDead = true;
        rmsSub?.cancel();
        rmsSub = null;
      },
    );

    stateSub = bridge.monitoringStateStream.listen(
      (stateData) {
        if (controller.disposed) return;
        controller.handleMonitoringStateEvent(stateData);
      },
      onDone: () {
        if (controller.disposed) return;
        debugPrint('monitoringStateStream done — marking subscriptions dead.');
        streamsDead = true;
        stateSub?.cancel();
        stateSub = null;
      },
      onError: (Object e, StackTrace st) {
        debugPrint('monitoringStateStream error: $e');
        streamsDead = true;
        stateSub?.cancel();
        stateSub = null;
      },
    );

    callEventSub = bridge.callEventStream.listen(
      (event) {
        if (controller.disposed) return;
        if (event.phoneNumber != null && event.phoneNumber!.isNotEmpty) {
          controller.phoneNumber = event.phoneNumber;
        }
      },
      onDone: () {
        if (controller.disposed) return;
        debugPrint('callEventStream done — marking subscriptions dead.');
        streamsDead = true;
        callEventSub?.cancel();
        callEventSub = null;
      },
      onError: (Object e, StackTrace st) {
        debugPrint('callEventStream error: $e');
        streamsDead = true;
        callEventSub?.cancel();
        callEventSub = null;
      },
    );
  }

  void cancelStreams() {
    transcriptSub?.cancel();
    transcriptSub = null;
    rmsSub?.cancel();
    rmsSub = null;
    stateSub?.cancel();
    stateSub = null;
    callEventSub?.cancel();
    callEventSub = null;
  }
}
