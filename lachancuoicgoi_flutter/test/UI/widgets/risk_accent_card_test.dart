import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/ui/theme/risk_level_colors.dart';
import 'package:lachancuocgoi_flutter/ui/widgets/risk_accent_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('RiskAccentCard', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RiskAccentCard(level: RiskLevel.green, child: Text('Content')),
        ),
      );

      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders inside a Card with clipBehavior', (tester) async {
      await tester.pumpWidget(
        wrap(const RiskAccentCard(level: RiskLevel.red, child: SizedBox())),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.clipBehavior, Clip.hardEdge);
    });

    testWidgets('accent bar color matches risk level', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RiskAccentCard(level: RiskLevel.orange, child: Text('Body')),
        ),
      );

      final row = tester.widget<Row>(
        find.descendant(
          of: find.byType(IntrinsicHeight),
          matching: find.byType(Row),
        ),
      );

      final firstChild = row.children.first;
      expect(firstChild, isA<Container>());

      final containers = tester.widgetList<Container>(
        find.descendant(of: find.byType(Row), matching: find.byType(Container)),
      );
      final hasAccentColor = containers.any((c) {
        return c.color == RiskLevel.orange.color;
      });
      expect(hasAccentColor, isTrue);
    });

    testWidgets('accepts custom padding', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RiskAccentCard(
            level: RiskLevel.green,
            padding: EdgeInsets.all(8),
            child: Text('Padded'),
          ),
        ),
      );

      final paddingWidgets = tester.widgetList<Padding>(
        find.descendant(of: find.byType(Card), matching: find.byType(Padding)),
      );

      expect(
        paddingWidgets.any((p) => p.padding == const EdgeInsets.all(8)),
        isTrue,
      );
    });
  });
}
