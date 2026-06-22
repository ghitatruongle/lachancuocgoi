import 'dart:async';
import 'dart:math';
import 'monitoring_controller.dart';

class MonitoringSimulationHelper {
  MonitoringSimulationHelper(this.controller) : simRandom = Random(42);

  final MonitoringController controller;
  Timer? _simulationPlaybackTimer;
  int currentScriptLineIndex = 0;
  final Random simRandom;

  void startSimulationPlayback(List<Map<String, dynamic>> scriptLines) {
    currentScriptLineIndex = 0;
    _simulationPlaybackTimer?.cancel();

    void scheduleNext() {
      if (currentScriptLineIndex >= scriptLines.length || controller.disposed) return;

      final line = scriptLines[currentScriptLineIndex];
      final delay = (line['delay'] as num?)?.toInt() ?? 2000;
      final speaker = line['speaker'] as String? ?? '';
      final text = line['line'] as String? ?? '';

      _simulationPlaybackTimer = Timer(
        Duration(milliseconds: max(delay, 100)),
        () {
          if (controller.disposed) return;
          final current = controller.currentState.transcript;
          final lineText = '$speaker: $text';
          controller.updateTranscriptFromSimulation(
            current.isEmpty ? lineText : '$current\n$lineText',
          );
          updateSimulationWaveform();
          currentScriptLineIndex++;
          scheduleNext();
        },
      );
    }

    scheduleNext();
  }

  void stopSimulationPlayback() {
    _simulationPlaybackTimer?.cancel();
    _simulationPlaybackTimer = null;
  }

  void updateSimulationWaveform() {
    for (var i = 0; i < MonitoringController.amplitudeBufferSize; i++) {
      controller.amplitudes[i] = simRandom.nextDouble() * 0.6 + 0.2;
    }
    controller.notifyWaveform();
  }
}
