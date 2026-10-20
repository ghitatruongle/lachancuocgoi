import '../native_bridge_interface.dart';

class SimulatorPermissionGate {
  Future<PermissionSnapshot> getSnapshot() async {
    return const PermissionSnapshot(
      recordAudio: true,
      phoneState: true,
      callLog: true,
      answerPhoneCalls: true,
      overlay: true,
      notification: true,
      accessibility: true,
      callScreening: true,
    );
  }
}
