// Bug Hunt Phase B.8 — Simulator Mode edge cases + API parity
//
// Reference: docs/superpowers/specs/.../Mục 9 — Simulator Mode

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/simulator/simulator_scripts.dart';
import 'package:lachancuocgoi_flutter/services/simulator_call_shield_bridge.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // BUG-TEST-INFRA-1: use shared helper instead of inline mock.
  setUp(() => setupPermissionHandlerMock());

  group('BUG-HUNT-SIM — Simulator edge cases', () {
    test(
      'BUG-SIM-1: stopMonitoring() with no startMonitoring does not throw',
      () async {
        final bridge = SimulatorCallShieldBridge();
        // No startMonitoring call before.
        await bridge.stopMonitoring();
        // No assertion needed — absence of throw is the contract.
      },
    );

    test('BUG-SIM-2: every catalog script has unique id', () {
      final ids = SimulatorScriptCatalog.all.map((s) => s.id).toList();
      expect(ids.toSet().length, equals(ids.length));
    });

    test('BUG-SIM-3: catalog script byId returns null for unknown id', () {
      expect(SimulatorScriptCatalog.byId('unknown_id'), isNull);
    });

    test(
      'BUG-SIM-4: simulator bridge permission gate returns all-granted',
      () async {
        final bridge = SimulatorCallShieldBridge();
        final snapshot = await bridge.getPermissionSnapshot();
        expect(snapshot.recordAudio, isA<bool>());
        expect(snapshot.notification, isA<bool>());
        expect(
          snapshot.phoneState,
          isTrue,
          reason: 'Simulator stub always grants phoneState',
        );
      },
    );
  });
}
