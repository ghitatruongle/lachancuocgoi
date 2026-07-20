// Bug #22 tests: MethodChannel timeout wrapper on AndroidCallShieldBridge.
//
// Verifies that:
//  - When the platform-thread takes too long, invokeMethod is cancelled
//    after the timeout and a default value is returned.
//  - When the platform-thread responds normally, no timeout fires and the
//    real value is propagated.
//  - PlatformException is still swallowed and a default is returned.
//
// BUG-BASELINE-3 fix: Inject 100ms timeout via constructor for fast tests.
// Production code defaults to 5s. Each timeout test now takes ~100ms instead
// of ~5s, reducing test suite time by ~10s per timeout test.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lachancuocgoi_flutter/services/android_call_shield_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.lachancuocgoi/native_bridge');

  late AndroidCallShieldBridge bridge;

  setUp(() {
    // BUG-BASELINE-3 fix: inject 100ms timeout for fast tests (production uses 5s).
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

  // BUG-BASELINE-3 fix: Previously used FakeAsync which cannot control the
  // real Timer created by Future.timeout(). The production code's
  // _invokeWithTimeout uses .timeout(5s) with an onTimeout callback that
  // returns false. With real async the timeout fires correctly.
  //
  // Now injected with 100ms timeout for fast tests.
  test(
    'startMonitoring returns false on timeout',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
            // Never completes — simulate a hung platform thread.
            return Completer<bool>().future;
          });
      // Injected timeout (100ms) fires → onTimeout returns false.
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
