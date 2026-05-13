import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../core/permission/permission_manager.dart';
import '../native/native_call_shield_bridge.dart';

@GenerateMocks([NativeCallShieldBridge])
import 'phase10_permissions_test.mocks.dart';

void main() {
  group('Phase 10: Permission Management Tests', () {
    late MockNativeCallShieldBridge mockBridge;
    late PermissionManager permissionManager;

    setUp(() {
      mockBridge = MockNativeCallShieldBridge();
      permissionManager = PermissionManager(mockBridge);
    });

    tearDown(() {
      permissionManager.dispose();
    });

    test('Khởi tạo đúng với trạng thái mặc định là false', () {
      expect(permissionManager.hasAccessibility, isFalse);
      expect(permissionManager.hasOverlay, isFalse);
      expect(permissionManager.hasNotification, isFalse);
      expect(permissionManager.isAllGranted, isFalse);
    });

    test('checkPermissions gọi bridge và cập nhật trạng thái', () async {
      when(mockBridge.getPermissionStatus()).thenAnswer((_) async => {
        'accessibility': true,
        'overlay': false,
        'notification': true,
      });

      await permissionManager.checkPermissions();

      expect(permissionManager.hasAccessibility, isTrue);
      expect(permissionManager.hasOverlay, isFalse);
      expect(permissionManager.hasNotification, isTrue);
      expect(permissionManager.isAllGranted, isFalse);
    });

    test('requestAccessibility gọi bridge đúng method', () async {
      when(mockBridge.requestAccessibilityPermission()).thenAnswer((_) async {});

      await permissionManager.requestAccessibility();

      verify(mockBridge.requestAccessibilityPermission()).called(1);
    });

    test('requestOverlay gọi bridge đúng method', () async {
      when(mockBridge.requestOverlayPermission()).thenAnswer((_) async {});

      await permissionManager.requestOverlay();

      verify(mockBridge.requestOverlayPermission()).called(1);
    });

    test('requestNotification gọi bridge đúng method', () async {
      when(mockBridge.requestNotificationPermission()).thenAnswer((_) async {});

      await permissionManager.requestNotification();

      verify(mockBridge.requestNotificationPermission()).called(1);
    });

    test('Stream listener cập nhật trạng thái khi có sự kiện từ native', () async {
      final streamController = StreamController<Map<String, dynamic>>.broadcast();
      when(mockBridge.permissionStream).thenAnswer((_) => streamController.stream);

      // Tạo lại manager để nhận stream mới
      permissionManager.dispose();
      permissionManager = PermissionManager(mockBridge);

      streamController.add({
        'accessibility': true,
        'overlay': true,
        'notification': true,
      });

      // Đợi event loop xử lý
      await Future.delayed(Duration(milliseconds: 100));

      expect(permissionManager.hasAccessibility, isTrue);
      expect(permissionManager.hasOverlay, isTrue);
      expect(permissionManager.hasNotification, isTrue);
      expect(permissionManager.isAllGranted, isTrue);
    });

    test('Xử lý lỗi khi checkPermissions thất bại', () async {
      when(mockBridge.getPermissionStatus()).thenThrow(Exception('Không thể kết nối native'));

      await permissionManager.checkPermissions();

      // Trạng thái vẫn giữ nguyên (false) khi có lỗi
      expect(permissionManager.hasAccessibility, isFalse);
      expect(permissionManager.isChecking, isFalse);
    });
  });
}
