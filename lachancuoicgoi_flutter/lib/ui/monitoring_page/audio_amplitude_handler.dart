import 'dart:math' show max;

import 'package:flutter/foundation.dart' show ChangeNotifier;

class AudioAmplitudeHandler {
  AudioAmplitudeHandler();

  static const int amplitudeBufferSize = 30;
  final List<double> _amplitudes = List<double>.filled(
    amplitudeBufferSize,
    0.1,
  );
  int _amplitudeWriteIndex = 0;
  DateTime? _lastAmplitudeUpdate;
  double _peakAmplitude = 0.0;
  bool _hasReceivedAnyAudio = false;

  final _WaveformNotifier _waveformNotifier = _WaveformNotifier();

  ChangeNotifier get waveformNotifier => _waveformNotifier;

  void notifyWaveform() => _waveformNotifier.notify();

  List<double> get amplitudes => _amplitudes;
  int get writeIndex => _amplitudeWriteIndex;
  double get peakAmplitude => _peakAmplitude;
  bool get hasReceivedAnyAudio => _hasReceivedAnyAudio;

  void handleRmsEvent(double rms) {
    final now = DateTime.now();
    if (_lastAmplitudeUpdate != null &&
        now.difference(_lastAmplitudeUpdate!).inMilliseconds < 100) {
      return;
    }
    _lastAmplitudeUpdate = now;
    if (rms > _peakAmplitude) _peakAmplitude = rms;
    _hasReceivedAnyAudio = true;
    final normalized = ((rms + 2.0) / 12.0).clamp(0.0, 1.0);
    _amplitudes[_amplitudeWriteIndex] = max(0.1, normalized);
    _amplitudeWriteIndex = (_amplitudeWriteIndex + 1) % amplitudeBufferSize;
    _waveformNotifier.notify();
  }

  void reset() {
    for (var i = 0; i < amplitudeBufferSize; i++) {
      _amplitudes[i] = 0.1;
    }
    _amplitudeWriteIndex = 0;
    _lastAmplitudeUpdate = null;
    _peakAmplitude = 0.0;
    _hasReceivedAnyAudio = false;
  }

  void debugSetAudioState({
    required double peakAmplitude,
    required bool hasReceivedAnyAudio,
  }) {
    _peakAmplitude = peakAmplitude;
    _hasReceivedAnyAudio = hasReceivedAnyAudio;
  }

  void dispose() {
    _waveformNotifier.dispose();
  }
}

class _WaveformNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
