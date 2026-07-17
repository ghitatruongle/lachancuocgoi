import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'android_call_shield_bridge.dart';
import 'bridge_models.dart';
import 'simulator_call_shield_bridge.dart';

export 'bridge_models.dart';

/// Abstract interface for the native bridge.
///
/// Allows faking the bridge in tests without touching EventChannels.
abstract class NativeBridgeInterface {
  /// Phase 2 (P2-8): Factory that selects the correct bridge implementation
  /// for the current platform. On Android it returns [AndroidCallShieldBridge]
  /// (production native bridge with timeout-hardened MethodChannel calls). On
  /// all other platforms (iOS, Web, Desktop) it returns
  /// [SimulatorCallShieldBridge] which runs scripted scam-call scenarios so the
  /// AI pipeline can be demoed without real call interception.
  ///
  /// This replaces the previous monolithic [NativeCallShieldBridge] which
  /// contained both Android and simulation code in one class, causing drift
  /// between the two code paths.
  static NativeBridgeInterface create() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidCallShieldBridge();
    }
    return SimulatorCallShieldBridge();
  }

  Future<bool> startMonitoring({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  });
  Future<bool> stopMonitoring();
  Future<bool> startCreatorMonitoring({required int devModeExpiresAtMs});
  Future<bool> stopCreatorMonitoring();
  Future<bool> showRedAlert(String reason);
  Future<bool> showOrangeAlert(String reason);
  Future<bool> dismissAlert();
  Future<PermissionSnapshot> getPermissionSnapshot();
  Future<bool> openAccessibilitySettings();
  Future<bool> requestCallScreeningRole();
  Future<bool> requestPhoneAndCallLogPermissions();
  Future<bool> checkOverlayPermission();
  Future<bool> requestOverlayPermission();
  Future<bool> isMonitoringActive();
  Future<bool> isCreatorMonitoringActive();
  Future<void> showIncomingCallOverlay(String callerInfo);
  Future<void> dismissIncomingCallOverlay();

  // Phase 2 (P2-4): Call screening opt-in — block/reject known scam numbers.
  Future<void> setCallScreeningBlockEnabled(bool enabled);
  Future<void> setBlockedNumbers(List<String> numbers);

  Stream<TranscriptUpdate> get transcriptStream;
  Stream<double> get rmsStream;
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream;
  Stream<CallEvent> get callEventStream;
  Stream<String> get logsStream;
}
