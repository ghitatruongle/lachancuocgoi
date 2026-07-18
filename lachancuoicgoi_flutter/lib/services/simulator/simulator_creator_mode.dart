import 'dart:async';

/// Replays a user-supplied list of transcript lines on a timer, emitting
/// cumulative transcript strings — the same pattern as the iOS/Desktop
/// simulator bridge, but driven by custom input instead of a hard-coded
/// script.
///
/// This lets users test the analysis pipeline against any scenario they
/// write, without needing real STT (which is unavailable on non-Android
/// platforms).
class SimulatorCreatorMode {
  SimulatorCreatorMode({required List<String> lines})
    : _lines = List<String>.unmodifiable(lines) {
    if (_lines.isEmpty) {
      throw ArgumentError.value(
        lines,
        'lines',
        'SimulatorCreatorMode requires at least one line.',
      );
    }
  }

  final List<String> _lines;
  Timer? _timer;
  int _currentLineIndex = 0;
  // Deliver timer emissions synchronously so stop() forms a strict boundary:
  // after it returns there is no already-queued transcript callback that can
  // arrive later and make the simulator appear to keep running.
  final _controller = StreamController<String>.broadcast(sync: true);

  /// Stream of cumulative transcript strings (line 0, then 0+1, then 0+1+2…).
  Stream<String> get transcriptStream => _controller.stream;

  /// Starts replaying lines on a periodic timer.
  ///
  /// [tickIntervalMs] — how often the timer fires.
  /// [sentenceIntervalTicks] — how many ticks between committing the next
  /// line (e.g. 100 ticks = one line every 10s at 100ms/tick).
  Future<void> play({
    required int tickIntervalMs,
    required int sentenceIntervalTicks,
  }) async {
    _currentLineIndex = 0;
    _timer?.cancel();
    var tickCount = 0;
    _timer = Timer.periodic(Duration(milliseconds: tickIntervalMs), (timer) {
      tickCount++;
      if (tickCount % sentenceIntervalTicks != 0) return;
      if (_currentLineIndex >= _lines.length) {
        timer.cancel();
        return;
      }
      _currentLineIndex++;
      final cumulative = _lines.take(_currentLineIndex).join(' ');
      _controller.add(cumulative);
    });
  }

  /// Stops the timer. No further events are emitted.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Releases resources.
  Future<void> dispose() async {
    stop();
    await _controller.close();
  }
}
