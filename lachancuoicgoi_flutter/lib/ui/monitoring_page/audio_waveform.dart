import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AudioWaveform extends StatelessWidget {
  const AudioWaveform({
    super.key,
    required this.amplitudes,
    required this.elapsedSeconds,
  });

  final List<double> amplitudes;
  final ValueListenable<int> elapsedSeconds;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
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
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(double.infinity, 100),
                painter: _WaveformPainter(amplitudes: amplitudes),
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
  _WaveformPainter({required this.amplitudes});

  final List<double> amplitudes;

  static final Paint _paint = Paint()
    ..color = Colors.green
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final barCount = amplitudes.length;
    final barWidth = size.width / (2 * barCount - 1);
    final maxAmp = size.height / 2;

    _paint.strokeWidth = barWidth;

    for (var i = 0; i < barCount; i++) {
      final x = i * 2 * barWidth;
      final amp = amplitudes[i].clamp(0.0, 1.0) * maxAmp;
      canvas.drawLine(
        Offset(x, size.height / 2 - amp),
        Offset(x, size.height / 2 + amp),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) {
    if (old.amplitudes.length != amplitudes.length) return true;
    for (var i = 0; i < amplitudes.length; i++) {
      if ((old.amplitudes[i] - amplitudes[i]).abs() > 0.001) return true;
    }
    return false;
  }
}
