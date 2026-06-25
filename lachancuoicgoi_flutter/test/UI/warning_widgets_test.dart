import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/warning/full_screen_warning.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/warning/red_warning.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/warning/orange_warning.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  group('FullScreenWarning', () {
    testWidgets('renders with titleText and subtitle', (tester) async {
      await tester.pumpWidget(
        wrap(
          const FullScreenWarning(
            color: Colors.red,
            icon: Icons.warning,
            titleText: 'Test Title',
            subtitle: 'Test Subtitle',
            buttonColor: Colors.red,
            onDismiss: _noop,
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Subtitle'), findsOneWidget);
    });

    testWidgets('shows DA HIEU button', (tester) async {
      await tester.pumpWidget(
        wrap(
          const FullScreenWarning(
            color: Colors.red,
            icon: Icons.warning,
            titleText: 'Title',
            subtitle: 'Sub',
            buttonColor: Colors.red,
            onDismiss: _noop,
          ),
        ),
      );

      expect(find.text('ĐÃ HIỂU'), findsOneWidget);
    });

    testWidgets('calls onDismiss when button tapped', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        wrap(
          FullScreenWarning(
            color: Colors.red,
            icon: Icons.warning,
            titleText: 'Title',
            subtitle: 'Sub',
            buttonColor: Colors.red,
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      await tester.tap(find.text('ĐÃ HIỂU'));
      expect(dismissed, true);
    });

    testWidgets('shows close button', (tester) async {
      await tester.pumpWidget(
        wrap(
          const FullScreenWarning(
            color: Colors.red,
            icon: Icons.warning,
            titleText: 'Title',
            subtitle: 'Sub',
            buttonColor: Colors.red,
            onDismiss: _noop,
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('calls onDismiss when close tapped', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        wrap(
          FullScreenWarning(
            color: Colors.red,
            icon: Icons.warning,
            titleText: 'Title',
            subtitle: 'Sub',
            buttonColor: Colors.red,
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(dismissed, true);
    });
  });

  group('RedWarning', () {
    testWidgets('shows NGUY HIEM titleText', (tester) async {
      await tester.pumpWidget(
        wrap(const RedWarning(title: 'Lừa đảo OTP', onDismiss: _noop)),
      );

      expect(find.text('NGUY HIỂM'), findsOneWidget);
      expect(find.text('Lừa đảo OTP'), findsOneWidget);
    });

    testWidgets('passes onDismiss to FullScreenWarning', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        wrap(RedWarning(title: 'Test', onDismiss: () => dismissed = true)),
      );

      await tester.tap(find.text('ĐÃ HIỂU'));
      expect(dismissed, true);
    });
  });

  group('OrangeWarning', () {
    testWidgets('shows NGUY CO titleText', (tester) async {
      await tester.pumpWidget(
        wrap(const OrangeWarning(title: 'Nội dung đáng ngờ', onDismiss: _noop)),
      );

      expect(find.text('NGUY CƠ'), findsOneWidget);
      expect(find.text('Nội dung đáng ngờ'), findsOneWidget);
    });

    testWidgets('passes onDismiss to FullScreenWarning', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        wrap(OrangeWarning(title: 'Test', onDismiss: () => dismissed = true)),
      );

      await tester.tap(find.text('ĐÃ HIỂU'));
      expect(dismissed, true);
    });
  });
}

void _noop() {}
