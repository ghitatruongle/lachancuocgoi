import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

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
  Stream<NativeCallEvent> get callEventStream;
  Stream<String> get logsStream;
}

/// Optional v1.6 capability implemented by bridges that understand the typed
/// native start-result wire schema.
abstract interface class TypedMonitoringStartBridge {
  Future<MonitoringStartResult> startMonitoringTyped({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  });
}

/// Optional capability used to mirror the selected analysis mode to the
/// Android process. Simulator/test bridges can omit it safely.
abstract interface class AnalysisModeSyncBridge {
  Future<void> setAnalysisMode(String mode);
}

/// Optional capability that mirrors the user's speakerphone preference into
/// the Android process. This is needed when monitoring starts from a native
/// incoming-call notification before Flutter has a visible Activity.
abstract interface class SpeakerphonePreferenceSyncBridge {
  Future<void> setAutoEnableSpeakerphone(bool enabled);
}

extension NativeBridgeAnalysisModeSync on NativeBridgeInterface {
  Future<void> syncAnalysisMode(String mode) async {
    final bridge = this;
    if (bridge case final AnalysisModeSyncBridge syncBridge) {
      await syncBridge.setAnalysisMode(mode);
    }
  }
}

extension NativeBridgeSpeakerphonePreferenceSync on NativeBridgeInterface {
  Future<void> syncAutoEnableSpeakerphone(bool enabled) async {
    final bridge = this;
    if (bridge case final SpeakerphonePreferenceSyncBridge syncBridge) {
      await syncBridge.setAutoEnableSpeakerphone(enabled);
    }
  }
}

/// Typed adapter that keeps existing `NativeBridgeInterface` fakes compatible.
/// Dart's `implements` does not inherit concrete methods, so making the new
/// method part of the original interface would break every legacy embedder.
extension NativeBridgeTypedMonitoringStart on NativeBridgeInterface {
  Future<MonitoringStartResult> startMonitoringWithResult({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  }) async {
    final bridge = this;
    if (bridge case final TypedMonitoringStartBridge typedBridge) {
      return typedBridge.startMonitoringTyped(
        phoneNumber: phoneNumber,
        enableSpeakerphone: enableSpeakerphone,
      );
    }
    final legacyResult = await bridge.startMonitoring(
      phoneNumber: phoneNumber,
      enableSpeakerphone: enableSpeakerphone,
    );
    return MonitoringStartResult.fromNative(legacyResult);
  }
}
