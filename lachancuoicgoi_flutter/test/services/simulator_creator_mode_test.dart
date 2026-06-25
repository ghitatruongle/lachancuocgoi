import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/simulator/simulator_creator_mode.dart';

void main() {
  group('SimulatorCreatorMode', () {
    test('plays custom lines as cumulative transcript', () async {
      final mode = SimulatorCreatorMode(lines: const ['A.', 'B.', 'C.']);
      final emitted = <String>[];
      final sub = mode.transcriptStream.listen(emitted.add);
      await mode.play(tickIntervalMs: 1, sentenceIntervalTicks: 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      // Each commit appends the next line cumulatively.
      expect(emitted, containsAll(['A.', 'A. B.', 'A. B. C.']));
    });

    test('rejects empty line list', () {
      expect(() => SimulatorCreatorMode(lines: const []), throwsArgumentError);
    });

    test('stops cleanly and emits no more after stop()', () async {
      final mode = SimulatorCreatorMode(lines: const ['X.', 'Y.']);
      final emitted = <String>[];
      final sub = mode.transcriptStream.listen(emitted.add);
      await mode.play(tickIntervalMs: 1, sentenceIntervalTicks: 1);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      mode.stop();
      final countAfterStop = emitted.length;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(emitted.length, countAfterStop);
    });
  });
}
