import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/native_bridge_interface.dart';
import 'package:lachancuocgoi_flutter/services/simulator_call_shield_bridge.dart';

void main() {
  group('SimulatorCallShieldBridge', () {
    test('emits transcript updates according to script using FakeAsync', () {
      fakeAsync((async) {
        final bridge = SimulatorCallShieldBridge();

        final transcripts = <TranscriptUpdate>[];
        final subscription = bridge.transcriptStream.listen((update) {
          transcripts.add(update);
        });

        // Start monitoring (which starts the 100ms periodic timer)
        bridge.startMonitoring();

        // The script emits full sentences every 100 ticks (10 seconds)
        // Advance time by 10 seconds (10000 ms)
        async.elapse(const Duration(seconds: 10));

        // It should have emitted the first sentence
        expect(transcripts.isNotEmpty, isTrue);
        expect(
          transcripts.last.text,
          contains('Cơ quan Cảnh sát điều tra Bộ Công an'),
        );
        expect(transcripts.last.isPartial, isFalse);

        // Advance by another 10 seconds for the second sentence
        async.elapse(const Duration(seconds: 10));
        expect(transcripts.last.text, contains('rửa tiền và buôn bán ma túy'));

        // Advance by enough time to get all 6 sentences (60 seconds total)
        async.elapse(const Duration(seconds: 40));

        expect(transcripts.last.text, contains('mở hồ sơ bảo lãnh tư pháp'));

        bridge.stopMonitoring();
        subscription.cancel();
        bridge.dispose();
      });
    });

    test('emits RMS audio levels', () {
      fakeAsync((async) {
        final bridge = SimulatorCallShieldBridge();

        final rmsValues = <double>[];
        final subscription = bridge.rmsStream.listen((rms) {
          rmsValues.add(rms);
        });

        bridge.startMonitoring();

        // Advance by 1 second (10 ticks)
        async.elapse(const Duration(seconds: 1));

        expect(rmsValues.length, 10);
        expect(rmsValues.first, greaterThanOrEqualTo(2.0));

        bridge.stopMonitoring();
        subscription.cancel();
        bridge.dispose();
      });
    });
  });
}
