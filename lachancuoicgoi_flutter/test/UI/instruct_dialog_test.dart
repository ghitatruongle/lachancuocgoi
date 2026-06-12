import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lachancuocgoi_flutter/ui/home_page/instruct_dialog.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => child,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
  }

  group('InstructDialog', () {
    testWidgets('renders dialog title', (tester) async {
      await tester.pumpWidget(wrap(const InstructDialog()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Hướng dẫn sử dụng'), findsOneWidget);
    });

    testWidgets('renders all 3 instruction steps', (tester) async {
      await tester.pumpWidget(wrap(const InstructDialog()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Bước 1: Bật Loa Ngoài'), findsOneWidget);
      expect(find.text('Bước 2: Phân Tích Âm Thanh'), findsOneWidget);
      expect(find.text('Bước 3: Gửi Cảnh Báo'), findsOneWidget);
    });

    testWidgets('renders step descriptions', (tester) async {
      await tester.pumpWidget(wrap(const InstructDialog()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Use textContaining with broader substrings for robustness
      expect(
        find.textContaining('loa ngoài'),
        findsWidgets,
      );
      expect(
        find.textContaining('lắng nghe'),
        findsWidgets,
      );
      expect(
        find.textContaining('phát hiện'),
        findsWidgets,
      );
    });

    testWidgets('close button dismisses dialog', (tester) async {
      await tester.pumpWidget(wrap(const InstructDialog()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Đã hiểu'), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Hướng dẫn sử dụng'), findsNothing);
    });

    testWidgets('renders step icons', (tester) async {
      await tester.pumpWidget(wrap(const InstructDialog()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    });
  });
}
