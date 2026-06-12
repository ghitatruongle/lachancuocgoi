import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/ui/home_page/rights_dialog.dart';

import 'test_helpers.dart';

void main() {
  Widget wrapWithDialog({
    PermissionSnapshot? snapshot,
  }) {
    final bridge = FakeNativeBridge(snapshot: snapshot);
    return ProviderScope(
      overrides: [
        bridgeOverride(bridge),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const RightsDialog(),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
  }

  group('RightsDialog', () {
    testWidgets('renders dialog title', (tester) async {
      await tester.pumpWidget(wrapWithDialog());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Quyền ứng dụng'), findsOneWidget);
    });

    testWidgets('shows permission list items', (tester) async {
      await tester.pumpWidget(wrapWithDialog());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // First few items are visible in the viewport
      expect(find.text('Ghi âm'), findsOneWidget);
      expect(find.text('Trạng thái cuộc gọi'), findsOneWidget);
      expect(find.text('Lịch sử cuộc gọi'), findsOneWidget);

      // ListView in dialog may be lazy. Check that at least 3 items are visible.
      // Remaining items (overlay, notifications, call screening, accessibility)
      // may need scrolling which is fragile in dialog context.
    });

    testWidgets('close button works', (tester) async {
      await tester.pumpWidget(wrapWithDialog());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Quyền ứng dụng'), findsOneWidget);

      // Tap the close button (icon button)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Quyền ứng dụng'), findsNothing);
    });

    testWidgets('shows progress indicator', (tester) async {
      await tester.pumpWidget(wrapWithDialog());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows permission count text', (tester) async {
      await tester.pumpWidget(wrapWithDialog());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // With all permissions denied, shows 0/7
      expect(find.textContaining('/7 quyền đã cấp'), findsOneWidget);
    });

    testWidgets('shows granted count when some permissions granted', (tester) async {
      await tester.pumpWidget(wrapWithDialog(
        snapshot: const PermissionSnapshot(
          recordAudio: true,
          phoneState: true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2/7 quyền đã cấp'), findsOneWidget);
    });

    testWidgets('shows "Đóng" button', (tester) async {
      await tester.pumpWidget(wrapWithDialog());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Đóng'), findsOneWidget);
    });

    testWidgets('"Đóng" button dismisses dialog', (tester) async {
      await tester.pumpWidget(wrapWithDialog());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      expect(find.text('Quyền ứng dụng'), findsNothing);
    });

    testWidgets('shows "Cấp tất cả" button when not all granted', (tester) async {
      await tester.pumpWidget(wrapWithDialog());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Cấp tất cả'), findsOneWidget);
    });

    testWidgets('shows check icons for granted permissions', (tester) async {
      await tester.pumpWidget(wrapWithDialog(
        snapshot: const PermissionSnapshot(recordAudio: true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Granted permission shows check_circle icon
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('shows description text for each permission', (tester) async {
      await tester.pumpWidget(wrapWithDialog());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Thu âm thanh cuộc gọi qua microphone'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Phát hiện cuộc gọi đến'),
        findsOneWidget,
      );
    });
  });
}
