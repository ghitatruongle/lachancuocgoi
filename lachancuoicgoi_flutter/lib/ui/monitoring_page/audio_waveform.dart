import 'package:flutter/material.dart';

/// Animated audio waveform display with flashing recording dot and timer.
class AudioWaveform extends StatelessWidget {
  const AudioWaveform({
    super.key,
    required this.amplitudes,
    required this.elapsedSeconds,
  });

  final List<double> amplitudes;
  final int elapsedSeconds;

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
              Row(
                children: [
                  const _FlashingDot(),
                  const SizedBox(width: 4),
                  Text(
                    'Đang giám sát',
                    style: tt.bodySmall?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                _formatElapsedTime(elapsedSeconds),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: const Size(double.infinity, 100),
              painter: _WaveformPainter(amplitudes: amplitudes),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatElapsedTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final barWidth = size.width / (2 * amplitudes.length - 1);
    final maxAmp = size.height / 2;
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < amplitudes.length; i++) {
      final x = i * 2 * barWidth;
      final amp = amplitudes[i].clamp(0.0, 1.0) * maxAmp;
      canvas.drawLine(
        Offset(x, size.height / 2 - amp),
        Offset(x, size.height / 2 + amp),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => true;
}
