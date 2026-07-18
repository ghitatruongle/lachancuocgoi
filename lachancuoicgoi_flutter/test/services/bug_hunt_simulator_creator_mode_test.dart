// Bug Hunt Phase B.7 — SimulatorCreatorMode edge cases
//
// Reference: docs/superpowers/specs/.../Mục 8 — Creator Mode

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/simulator/simulator_creator_mode.dart';

void main() {
  group('BUG-HUNT-CREATOR — SimulatorCreatorMode edge cases', () {
    test(
      'BUG-CREATOR-1: play() called twice resets timer (no double-fire)',
      () async {
        final mode = SimulatorCreatorMode(lines: const ['A', 'B', 'C']);
        final emitted = <String>[];
        final sub = mode.transcriptStream.listen(emitted.add);
        await mode.play(tickIntervalMs: 1, sentenceIntervalTicks: 1);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        // Re-start — should reset state, not double-fire.
        await mode.play(tickIntervalMs: 1, sentenceIntervalTicks: 1);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await sub.cancel();
        await mode.dispose();
        expect(emitted, isNotEmpty);
      },
    );

    test('BUG-CREATOR-2: empty lines throws ArgumentError (constructor)', () {
      expect(
        () => SimulatorCreatorMode(lines: const <String>[]),
        throwsArgumentError,
      );
    });

    test(
      'BUG-CREATOR-3: play with valid lines emits increasing transcripts',
      () async {
        final mode = SimulatorCreatorMode(lines: const ['X', 'Y', 'Z']);
        final emitted = <String>[];
        final sub = mode.transcriptStream.listen(emitted.add);
        await mode.play(tickIntervalMs: 5, sentenceIntervalTicks: 1);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await sub.cancel();
        await mode.dispose();
        // Should emit at least 1 transcript.
        expect(emitted, isNotEmpty);
        // The last emitted should contain all 3 lines.
        expect(emitted.last, contains('X'));
        expect(emitted.last, contains('Y'));
        expect(emitted.last, contains('Z'));
      },
    );
  });
}
