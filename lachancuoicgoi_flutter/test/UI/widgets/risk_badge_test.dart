import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/ui/theme/risk_level_colors.dart';
import 'package:lachancuocgoi_flutter/ui/widgets/risk_badge.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('RiskBadge', () {
    testWidgets('shows Vietnamese name for each risk level', (tester) async {
      for (final level in RiskLevel.values) {
        await tester.pumpWidget(wrap(RiskBadge(level: level)));
        expect(find.text(level.vietnameseName), findsOneWidget);
      }
    });

    testWidgets('text color matches risk level color', (tester) async {
      await tester.pumpWidget(wrap(const RiskBadge(level: RiskLevel.red)));

      final text = tester.widget<Text>(find.text('Nguy hiểm'));
      expect(text.style?.color, RiskLevel.red.color);
    });

    testWidgets('background is 10% tint of risk color', (tester) async {
      await tester.pumpWidget(wrap(const RiskBadge(level: RiskLevel.orange)));

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('Nguy cơ'),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.color,
        equals(RiskLevel.orange.color.withValues(alpha: 0.1)),
      );
    });

    testWidgets('has Semantics label with risk level name', (tester) async {
      await tester.pumpWidget(wrap(const RiskBadge(level: RiskLevel.red)));

      // Find the Semantics widget that is our RiskBadge's wrapper.
      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final hasLabel = semanticsWidgets.any((s) {
        final label = s.properties.label;
        return label != null &&
            label.contains('Nguy hiểm') &&
            label.contains('Mức độ rủi ro');
      });
      expect(hasLabel, isTrue);
    });
  });
}
