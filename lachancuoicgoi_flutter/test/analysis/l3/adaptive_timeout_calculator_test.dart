import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/adaptive_timeout_calculator.dart';

void main() {
  group('AdaptiveTimeoutCalculator Unit Tests', () {
    test('Initializes with default timeout within bounds', () {
      final calc = AdaptiveTimeoutCalculator(initialTimeoutMs: 1000);
      expect(calc.calculateTimeoutMs(), equals(1700));
      expect(calc.sampleCount, equals(0));
    });

    test('Updates RTT smoothly with EMA samples', () {
      final calc = AdaptiveTimeoutCalculator(initialTimeoutMs: 1000);
      calc.recordSample(400);
      expect(calc.currentRttMs, equals(400.0));

      calc.recordSample(600);
      expect(calc.currentRttMs, equals(460.0));
      expect(calc.calculateTimeoutMs(), equals(890));
    });

    test('Clamps calculated timeout to min and max boundaries', () {
      final calc = AdaptiveTimeoutCalculator(
        minTimeoutMs: 600,
        maxTimeoutMs: 2500,
      );

      calc.recordSample(100);
      expect(calc.calculateTimeoutMs(), equals(600));

      calc.recordSample(3000);
      calc.recordSample(3000);
      expect(calc.calculateTimeoutMs(), equals(2500));
    });

    test('Reset clears sample count and restores initial RTT', () {
      final calc = AdaptiveTimeoutCalculator(initialTimeoutMs: 1000);
      calc.recordSample(500);
      expect(calc.sampleCount, equals(1));

      calc.reset(initialTimeoutMs: 1200);
      expect(calc.sampleCount, equals(0));
      expect(calc.currentRttMs, equals(1200.0));
    });
  });
}
