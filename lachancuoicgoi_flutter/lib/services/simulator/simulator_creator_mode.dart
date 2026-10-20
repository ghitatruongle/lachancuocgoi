import 'dart:async';

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

  final _controller = StreamController<String>.broadcast(sync: true);

  Stream<String> get transcriptStream => _controller.stream;

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

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    stop();
    await _controller.close();
  }
}
