import '../native_bridge_interface.dart';

/// No-op permission gate for the non-Android simulator.
///
/// On iOS/Desktop/Web, the simulator doesn't need real OS permissions —
/// there's no native STT, overlay, or call screening. This gate always
/// reports [PermissionSnapshot.allGranted] = `true` so the UI contract
/// stays consistent across platforms (the UI doesn't need special-casing
/// for simulator mode).
class SimulatorPermissionGate {
  /// Returns a snapshot with all permissions granted.
  Future<PermissionSnapshot> getSnapshot() async {
    return const PermissionSnapshot(
      recordAudio: true,
      phoneState: true,
      callLog: true,
      overlay: true,
      notification: true,
      accessibility: true,
      callScreening: true,
    );
  }
}
