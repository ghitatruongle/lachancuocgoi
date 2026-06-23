import 'dart:math' show max;

import 'package:flutter/foundation.dart' show ChangeNotifier;

/// Manages the circular buffer of RMS amplitudes for the audio waveform
/// visualization.
///
/// Extracted from [MonitoringController] to reduce class size.
class AudioAmplitudeHandler {
  AudioAmplitudeHandler();

  /// Circular buffer for RMS amplitudes.
  static const int amplitudeBufferSize = 30;
  final List<double> _amplitudes = List<double>.filled(amplitudeBufferSize, 0.1);
  int _amplitudeWriteIndex = 0;
  DateTime? _lastAmplitudeUpdate;
  double _peakAmplitude = 0.0;
  bool _hasReceivedAnyAudio = false;

  final _WaveformNotifier _waveformNotifier = _WaveformNotifier();

  /// Exposed for waveform widget.
  ChangeNotifier get waveformNotifier => _waveformNotifier;

  /// Notifies waveform listeners of amplitude changes.
  void notifyWaveform() => _waveformNotifier.notify();

  /// Read-only snapshot of the amplitude buffer.
  List<double> get amplitudes => _amplitudes;
  int get writeIndex => _amplitudeWriteIndex;
  double get peakAmplitude => _peakAmplitude;
  bool get hasReceivedAnyAudio => _hasReceivedAnyAudio;

  /// Updates the circular buffer with a new RMS value.
  /// Throttles to max 10 updates/second (100ms minimum interval).
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

  /// Resets all amplitude state for a new session.
  void reset() {
    for (var i = 0; i < amplitudeBufferSize; i++) {
      _amplitudes[i] = 0.1;
    }
    _amplitudeWriteIndex = 0;
    _lastAmplitudeUpdate = null;
    _peakAmplitude = 0.0;
    _hasReceivedAnyAudio = false;
  }

  /// Exposed for testing via [MonitoringController.debugSetAudioState].
  /// Package-internal; not intended for external use.
  void debugSetAudioState({
    required double peakAmplitude,
    required bool hasReceivedAnyAudio,
  }) {
    _peakAmplitude = peakAmplitude;
    _hasReceivedAnyAudio = hasReceivedAnyAudio;
  }
}

class _WaveformNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
