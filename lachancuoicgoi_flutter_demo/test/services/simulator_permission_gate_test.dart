import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/native_bridge_interface.dart';
import 'package:lachancuocgoi_flutter/services/simulator/simulator_permission_gate.dart';

void main() {
  group('SimulatorPermissionGate', () {
    test('returns allGranted snapshot on non-Android', () async {
      final gate = SimulatorPermissionGate();
      final snapshot = await gate.getSnapshot();
      expect(snapshot.allGranted, isTrue);
      expect(snapshot.grantedCount, PermissionSnapshot.totalPermissions);
    });

    test('returns equivalent snapshot each call', () async {
      final gate = SimulatorPermissionGate();
      final a = await gate.getSnapshot();
      final b = await gate.getSnapshot();
      expect(a, equals(b));
    });
  });
}
