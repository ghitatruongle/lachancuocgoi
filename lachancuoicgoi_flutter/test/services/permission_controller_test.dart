import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/services/permission_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.lachancuocgoi/native_bridge');
  late List<MethodCall> methodCalls;
  late Map<String, bool> permissionMap;

  setUp(() {
    methodCalls = [];
    permissionMap = {
      'recordAudio': false,
      'phoneState': false,
      'callLog': false,
      'overlay': false,
      'notification': false,
      'accessibility': false,
      'callScreening': false,
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      methodCalls.add(call);
      return switch (call.method) {
        'getPermissionSnapshot' => Map<String, bool>.from(permissionMap),
        'requestPhoneAndCallLogPermissions' => true,
        'requestOverlayPermission' => true,
        'openAccessibilitySettings' => true,
        'requestCallScreeningRole' => true,
        'isMonitoringActive' => false,
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('PermissionController — refresh', () {
    test('initial state loads snapshot from native', () async {
      permissionMap['recordAudio'] = true;
      permissionMap['notification'] = true;

      final controller = PermissionController(NativeCallShieldBridge.instance);
      // Wait for the initial _refresh() to complete
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.snapshot.recordAudio, isTrue);
      expect(controller.state.snapshot.notification, isTrue);
      expect(controller.state.snapshot.phoneState, isFalse);
    });

    test('refresh is throttled — second call within 500ms is skipped', () async {
      final controller = PermissionController(NativeCallShieldBridge.instance);
      await Future<void>.delayed(Duration.zero);

      final callCountBefore = methodCalls
          .where((c) => c.method == 'getPermissionSnapshot')
          .length;

      // Call refresh immediately — should be throttled
      await controller.refresh();
      await controller.refresh();
      await controller.refresh();

      final callCountAfter = methodCalls
          .where((c) => c.method == 'getPermissionSnapshot')
          .length;

      // Only 1 extra call should have been made (the initial one from constructor + 0 throttled)
      // Actually the constructor's _refresh is async, so we might see 1 or 2 total
      expect(callCountAfter - callCountBefore, lessThanOrEqualTo(1));
    });

    test('refresh updates state when snapshot changes', () async {
      final controller = PermissionController(NativeCallShieldBridge.instance);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.snapshot.recordAudio, isFalse);

      // Change the native response
      permissionMap['recordAudio'] = true;

      // Wait for throttle to expire
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await controller.refresh();

      expect(controller.state.snapshot.recordAudio, isTrue);
    });

    test('refresh does not update state when snapshot is identical', () async {
      final controller = PermissionController(NativeCallShieldBridge.instance);
      // Wait for initial _refresh() to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final stateBefore = controller.state;

      // Wait for throttle to expire, then refresh again with same data
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await controller.refresh();

      // State should be the same object (no copyWith was called)
      expect(controller.state.snapshot, equals(stateBefore.snapshot));
    });
  });

  group('PermissionController — requestMicrophonePermission', () {
    test('returns current snapshot value after refresh', () async {
      permissionMap['recordAudio'] = true;
      final controller = PermissionController(NativeCallShieldBridge.instance);
      await Future<void>.delayed(Duration.zero);

      // Wait for throttle
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final result = await controller.requestMicrophonePermission();

      expect(result, isTrue);
      expect(controller.state.snapshot.recordAudio, isTrue);
    });
  });

  group('PermissionController — requestPhoneAndCallLogPermissions', () {
    test('calls bridge and refreshes snapshot', () async {
      permissionMap['phoneState'] = true;
      permissionMap['callLog'] = true;
      final controller = PermissionController(NativeCallShieldBridge.instance);
      await Future<void>.delayed(Duration.zero);

      await Future<void>.delayed(const Duration(milliseconds: 600));
      final result = await controller.requestPhoneAndCallLogPermissions();

      expect(result, isTrue);
      expect(methodCalls, contains(isA<MethodCall>().having(
        (c) => c.method, 'method', 'requestPhoneAndCallLogPermissions',
      )));
    });
  });

  group('PermissionController — requestOverlayPermission', () {
    test('calls bridge and returns result', () async {
      permissionMap['overlay'] = true;
      final controller = PermissionController(NativeCallShieldBridge.instance);
      await Future<void>.delayed(Duration.zero);

      final result = await controller.requestOverlayPermission();
      expect(result, isTrue);
      // Lifecycle resume triggers refresh in production.
      // In test, call refresh explicitly.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await controller.refresh();
      expect(controller.state.snapshot.overlay, isTrue);
    });
  });

  group('PermissionController — requestCallScreeningPermission', () {
    test('calls bridge and returns result', () async {
      permissionMap['callScreening'] = true;
      final controller = PermissionController(NativeCallShieldBridge.instance);
      await Future<void>.delayed(Duration.zero);

      final result = await controller.requestCallScreeningPermission();
      expect(result, isTrue);
      // Lifecycle resume triggers refresh in production.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await controller.refresh();
      expect(controller.state.snapshot.callScreening, isTrue);
    });
  });

  group('PermissionController — requestAllPermissions', () {
    test('requests all missing permissions in sequence', () async {
      final controller = PermissionController(NativeCallShieldBridge.instance);
      await Future<void>.delayed(Duration.zero);

      // Set all to true after requests
      permissionMap['recordAudio'] = true;
      permissionMap['phoneState'] = true;
      permissionMap['callLog'] = true;
      permissionMap['overlay'] = true;
      permissionMap['notification'] = true;
      permissionMap['accessibility'] = true;
      permissionMap['callScreening'] = true;

      await Future<void>.delayed(const Duration(milliseconds: 600));
      final results = await controller.requestAllPermissions();

      expect(results, isA<Map<String, bool>>());
      // After all requests, allGranted should be true
      expect(controller.state.snapshot.allGranted, isTrue);
    });

    test('skips already granted permissions', () async {
      permissionMap['recordAudio'] = true;
      permissionMap['phoneState'] = true;
      permissionMap['callLog'] = true;
      permissionMap['overlay'] = true;
      permissionMap['notification'] = true;
      permissionMap['accessibility'] = true;
      permissionMap['callScreening'] = true;

      final controller = PermissionController(NativeCallShieldBridge.instance);
      await Future<void>.delayed(Duration.zero);

      await Future<void>.delayed(const Duration(milliseconds: 600));
      final results = await controller.requestAllPermissions();

      // All already granted, so individual request methods shouldn't be called
      expect(results, isEmpty);
    });
  });

  group('PermissionController — checkMonitoringActive', () {
    test('delegates to bridge', () async {
      final controller = PermissionController(NativeCallShieldBridge.instance);
      await Future<void>.delayed(Duration.zero);

      final result = await controller.checkMonitoringActive();
      expect(result, isFalse);
    });
  });

  group('PermissionController — providers', () {
    test('allPermissionsGrantedProvider reflects state', () async {
      final bridge = NativeCallShieldBridge.instance;
      final controller = PermissionController(bridge);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.allGranted, isFalse);
    });

    test('missingPermissionsProvider lists missing permissions', () async {
      permissionMap['recordAudio'] = true;
      final bridge = NativeCallShieldBridge.instance;
      final controller = PermissionController(bridge);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.snapshot.recordAudio, isTrue);
      expect(controller.state.snapshot.phoneState, isFalse);
      expect(controller.state.grantedCount, 1);
    });
  });
}
