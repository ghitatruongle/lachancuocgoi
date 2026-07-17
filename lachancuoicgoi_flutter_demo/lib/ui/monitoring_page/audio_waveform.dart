import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AudioWaveform extends StatelessWidget {
  const AudioWaveform({
    super.key,
    required this.amplitudes,
    required this.writeIndex,
    required this.elapsedSeconds,
  });

  final List<double> amplitudes;
  final int writeIndex;
  final ValueListenable<int> elapsedSeconds;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  _FlashingDot(),
                  SizedBox(width: 4),
                  _MonitoringLabel(),
                ],
              ),
              _ElapsedTimeDisplay(elapsedSeconds: elapsedSeconds),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(double.infinity, 60),
                painter: _WaveformPainter(
                  amplitudes: amplitudes,
                  writeIndex: writeIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitoringLabel extends StatelessWidget {
  const _MonitoringLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Đang giám sát',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.red,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _ElapsedTimeDisplay extends StatelessWidget {
  const _ElapsedTimeDisplay({required this.elapsedSeconds});

  final ValueListenable<int> elapsedSeconds;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<int>(
      valueListenable: elapsedSeconds,
      builder: (context, seconds, _) {
        final m = seconds ~/ 60;
        final s = seconds % 60;
        final formatted =
            '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
        return Text(
          formatted,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        );
      },
    );
  }
}

class _FlashingDot extends StatefulWidget {
  const _FlashingDot();

  @override
  State<_FlashingDot> createState() => _FlashingDotState();
}

class _FlashingDotState extends State<_FlashingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: _animation.value),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.amplitudes, required this.writeIndex});

  final List<double> amplitudes;
  final int writeIndex;

  static final Paint _paint = Paint()
    ..color = Colors.green
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final barCount = amplitudes.length;
    final barWidth = size.width / (2 * barCount).toDouble();
    final maxAmp = size.height / 2;

    _paint.strokeWidth = barWidth;

    for (var i = 0; i < barCount; i++) {
      final x = (i * 2 + 1) * barWidth;
      final bufferIndex = (writeIndex + i) % barCount;
      final amp = amplitudes[bufferIndex].clamp(0.0, 1.0) * maxAmp;
      canvas.drawLine(
        Offset(x, size.height / 2 - amp),
        Offset(x, size.height / 2 + amp),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) {
    return true; // Animator triggers this natively, always repaint when called.
  }
}
