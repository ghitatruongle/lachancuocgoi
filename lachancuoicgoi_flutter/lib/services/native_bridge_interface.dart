import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'android_call_shield_bridge.dart';
import 'bridge_models.dart';
import 'simulator_call_shield_bridge.dart';

export 'bridge_models.dart';

abstract class NativeBridgeInterface {
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

  Future<void> setCallScreeningBlockEnabled(bool enabled);
  Future<void> setBlockedNumbers(List<String> numbers);

  Stream<TranscriptUpdate> get transcriptStream;
  Stream<double> get rmsStream;
  Stream<(MonitoringState, int?, String?)> get monitoringStateStream;
  Stream<NativeCallEvent> get callEventStream;
  Stream<String> get logsStream;
}

abstract interface class TypedMonitoringStartBridge {
  Future<MonitoringStartResult> startMonitoringTyped({
    String? phoneNumber,
    bool enableSpeakerphone = false,
  });
}

abstract interface class AnalysisModeSyncBridge {
  Future<void> setAnalysisMode(String mode);
}

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
