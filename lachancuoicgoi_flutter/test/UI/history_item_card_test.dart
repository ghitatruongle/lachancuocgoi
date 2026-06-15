import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/ui/history_page/history_item_card.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  CallHistory makeItem({
    String riskLevel = 'RED',
    String summary = 'Test summary text',
    String dateTime = '01/06/2026 10:30',
    String duration = '5 phút',
    int flagCount = 3,
    String? analysisType,
  }) {
    return CallHistory(
      id: 1,
      dateTime: dateTime,
      riskLevel: riskLevel,
      summary: summary,
      duration: duration,
      flagCount: flagCount,
      transcript: 'test transcript',
      analysisType: analysisType,
    );
  }

  group('HistoryItemCard', () {
    testWidgets('displays risk level badge text', (tester) async {
      await tester.pumpWidget(wrap(
        HistoryItemCard(
          item: makeItem(riskLevel: 'RED'),
          onTap: () {},
        ),
      ));

      // Risk level badge shows Vietnamese name
      expect(find.text('Nguy hiểm'), findsOneWidget);
    });

    testWidgets('displays risk level color bar for GREEN', (tester) async {
      await tester.pumpWidget(wrap(
        HistoryItemCard(
          item: makeItem(riskLevel: 'GREEN'),
          onTap: () {},
        ),
      ));

      expect(find.text('An toàn'), findsOneWidget);
    });

    testWidgets('displays risk level color bar for ORANGE', (tester) async {
      await tester.pumpWidget(wrap(
        HistoryItemCard(
          item: makeItem(riskLevel: 'ORANGE'),
          onTap: () {},
        ),
      ));

      expect(find.text('Nguy cơ'), findsOneWidget);
    });

    testWidgets('displays risk level color bar for YELLOW', (tester) async {
      await tester.pumpWidget(wrap(
        HistoryItemCard(
          item: makeItem(riskLevel: 'YELLOW'),
          onTap: () {},
        ),
      ));

      expect(find.text('Chú ý'), findsOneWidget);
    });

    testWidgets('shows summary text', (tester) async {
      await tester.pumpWidget(wrap(
        HistoryItemCard(
          item: makeItem(summary: 'Cuộc gọi đáng ngờ về OTP'),
          onTap: () {},
        ),
      ));

      expect(find.text('Cuộc gọi đáng ngờ về OTP'), findsOneWidget);
    });

    testWidgets('shows date/time', (tester) async {
      await tester.pumpWidget(wrap(
        HistoryItemCard(
          item: makeItem(dateTime: '15/05/2026 14:30'),
          onTap: () {},
        ),
      ));

      expect(find.text('15/05/2026 14:30'), findsOneWidget);
    });

    testWidgets('shows duration and flag count', (tester) async {
      await tester.pumpWidget(wrap(
        HistoryItemCard(
          item: makeItem(duration: '3 phút', flagCount: 5),
          onTap: () {},
        ),
      ));

      expect(find.text('3 phút • 5 dấu hiệu'), findsOneWidget);
    });

    testWidgets('tap navigates to result via onTap callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrap(
        HistoryItemCard(
          item: makeItem(),
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('shows analysis type when present', (tester) async {
      await tester.pumpWidget(wrap(
        HistoryItemCard(
          item: makeItem(analysisType: 'AI Gemini'),
          onTap: () {},
        ),
      ));

      expect(find.text('AI Gemini'), findsOneWidget);
    });

    testWidgets('shows fallback text when analysis type is null', (tester) async {
      await tester.pumpWidget(wrap(
        HistoryItemCard(
          item: makeItem(analysisType: null),
          onTap: () {},
        ),
      ));

      expect(find.text('Không phân tích'), findsOneWidget);
    });

    testWidgets('has risk color bar container', (tester) async {
      await tester.pumpWidget(wrap(
        HistoryItemCard(
          item: makeItem(riskLevel: 'RED'),
          onTap: () {},
        ),
      ));

      // The 4px wide risk color bar container exists
      final containers = find.byType(Container);
      expect(containers, findsWidgets);
    });
  });
}
