import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/native_bridge_interface.dart';
import 'package:lachancuocgoi_flutter/services/simulator/simulator_scripts.dart';
import 'package:lachancuocgoi_flutter/services/simulator_call_shield_bridge.dart';

void main() {
  group('SimulatorCallShieldBridge', () {
    test('typed start and stop operations are idempotent', () async {
      final bridge = SimulatorCallShieldBridge();
      final states = <MonitoringState>[];
      final subscription = bridge.monitoringStateStream.listen(
        (event) => states.add(event.$1),
      );

      final first = await bridge.startMonitoringWithResult();
      final second = await bridge.startMonitoringWithResult();
      await bridge.stopMonitoring();
      await bridge.stopMonitoring();
      await Future<void>.delayed(Duration.zero);

      expect(first.status, MonitoringStartStatus.started);
      expect(second.status, MonitoringStartStatus.alreadyRunning);
      expect(
        states.where((state) => state == MonitoringState.started),
        hasLength(1),
      );
      expect(
        states.where((state) => state == MonitoringState.stopped),
        hasLength(1),
      );

      await subscription.cancel();
      bridge.dispose();
    });

    test('emits transcript updates according to script using FakeAsync', () {
      fakeAsync((async) {
        // Use a custom script so the test is independent of the default catalog.
        const script = SimulatorScript(
          id: 'test_police',
          title: 'Test police script',
          lines: [
            'Xin chào ông, tôi là cán bộ điều tra thuộc Cơ quan Cảnh sát điều tra Bộ Công an.',
            'Số điện thoại và tài khoản ngân hàng của ông đang bị nghi ngờ liên quan đến một đường dây rửa tiền và buôn bán ma túy quy mô lớn.',
            'Hãy đọc lại cho tôi mã xác thực OTP để hoàn tất thủ tục mở hồ sơ bảo lãnh tư pháp.',
          ],
        );
        final bridge = SimulatorCallShieldBridge(script: script);

        final transcripts = <TranscriptUpdate>[];
        final subscription = bridge.transcriptStream.listen((update) {
          transcripts.add(update);
        });

        // Start monitoring (which starts the 100ms periodic timer)
        bridge.startMonitoring();

        // The script emits full sentences every 100 ticks (10 seconds)
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

        // Advance by enough time to cycle through all 3 sentences
        async.elapse(const Duration(seconds: 10));
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

    test('uses catalog default script when no script provided', () {
      fakeAsync((async) {
        final bridge = SimulatorCallShieldBridge();

        final transcripts = <TranscriptUpdate>[];
        final subscription = bridge.transcriptStream.listen((update) {
          transcripts.add(update);
        });

        bridge.startMonitoring();
        async.elapse(const Duration(seconds: 10));

        // Default is bankFraud — should contain 'nhân viên ngân hàng'
        expect(transcripts.last.text, contains('nhân viên ngân hàng'));

        bridge.stopMonitoring();
        subscription.cancel();
        bridge.dispose();
      });
    });
  });
}
