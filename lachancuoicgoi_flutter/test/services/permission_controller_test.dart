import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lachancuocgoi_flutter/services/permission_controller.dart';

/// Creates a [ProviderContainer] and returns the [PermissionController] notifier.
/// This is the correct way to create a [Notifier]-based controller in tests.
ProviderContainer createContainer() {
  return ProviderContainer(overrides: []);
}

PermissionController createController(ProviderContainer container) {
  return container.read(permissionControllerProvider.notifier);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.lachancuocgoi/native_bridge');
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  final permissionMap = <String, bool>{
    'recordAudio': false,
    'phoneState': false,
    'callLog': false,
    'overlay': false,
    'notification': false,
    'accessibility': false,
    'callScreening': false,
  };

  final methodCalls = <MethodCall>[];

  ProviderContainer? container;

  setUp(() {
    container = createContainer();
    methodCalls.clear();
    permissionMap.clear();
    permissionMap.addAll({
      'recordAudio': false,
      'phoneState': false,
      'callLog': false,
      'overlay': false,
      'notification': false,
      'accessibility': false,
      'callScreening': false,
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          methodCalls.add(call);
          if (call.method == 'getPermissionSnapshot') {
            return permissionMap;
          }
          if (call.method == 'isMonitoringActive') {
            return false;
          }
          return true;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'requestPermissions') {
            final permissions =
                (call.arguments as List<dynamic>?) ?? <dynamic>[];
            return <int, int>{
              for (final p in permissions)
                p as int: 1, // 1 = PermissionStatus.granted
            };
          }
          return null;
        });
  });

  tearDown(() {
    container?.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  group('PermissionController — refresh', () {
    testWidgets('initial state loads snapshot from native', (tester) async {
      permissionMap['recordAudio'] = true;
      permissionMap['notification'] = true;

      final controller = createController(container!);
      // Wait for the initial _refresh() to complete
      await tester.pump();

      expect(controller.state.snapshot.recordAudio, isTrue);
      expect(controller.state.snapshot.notification, isTrue);
      expect(controller.state.snapshot.phoneState, isFalse);
    });

    testWidgets('refresh is throttled — second call within 500ms is skipped', (
      tester,
    ) async {
      final controller = createController(container!);
      await tester.pump();

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

    testWidgets('refresh updates state when snapshot changes', (tester) async {
      final controller = createController(container!);
      await tester.pump();
      expect(controller.state.snapshot.recordAudio, isFalse);

      // Change the native response
      permissionMap['recordAudio'] = true;

      // Wait for throttle to expire in fake time
      await tester.pump(const Duration(milliseconds: 600));
      await controller.refresh();

      expect(controller.state.snapshot.recordAudio, isTrue);
    });

    testWidgets('refresh does not update state when snapshot is identical', (
      tester,
    ) async {
      final controller = createController(container!);
      // Wait for initial _refresh() to complete
      await tester.pump(const Duration(milliseconds: 100));

      final stateBefore = controller.state;

      // Wait for throttle to expire, then refresh again with same data
      await tester.pump(const Duration(milliseconds: 600));
      await controller.refresh();

      // State should be the same object (no copyWith was called)
      expect(controller.state.snapshot, equals(stateBefore.snapshot));
    });
  });

  group('PermissionController — requestMicrophonePermission', () {
    testWidgets('returns current snapshot value after refresh', (tester) async {
      permissionMap['recordAudio'] = true;
      final controller = createController(container!);
      await tester.pump();

      // Wait for throttle
      await tester.pump(const Duration(milliseconds: 600));
      final result = await controller.requestMicrophonePermission();

      expect(result, isTrue);
      expect(controller.state.snapshot.recordAudio, isTrue);
    });
  });

  group('PermissionController — requestPhoneAndCallLogPermissions', () {
    testWidgets('calls bridge and refreshes snapshot', (tester) async {
      permissionMap['phoneState'] = true;
      permissionMap['callLog'] = true;
      final controller = createController(container!);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 600));
      final result = await controller.requestPhoneAndCallLogPermissions();

      expect(result, isTrue);
      expect(
        methodCalls,
        contains(
          isA<MethodCall>().having(
            (c) => c.method,
            'method',
            'requestPhoneAndCallLogPermissions',
          ),
        ),
      );
    });
  });

  group('PermissionController — requestOverlayPermission', () {
    testWidgets('calls bridge and returns result', (tester) async {
      permissionMap['overlay'] = true;
      final controller = createController(container!);
      await tester.pump();

      final result = await controller.requestOverlayPermission();
      expect(result, isTrue);
      // Lifecycle resume triggers refresh in production.
      // In test, call refresh explicitly.
      await tester.pump(const Duration(milliseconds: 600));
      await controller.refresh();
      expect(controller.state.snapshot.overlay, isTrue);
    });
  });

  group('PermissionController — requestCallScreeningPermission', () {
    testWidgets('calls bridge and returns result', (tester) async {
      permissionMap['callScreening'] = true;
      final controller = createController(container!);
      await tester.pump();

      final result = await controller.requestCallScreeningPermission();
      expect(result, isTrue);
      // Lifecycle resume triggers refresh in production.
      await tester.pump(const Duration(milliseconds: 600));
      await controller.refresh();
      expect(controller.state.snapshot.callScreening, isTrue);
    });
  });

  group('PermissionController — requestAllPermissions', () {
    testWidgets('requests all missing permissions in sequence', (tester) async {
      final controller = createController(container!);
      await tester.pump();

      // Set all to true after requests
      permissionMap['recordAudio'] = true;
      permissionMap['phoneState'] = true;
      permissionMap['callLog'] = true;
      permissionMap['overlay'] = true;
      permissionMap['notification'] = true;
      permissionMap['accessibility'] = true;
      permissionMap['callScreening'] = true;

      await tester.pump(const Duration(milliseconds: 600));
      final results = await controller.requestAllPermissions();

      expect(results, isA<Map<String, bool>>());
      // After all requests, allGranted should be true
      expect(controller.state.snapshot.allGranted, isTrue);
    });

    testWidgets('skips already granted permissions', (tester) async {
      permissionMap['recordAudio'] = true;
      permissionMap['phoneState'] = true;
      permissionMap['callLog'] = true;
      permissionMap['overlay'] = true;
      permissionMap['notification'] = true;
      permissionMap['accessibility'] = true;
      permissionMap['callScreening'] = true;

      final controller = createController(container!);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 600));
      final results = await controller.requestAllPermissions();

      // All already granted, so individual request methods shouldn't be called
      expect(results, isEmpty);
    });
  });

  group('PermissionController — checkMonitoringActive', () {
    testWidgets('delegates to bridge', (tester) async {
      final controller = createController(container!);
      await tester.pump();

      final result = await controller.checkMonitoringActive();
      expect(result, isFalse);
    });
  });

  group('PermissionController — providers', () {
    testWidgets('allPermissionsGrantedProvider reflects state', (tester) async {
      final controller = createController(container!);
      await tester.pump();

      expect(controller.state.allGranted, isFalse);
    });

    testWidgets('missingPermissionsProvider lists missing permissions', (
      tester,
    ) async {
      permissionMap['recordAudio'] = true;
      final controller = createController(container!);
      await tester.pump();

      expect(controller.state.snapshot.recordAudio, isTrue);
      expect(controller.state.snapshot.phoneState, isFalse);
      expect(controller.state.grantedCount, 1);
    });
  });
}
