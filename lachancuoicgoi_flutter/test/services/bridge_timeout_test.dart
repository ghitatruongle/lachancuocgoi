import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lachancuocgoi_flutter/services/android_call_shield_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.lachancuocgoi/native_bridge');

  late AndroidCallShieldBridge bridge;

  setUp(() {
    bridge = AndroidCallShieldBridge(
      defaultTimeout: const Duration(milliseconds: 100),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test(
    'startMonitoring returns the value when the platform responds fast',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            return true;
          });
      final result = await bridge.startMonitoring(phoneNumber: '+84987654321');
      expect(result, isTrue);
    },
  );

  test(
    'startMonitoring returns false on timeout',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            return Completer<bool>().future;
          });

      final result = await bridge.startMonitoring(phoneNumber: '+84987654321');
      expect(result, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 2)),
  );

  test(
    'stopMonitoring times out gracefully',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            return Completer<bool>().future;
          });
      final result = await bridge.stopMonitoring();
      expect(result, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 2)),
  );

  test(
    'startCreatorMonitoring times out gracefully',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            return Completer<bool>().future;
          });
      final result = await bridge.startCreatorMonitoring(
        devModeExpiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
      );
      expect(result, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  test('PlatformException is swallowed and false is returned', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          throw PlatformException(code: 'UNAVAILABLE', message: 'test');
        });
    final result = await bridge.startMonitoring();
    expect(result, isFalse);
  });
}
