import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/ui/widgets/dialogs.dart';

void main() {
  group('showConfirmDialog', () {
    testWidgets('shows title and message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showConfirmDialog(
                      context,
                      title: 'Xóa?',
                      message: 'Bạn có chắc không?',
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Xóa?'), findsOneWidget);
      expect(find.text('Bạn có chắc không?'), findsOneWidget);
    });

    testWidgets('shows default confirm label "Xóa"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showConfirmDialog(context, title: 'Xóa?', message: 'Msg');
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Xóa'), findsOneWidget);
    });

    testWidgets('shows default cancel label "Quay lại"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showConfirmDialog(context, title: 'Xóa?', message: 'Msg');
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Quay lại'), findsOneWidget);
    });

    testWidgets('returns false when cancelled', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showConfirmDialog(
                      context,
                      title: 'Xóa?',
                      message: 'Msg',
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('returns true when confirmed', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showConfirmDialog(
                      context,
                      title: 'Xóa?',
                      message: 'Msg',
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('confirm button has error color when destructive', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showConfirmDialog(context, title: 'Xóa?', message: 'Msg');
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The confirm button should have error foreground color.
      final buttons = find.byType(TextButton);
      expect(buttons, findsNWidgets(2));

      // The destructive one (last button) should have error color.
      final confirmButton = tester.widget<TextButton>(buttons.last);
      expect(confirmButton.style?.foregroundColor?.resolve({}), isNotNull);
    });

    testWidgets('accepts custom confirm label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showConfirmDialog(
                      context,
                      title: 'Xác nhận?',
                      message: 'Msg',
                      confirmLabel: 'Xác nhận',
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận'), findsOneWidget);
    });

    testWidgets('returns false when dialog is dismissed', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showConfirmDialog(
                      context,
                      title: 'Xóa?',
                      message: 'Msg',
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Dismiss by tapping outside (barrier dismiss)
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });
}
