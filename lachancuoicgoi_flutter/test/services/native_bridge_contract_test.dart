import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/services/native_bridge_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NativeBridgeContract bridge;
  late List<MethodCall> log;

  setUp(() {
    log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('org.lachancuocgoi/native_service'),
          (MethodCall methodCall) async {
            log.add(methodCall);
            if (methodCall.method == 'checkOverlayPermission') {
              return true;
            }
            if (methodCall.method == 'checkCallScreeningStatus') {
              return false;
            }
            if (methodCall.method == 'throwError') {
              throw PlatformException(
                code: 'UNAVAILABLE',
                message: 'Service not ready',
              );
            }
            if (methodCall.method == 'badType') {
              return 'NOT_A_BOOL';
            }
            return null;
          },
        );
    bridge = NativeBridgeContract();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('org.lachancuocgoi/native_service'),
          null,
        );
  });

  group('NativeBridgeContract Tests', () {
    test(
      'checkOverlayPermission returns true when native responds true',
      () async {
        final result = await bridge.checkOverlayPermission();
        expect(result, isTrue);
        expect(log.single.method, equals('checkOverlayPermission'));
      },
    );

    test(
      'checkCallScreeningStatus returns false when native responds false',
      () async {
        final result = await bridge.checkCallScreeningStatus();
        expect(result, isFalse);
      },
    );

    test(
      'Catches PlatformException gracefully and returns fallback value',
      () async {
        final result = await bridge.invokeTypeSafeMethod<bool>(
          'throwError',
          null,
          false,
        );
        expect(result, isFalse);
      },
    );

    test('Handles type mismatch safely without throwing TypeError', () async {
      final result = await bridge.invokeTypeSafeMethod<bool>(
        'badType',
        null,
        false,
      );
      expect(result, isFalse);
    });
  });
}
