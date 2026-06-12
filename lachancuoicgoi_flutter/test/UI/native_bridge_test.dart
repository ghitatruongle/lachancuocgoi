import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NativeCallShieldBridge bridge;
  late List<MethodCall> methodCalls;

  const methodChannel = MethodChannel('com.lachancuocgoi/native_bridge');

  setUp(() {
    bridge = NativeCallShieldBridge.instance;
    methodCalls = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          methodCalls.add(call);
          return switch (call.method) {
            'startMonitoring' => true,
            'stopMonitoring' => true,
            'showRedAlert' => true,
            'showOrangeAlert' => true,
            'dismissAlert' => true,
            'getPermissionSnapshot' => <String, bool>{
              'recordAudio': true,
              'phoneState': true,
              'callLog': false,
              'overlay': true,
              'notification': true,
              'accessibility': false,
              'callScreening': true,
            },
            'openAccessibilitySettings' => true,
            'requestCallScreeningRole' => true,
            'checkOverlayPermission' => true,
            'requestOverlayPermission' => true,
            'isAccessibilityEnabled' => false,
            'isMonitoringActive' => false,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('NativeCallShieldBridge — MethodChannel', () {
    test('startMonitoring uses default arguments when omitted', () async {
      final result = await bridge.startMonitoring();

      expect(result, isTrue);
      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, 'startMonitoring');
      expect(
        methodCalls.first.arguments,
        equals({'phoneNumber': null, 'enableSpeakerphone': false}),
      );
    });

    test('startMonitoring sends correct arguments', () async {
      final result = await bridge.startMonitoring(
        phoneNumber: '+84912345678',
        enableSpeakerphone: true,
      );

      expect(result, isTrue);
      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, 'startMonitoring');
      expect(
        methodCalls.first.arguments,
        equals({'phoneNumber': '+84912345678', 'enableSpeakerphone': true}),
      );
    });

    test('stopMonitoring sends correct method', () async {
      final result = await bridge.stopMonitoring();

      expect(result, isTrue);
      expect(methodCalls.first.method, 'stopMonitoring');
    });

    test('showRedAlert sends reason argument', () async {
      final result = await bridge.showRedAlert('Đã phát hiện lừa đảo!');

      expect(result, isTrue);
      expect(methodCalls.first.method, 'showRedAlert');
      expect(methodCalls.first.arguments, {'reason': 'Đã phát hiện lừa đảo!'});
    });

    test('showOrangeAlert sends reason argument', () async {
      final result = await bridge.showOrangeAlert('Có nguy cơ lừa đảo.');

      expect(result, isTrue);
      expect(methodCalls.first.method, 'showOrangeAlert');
      expect(methodCalls.first.arguments, {'reason': 'Có nguy cơ lừa đảo.'});
    });

    test('dismissAlert calls correct method', () async {
      final result = await bridge.dismissAlert();
      expect(result, isTrue);
      expect(methodCalls.first.method, 'dismissAlert');
    });

    test(
      'getPermissionSnapshot falls back to defaults when native returns null',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methodChannel, (call) async {
              methodCalls.add(call);
              if (call.method == 'getPermissionSnapshot') {
                return null;
              }
              return true;
            });

        final snapshot = await bridge.getPermissionSnapshot();

        expect(snapshot.allGranted, isFalse);
        expect(snapshot.grantedCount, 0);
      },
    );

    test('getPermissionSnapshot parses map correctly', () async {
      final snapshot = await bridge.getPermissionSnapshot();

      expect(snapshot.recordAudio, isTrue);
      expect(snapshot.phoneState, isTrue);
      expect(snapshot.callLog, isFalse);
      expect(snapshot.overlay, isTrue);
      expect(snapshot.notification, isTrue);
      expect(snapshot.accessibility, isFalse);
      expect(snapshot.callScreening, isTrue);
      expect(snapshot.allGranted, isFalse);
      expect(snapshot.grantedCount, 5);
    });

    test('openAccessibilitySettings calls method', () async {
      final result = await bridge.openAccessibilitySettings();
      expect(result, isTrue);
      expect(methodCalls.first.method, 'openAccessibilitySettings');
    });

    test('requestCallScreeningRole calls method', () async {
      final result = await bridge.requestCallScreeningRole();
      expect(result, isTrue);
      expect(methodCalls.first.method, 'requestCallScreeningRole');
    });

    test('checkOverlayPermission returns true', () async {
      final result = await bridge.checkOverlayPermission();
      expect(result, isTrue);
    });

    test('requestOverlayPermission calls method', () async {
      final result = await bridge.requestOverlayPermission();
      expect(result, isTrue);
    });

    test('isAccessibilityEnabled returns false', () async {
      final result = await bridge.isAccessibilityEnabled();
      expect(result, isFalse);
    });

    test('isMonitoringActive returns false', () async {
      final result = await bridge.isMonitoringActive();
      expect(result, isFalse);
    });

    test('handles PlatformException gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            throw PlatformException(code: 'ERROR', message: 'Test error');
          });

      final result = await bridge.startMonitoring();
      expect(result, isFalse);

      final snapshot = await bridge.getPermissionSnapshot();
      expect(snapshot.allGranted, isFalse);
    });

    test('startCreatorMonitoring sends devModeExpiresAtMs argument', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            methodCalls.add(call);
            return true;
          });

      final result = await bridge.startCreatorMonitoring(
        devModeExpiresAtMs: 1700000000000,
      );

      expect(result, isTrue);
      expect(methodCalls.last.method, 'startCreatorMonitoring');
      expect(
        methodCalls.last.arguments,
        equals({'devModeExpiresAtMs': 1700000000000}),
      );
    });

    test('startCreatorMonitoring returns false on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            throw PlatformException(code: 'ERROR', message: 'Test error');
          });

      final result = await bridge.startCreatorMonitoring(
        devModeExpiresAtMs: 0,
      );
      expect(result, isFalse);
    });

    test('stopCreatorMonitoring calls correct method', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            methodCalls.add(call);
            return true;
          });

      final result = await bridge.stopCreatorMonitoring();
      expect(result, isTrue);
      expect(methodCalls.last.method, 'stopCreatorMonitoring');
    });

    test('stopCreatorMonitoring returns false on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            throw PlatformException(code: 'ERROR', message: 'Test error');
          });

      final result = await bridge.stopCreatorMonitoring();
      expect(result, isFalse);
    });

    test('isCreatorMonitoringActive returns native value', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            methodCalls.add(call);
            if (call.method == 'isCreatorMonitoringActive') return true;
            return null;
          });

      final result = await bridge.isCreatorMonitoringActive();
      expect(result, isTrue);
      expect(methodCalls.last.method, 'isCreatorMonitoringActive');
    });

    test('isCreatorMonitoringActive returns false on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            throw PlatformException(code: 'ERROR', message: 'Test error');
          });

      final result = await bridge.isCreatorMonitoringActive();
      expect(result, isFalse);
    });

    test('requestPhoneAndCallLogPermissions calls correct method', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            methodCalls.add(call);
            return true;
          });

      final result = await bridge.requestPhoneAndCallLogPermissions();
      expect(result, isTrue);
      expect(methodCalls.last.method, 'requestPhoneAndCallLogPermissions');
    });

    test('requestPhoneAndCallLogPermissions returns false on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            throw PlatformException(code: 'ERROR', message: 'Test error');
          });

      final result = await bridge.requestPhoneAndCallLogPermissions();
      expect(result, isFalse);
    });

    test('startCreatorMonitoring returns false when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            methodCalls.add(call);
            return null;
          });

      final result = await bridge.startCreatorMonitoring(
        devModeExpiresAtMs: 0,
      );
      expect(result, isFalse);
    });
  });

  group('NativeCallShieldBridge — Data Models', () {
    test('MonitoringState falls back to idle for unknown value', () {
      final (state, duration, transcript) = MonitoringState.parse(
        'SOMETHING_ELSE',
      );
      expect(state, MonitoringState.idle);
      expect(duration, isNull);
      expect(transcript, isNull);
    });

    test('MonitoringState parses STARTED', () {
      final (state, duration, transcript) = MonitoringState.parse('STARTED');
      expect(state, MonitoringState.started);
      expect(duration, isNull);
      expect(transcript, isNull);
    });

    test('MonitoringState parses STOPPED with data', () {
      final (state, duration, transcript) = MonitoringState.parse(
        'STOPPED:120:Xin chào anh',
      );
      expect(state, MonitoringState.stopped);
      expect(duration, 120);
      expect(transcript, 'Xin chào anh');
    });

    test('MonitoringState parses STOPPED with colons in transcript', () {
      final (state, duration, transcript) = MonitoringState.parse(
        'STOPPED:60:Anh ơi: bước tiếp theo',
      );
      expect(state, MonitoringState.stopped);
      expect(duration, 60);
      expect(transcript, 'Anh ơi: bước tiếp theo');
    });

    test('MonitoringState parses NETWORK_AVAILABLE', () {
      final (state, _, _) = MonitoringState.parse('NETWORK_AVAILABLE');
      expect(state, MonitoringState.networkAvailable);
    });

    test('MonitoringState parses NETWORK_LOST', () {
      final (state, _, _) = MonitoringState.parse('NETWORK_LOST');
      expect(state, MonitoringState.networkLost);
    });

    test('CallEvent parses from map', () {
      final event = CallEvent.fromMap({
        'type': 'RINGING',
        'phoneNumber': '+84912345678',
        'source': 'telecom',
      });
      expect(event.type, 'RINGING');
      expect(event.phoneNumber, '+84912345678');
      expect(event.source, 'telecom');
    });

    test('CallEvent handles partial map', () {
      final event = CallEvent.fromMap({'type': 'ENDED'});
      expect(event.type, 'ENDED');
      expect(event.phoneNumber, isNull);
    });

    test('CallEvent handles empty map', () {
      final event = CallEvent.fromMap(<Object?, Object?>{});
      expect(event.type, 'UNKNOWN');
    });

    test('PermissionSnapshot counts correctly', () {
      const snapshot = PermissionSnapshot(
        recordAudio: true,
        phoneState: true,
        callLog: true,
        overlay: true,
        notification: true,
        accessibility: true,
        callScreening: true,
      );
      expect(snapshot.allGranted, isTrue);
      expect(snapshot.grantedCount, 7);
      expect(PermissionSnapshot.totalPermissions, 7);
    });

    test('PermissionSnapshot default all false', () {
      const snapshot = PermissionSnapshot();
      expect(snapshot.allGranted, isFalse);
      expect(snapshot.grantedCount, 0);
    });

    test('PermissionSnapshot equality — identical snapshots are equal', () {
      const a = PermissionSnapshot(recordAudio: true, phoneState: true);
      const b = PermissionSnapshot(recordAudio: true, phoneState: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('PermissionSnapshot equality — different snapshots are not equal', () {
      const a = PermissionSnapshot(recordAudio: true);
      const b = PermissionSnapshot(recordAudio: false);
      expect(a, isNot(equals(b)));
    });

    test('PermissionSnapshot equality — same instance', () {
      const a = PermissionSnapshot(recordAudio: true);
      expect(a, equals(a));
    });

    test('PermissionSnapshot equality — all fields compared', () {
      const a = PermissionSnapshot(
        recordAudio: true,
        phoneState: true,
        callLog: true,
        overlay: true,
        notification: true,
        accessibility: true,
        callScreening: true,
      );
      const b = PermissionSnapshot(
        recordAudio: true,
        phoneState: true,
        callLog: true,
        overlay: true,
        notification: true,
        accessibility: true,
        callScreening: false, // different
      );
      expect(a, isNot(equals(b)));
    });
  });
}
