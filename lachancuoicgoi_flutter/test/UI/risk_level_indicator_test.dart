import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/risk_level_indicator.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('RiskLevelIndicator', () {
    testWidgets('shows label Mức độ rủi ro', (tester) async {
      await tester.pumpWidget(wrap(
        const RiskLevelIndicator(riskLevel: RiskLevel.green),
      ));
      expect(find.text('Mức độ rủi ro'), findsOneWidget);
    });

    testWidgets('shows An toàn for green risk', (tester) async {
      await tester.pumpWidget(wrap(
        const RiskLevelIndicator(riskLevel: RiskLevel.green),
      ));
      expect(find.text('An toàn'), findsOneWidget);
    });

    testWidgets('shows Nguy cơ for orange risk', (tester) async {
      await tester.pumpWidget(wrap(
        const RiskLevelIndicator(riskLevel: RiskLevel.orange),
      ));
      expect(find.text('Nguy cơ'), findsOneWidget);
    });

    testWidgets('shows Nguy hiểm for red risk', (tester) async {
      await tester.pumpWidget(wrap(
        const RiskLevelIndicator(riskLevel: RiskLevel.red),
      ));
      expect(find.text('Nguy hiểm'), findsOneWidget);
    });

    testWidgets('progress increases with risk level', (tester) async {
      await tester.pumpWidget(wrap(
        const RiskLevelIndicator(riskLevel: RiskLevel.green),
      ));
      final greenValue = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      ).value!;

      await tester.pumpWidget(wrap(
        const RiskLevelIndicator(riskLevel: RiskLevel.orange),
      ));
      final orangeValue = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      ).value!;

      await tester.pumpWidget(wrap(
        const RiskLevelIndicator(riskLevel: RiskLevel.red),
      ));
      final redValue = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      ).value!;

      // Risk should increase: green < orange < red
      expect(greenValue, lessThan(orangeValue));
      expect(orangeValue, lessThan(redValue));
      expect(redValue, 1.0);
    });
  });
}
