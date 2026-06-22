import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/ui/widgets/info_line.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('InfoLine', () {
    testWidgets('renders icon and text', (tester) async {
      await tester.pumpWidget(
        wrap(const InfoLine(icon: Icons.info, text: 'Some info')),
      );

      expect(find.byIcon(Icons.info), findsOneWidget);
      expect(find.text('Some info'), findsOneWidget);
    });

    testWidgets('icon and text share the custom color', (tester) async {
      const customColor = Colors.red;
      await tester.pumpWidget(
        wrap(
          const InfoLine(
            icon: Icons.warning,
            text: 'Warning text',
            color: customColor,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.warning));
      expect(icon.color, customColor);

      final text = tester.widget<Text>(find.text('Warning text'));
      expect(text.style?.color, customColor);
    });

    testWidgets('defaults color to onSurfaceVariant from theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const InfoLine(icon: Icons.info, text: 'Default color')),
      );

      // When color is null, InfoLine uses cs.onSurfaceVariant.
      // The icon and text widgets will both have non-null colors resolved
      // from the theme. Verify the Text widget's style has a color.
      final text = tester.widget<Text>(find.text('Default color'));
      expect(text.style?.color, isNotNull);
    });

    testWidgets('respects custom iconSize', (tester) async {
      await tester.pumpWidget(
        wrap(const InfoLine(icon: Icons.info, text: 'Small', iconSize: 12)),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.info));
      expect(icon.size, 12);
    });

    testWidgets('respects custom gap', (tester) async {
      await tester.pumpWidget(
        wrap(const InfoLine(icon: Icons.info, text: 'Gap test', gap: 24)),
      );

      // Find the SizedBox between icon and text. The Row children are:
      // [Icon, SizedBox(width: gap), Expanded(child: Text)].
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.descendant(of: find.byType(Row), matching: find.byType(SizedBox)),
      );
      // At least one should have width == 24.
      expect(sizedBoxes.any((sb) => sb.width == 24), isTrue);
    });

    testWidgets('text is wrapped in Expanded for overflow safety', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const InfoLine(
            icon: Icons.info,
            text: 'A very long line that should not overflow the row',
          ),
        ),
      );

      expect(find.byType(Expanded), findsOneWidget);
    });
  });
}
