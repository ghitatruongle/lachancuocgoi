import 'dart:async';
import '../../core/system_logger.dart';
import '../../services/native_call_shield_bridge.dart';
import 'monitoring_controller.dart';

class MonitoringStreamHandler {
  MonitoringStreamHandler(this.controller);

  final MonitoringController controller;

  StreamSubscription<TranscriptUpdate>? transcriptSub;
  StreamSubscription<double>? rmsSub;
  StreamSubscription<(MonitoringState, int?, String?)>? stateSub;
  StreamSubscription<NativeCallEvent>? callEventSub;
  StreamSubscription<String>? logsSub;
  bool streamsDead = false;

  void initStreams() {
    if (controller.isSimulationSession()) return;

    if (!streamsDead &&
        (transcriptSub != null ||
            rmsSub != null ||
            stateSub != null ||
            callEventSub != null ||
            logsSub != null)) {
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
        SystemLogger.instance.log(
          LogCategory.stt,
          'transcriptStream done — marking subscriptions dead.',
        );
        streamsDead = true;
        transcriptSub?.cancel();
        transcriptSub = null;
      },
      onError: (Object e, StackTrace st) {
        SystemLogger.instance.log(
          LogCategory.stt,
          'transcriptStream error: $e',
          level: LogLevel.error,
        );
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
        SystemLogger.instance.log(
          LogCategory.recording,
          'rmsStream done — marking subscriptions dead.',
        );
        streamsDead = true;
        rmsSub?.cancel();
        rmsSub = null;
      },
      onError: (Object e, StackTrace st) {
        SystemLogger.instance.log(
          LogCategory.recording,
          'rmsStream error: $e',
          level: LogLevel.error,
        );
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
        SystemLogger.instance.log(
          LogCategory.system,
          'monitoringStateStream done — marking subscriptions dead.',
        );
        streamsDead = true;
        stateSub?.cancel();
        stateSub = null;
      },
      onError: (Object e, StackTrace st) {
        SystemLogger.instance.log(
          LogCategory.system,
          'monitoringStateStream error: $e',
          level: LogLevel.error,
        );
        streamsDead = true;
        stateSub?.cancel();
        stateSub = null;
      },
    );

    callEventSub = bridge.callEventStream.listen(
      (event) {
        if (controller.disposed) return;
        if (event.numberAvailable &&
            event.maskedNumber != null &&
            event.maskedNumber!.isNotEmpty) {
          controller.maskedNumber = event.maskedNumber;
        }
      },
      onDone: () {
        if (controller.disposed) return;
        SystemLogger.instance.log(
          LogCategory.system,
          'callEventStream done — marking subscriptions dead.',
        );
        streamsDead = true;
        callEventSub?.cancel();
        callEventSub = null;
      },
      onError: (Object e, StackTrace st) {
        SystemLogger.instance.log(
          LogCategory.system,
          'callEventStream error: $e',
          level: LogLevel.error,
        );
        streamsDead = true;
        callEventSub?.cancel();
        callEventSub = null;
      },
    );

    logsSub = bridge.logsStream.listen(
      (rawLog) {
        if (controller.disposed) return;
        final parts = rawLog.split('|');
        if (parts.length >= 3) {
          final levelStr = parts[0].toUpperCase();
          final tagStr = parts[1];
          final message = parts.sublist(2).join('|');

          LogLevel level = LogLevel.info;
          if (levelStr == 'WARN' || levelStr == 'WARNING') {
            level = LogLevel.warning;
          } else if (levelStr == 'ERROR') {
            level = LogLevel.error;
          }

          LogCategory category = LogCategory.system;
          if (tagStr.contains('Vosk') ||
              tagStr.contains('Model') ||
              tagStr.contains('gemini') ||
              tagStr.contains('Gemini')) {
            category = LogCategory.model;
          } else if (tagStr.contains('Speech') || tagStr.contains('STT')) {
            category = LogCategory.stt;
          } else if (tagStr.contains('Capture') ||
              tagStr.contains('Audio') ||
              tagStr.contains('Service')) {
            category = LogCategory.recording;
          }

          SystemLogger.instance.log(category, message, level: level);
        }
      },
      onDone: () {
        if (controller.disposed) return;
        SystemLogger.instance.log(LogCategory.system, 'logsStream done.');
        logsSub?.cancel();
        logsSub = null;
      },
      onError: (Object e, StackTrace st) {
        SystemLogger.instance.log(
          LogCategory.system,
          'logsStream error: $e',
          level: LogLevel.error,
        );
        logsSub?.cancel();
        logsSub = null;
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
    logsSub?.cancel();
    logsSub = null;
  }
}
