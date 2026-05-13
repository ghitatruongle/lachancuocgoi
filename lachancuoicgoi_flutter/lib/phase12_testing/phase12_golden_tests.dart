import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../core/permission/permission_manager.dart';
import '../ui/rights_dialog/rights_dialog.dart';

/// Golden test cho Rights Dialog
void main() {
  group('Phase 12: Golden Tests', () {
    // Test 1: Rights Dialog khi chưa có quyền nào
    testWidgets('RightsDialog - No permissions granted', (WidgetTester tester) async {
      final permissionManager = PermissionManagerMock(false, false, false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<PermissionManager>.value(
              value: permissionManager,
              child: const RightsDialog(),
            ),
          ),
        ),
      );

      expect(find.text('Cấp quyền cần thiết'), findsOneWidget);
      expect(find.text('Quyền Trợ năng (Accessibility)'), findsOneWidget);
      expect(find.text('Quyền Hiển thị trên ứng dụng khác'), findsOneWidget);
      expect(find.text('Quyền Thông báo'), findsOneWidget);
      
      // Kiểm tra các nút "Cấp quyền" xuất hiện
      expect(find.text('Cấp quyền'), findsNWidgets(3));
      
      // Chụp golden image
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/rights_dialog_no_permissions.png'),
      );
    });

    // Test 2: Rights Dialog khi đã có tất cả quyền
    testWidgets('RightsDialog - All permissions granted', (WidgetTester tester) async {
      final permissionManager = PermissionManagerMock(true, true, true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<PermissionManager>.value(
              value: permissionManager,
              child: const RightsDialog(),
            ),
          ),
        ),
      );

      // Kiểm tra icon check màu xanh xuất hiện
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
      
      // Không có nút "Cấp quyền" nào
      expect(find.text('Cấp quyền'), findsNothing);
      
      // Nút "Hoàn tất" enabled
      final completeButton = tester.widget<ElevatedButton>(
        find.text('Hoàn tất'),
      );
      expect(completeButton.onPressed, isNotNull);
      
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/rights_dialog_all_granted.png'),
      );
    });

    // Test 3: Rights Dialog khi chỉ có một số quyền
    testWidgets('RightsDialog - Partial permissions', (WidgetTester tester) async {
      final permissionManager = PermissionManagerMock(true, false, true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<PermissionManager>.value(
              value: permissionManager,
              child: const RightsDialog(),
            ),
          ),
        ),
      );

      // Chỉ có 2 icon check (accessibility và notification)
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      // 1 icon error (overlay)
      expect(find.byIcon(Icons.error_outline), findsNWidgets(1));
      
      // Chỉ có 1 nút "Cấp quyền" cho overlay
      expect(find.text('Cấp quyền'), findsNWidgets(1));
      
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/rights_dialog_partial.png'),
      );
    });
  });
}

/// Mock PermissionManager cho testing
class PermissionManagerMock extends ChangeNotifier implements PermissionManager {
  final bool hasAcc;
  final bool hasOvl;
  final bool hasNoti;

  PermissionManagerMock(this.hasAcc, this.hasOvl, this.hasNoti);

  @override
  bool get hasAccessibility => hasAcc;

  @override
  bool get hasOverlay => hasOvl;

  @override
  bool get hasNotification => hasNoti;

  @override
  bool get isChecking => false;

  @override
  bool get isAllGranted => hasAcc && hasOvl && hasNoti;

  @override
  Future<void> checkPermissions() async {}

  @override
  Future<void> requestAccessibility() async {}

  @override
  Future<void> requestOverlay() async {}

  @override
  Future<void> requestNotification() async {}

  @override
  void dispose() {}
}
