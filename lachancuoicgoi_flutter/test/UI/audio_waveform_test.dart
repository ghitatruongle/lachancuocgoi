import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/audio_waveform.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_state.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AudioWaveform', () {
    testWidgets('renders with zero amplitudes', (tester) async {
      await tester.pumpWidget(
        wrap(
          AudioWaveform(
            amplitudes: List.filled(30, 0.1),
            writeIndex: 0,
            elapsedSeconds: _constNotifier(0),
          ),
        ),
      );

      expect(find.text('Đang giám sát'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('renders with varying amplitudes', (tester) async {
      final amplitudes = List.generate(30, (i) => 0.1 + (i / 30) * 0.9);
      await tester.pumpWidget(
        wrap(
          AudioWaveform(
            amplitudes: amplitudes,
            writeIndex: 0,
            elapsedSeconds: _constNotifier(5),
          ),
        ),
      );

      expect(find.text('Đang giám sát'), findsOneWidget);
      expect(find.text('00:05'), findsOneWidget);
    });

    testWidgets('displays elapsed time correctly', (tester) async {
      await tester.pumpWidget(
        wrap(
          AudioWaveform(
            amplitudes: List.filled(30, 0.1),
            writeIndex: 0,
            elapsedSeconds: _constNotifier(125),
          ),
        ),
      );

      expect(find.text('02:05'), findsOneWidget);
    });

    testWidgets('has a CustomPaint for waveform', (tester) async {
      await tester.pumpWidget(
        wrap(
          AudioWaveform(
            amplitudes: List.filled(30, 0.1),
            writeIndex: 0,
            elapsedSeconds: _constNotifier(0),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('does not claim monitoring is active after start failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          AudioWaveform(
            amplitudes: List.filled(30, 0.0),
            writeIndex: 0,
            elapsedSeconds: _constNotifier(0),
            phase: MonitoringPhase.failed,
          ),
        ),
      );

      expect(find.text('Giám sát chưa hoạt động'), findsOneWidget);
      expect(find.text('Đang giám sát'), findsNothing);
    });
  });
}

ValueNotifier<int> _constNotifier(int value) => ValueNotifier<int>(value);
