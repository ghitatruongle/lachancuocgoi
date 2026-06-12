import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lachancuocgoi_flutter/ui/tips_lesson_page/tips_lesson_page.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('TipsLessonPage', () {
    testWidgets('renders app bar title', (tester) async {
      await tester.pumpWidget(wrap(const TipsLessonPage()));
      expect(find.text('Mẹo chống lừa đảo'), findsOneWidget);
    });

    testWidgets('renders first tip title', (tester) async {
      await tester.pumpWidget(wrap(const TipsLessonPage()));
      await tester.pumpAndSettle();

      expect(find.text('Xác minh danh tính người gọi'), findsOneWidget);
    });

    testWidgets('has Card widgets for tips', (tester) async {
      await tester.pumpWidget(wrap(const TipsLessonPage()));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('content is scrollable', (tester) async {
      await tester.pumpWidget(wrap(const TipsLessonPage()));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders description text', (tester) async {
      await tester.pumpWidget(wrap(const TipsLessonPage()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Những kiến thức cần biết'),
        findsOneWidget,
      );
    });

    testWidgets('back button is present', (tester) async {
      await tester.pumpWidget(wrap(const TipsLessonPage()));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}
