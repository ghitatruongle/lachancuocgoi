import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/ui/widgets/loading_elevated_button.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('LoadingElevatedButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        wrap(
          LoadingElevatedButton(
            isLoading: false,
            icon: Icons.play_arrow,
            label: 'Bắt đầu',
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('Bắt đầu'), findsOneWidget);
    });

    testWidgets('shows icon when not loading', (tester) async {
      await tester.pumpWidget(
        wrap(
          LoadingElevatedButton(
            isLoading: false,
            icon: Icons.play_arrow,
            label: 'Bắt đầu',
            onPressed: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows spinner when loading', (tester) async {
      await tester.pumpWidget(
        wrap(
          LoadingElevatedButton(
            isLoading: true,
            icon: Icons.play_arrow,
            label: 'Đang xử lý',
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('disables button when loading', (tester) async {
      await tester.pumpWidget(
        wrap(
          LoadingElevatedButton(
            isLoading: true,
            icon: Icons.play_arrow,
            label: 'Test',
            onPressed: () {},
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('enables button when not loading', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        wrap(
          LoadingElevatedButton(
            isLoading: false,
            icon: Icons.play_arrow,
            label: 'Test',
            onPressed: () => pressed = true,
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      expect(pressed, isTrue);
    });

    testWidgets('does not call onPressed when loading', (tester) async {
      await tester.pumpWidget(
        wrap(
          LoadingElevatedButton(
            isLoading: true,
            icon: Icons.play_arrow,
            label: 'Test',
            onPressed: () {},
          ),
        ),
      );

      // Button is disabled so tap won't fire.
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('is full-width by default', (tester) async {
      await tester.pumpWidget(
        wrap(
          Center(
            child: LoadingElevatedButton(
              isLoading: false,
              icon: Icons.play_arrow,
              label: 'Wide',
              onPressed: () {},
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(ElevatedButton),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.width, double.infinity);
    });

    testWidgets('expanded=false does not force full width', (tester) async {
      await tester.pumpWidget(
        wrap(
          LoadingElevatedButton(
            isLoading: false,
            icon: Icons.play_arrow,
            label: 'Inline',
            onPressed: () {},
            expanded: false,
          ),
        ),
      );

      // No wrapping SizedBox with width: double.infinity.
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.ancestor(
          of: find.byType(ElevatedButton),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBoxes.any((sb) => sb.width == double.infinity), isFalse);
    });
  });
}
