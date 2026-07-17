import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/ui/widgets/section_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('SectionCard', () {
    testWidgets('renders child inside a Card', (tester) async {
      await tester.pumpWidget(wrap(const SectionCard(child: Text('Hello'))));

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('renders title and trailing when provided', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SectionCard(
            title: Text('Title'),
            trailing: Icon(Icons.close),
            child: Text('Body'),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('does not render header row when title is null', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const SectionCard(child: Text('Body'))));

      // No header row — just child Column, no Row in direct children.
      expect(
        find.descendant(of: find.byType(Card), matching: find.byType(Row)),
        findsNothing,
      );
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('uses default padding (16)', (tester) async {
      await tester.pumpWidget(wrap(const SectionCard(child: SizedBox())));

      // Card itself wraps content in a Padding; there may be multiple Padding
      // widgets (Card internal margin + our content padding). At least one should
      // use the default EdgeInsets.all(16) from AppSpacing.sm.
      final paddingWidgets = tester.widgetList<Padding>(
        find.descendant(of: find.byType(Card), matching: find.byType(Padding)),
      );
      expect(
        paddingWidgets.any((p) => p.padding == const EdgeInsets.all(16)),
        isTrue,
      );
    });

    testWidgets('accepts custom padding', (tester) async {
      await tester.pumpWidget(
        wrap(const SectionCard(padding: EdgeInsets.all(8), child: SizedBox())),
      );

      // Find the Padding with EdgeInsets.all(8) inside the Card.
      final paddingWidgets = tester.widgetList<Padding>(
        find.descendant(of: find.byType(Card), matching: find.byType(Padding)),
      );
      expect(
        paddingWidgets.any((p) => p.padding == const EdgeInsets.all(8)),
        isTrue,
      );
    });

    testWidgets('child column is start-aligned', (tester) async {
      await tester.pumpWidget(wrap(const SectionCard(child: Text('Left'))));

      final column = tester.widget<Column>(
        find.descendant(
          of: find.byType(Padding),
          matching: find.byType(Column),
        ),
      );
      expect(column.crossAxisAlignment, equals(CrossAxisAlignment.start));
    });

    testWidgets('title and child separated by SizedBox when title exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const SectionCard(title: Text('Header'), child: Text('Body'))),
      );

      // The header Row and child are inside a Column; between them a SizedBox
      // of height 12 (AppSpacing.xs) separates them.
      final column = tester.widget<Column>(
        find.descendant(
          of: find.byType(Padding),
          matching: find.byType(Column),
        ),
      );
      expect(column.children.length, 3); // Row + SizedBox + child
    });
  });
}
