import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/live_conversation.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('LiveConversation', () {
    testWidgets('shows listening placeholder when transcript empty and not simulation',
        (tester) async {
      await tester.pumpWidget(wrap(
        const LiveConversation(transcript: '', isSimulation: false),
      ));

      expect(find.text('Đang lắng nghe...'), findsOneWidget);
    });

    testWidgets('shows simulation waiting when transcript empty and simulation',
        (tester) async {
      await tester.pumpWidget(wrap(
        const LiveConversation(transcript: '', isSimulation: true),
      ));

      expect(find.text('Đang chờ kịch bản...'), findsOneWidget);
    });

    testWidgets('displays transcript text', (tester) async {
      await tester.pumpWidget(wrap(
        const LiveConversation(
          transcript: 'Xin chào, tôi là Minh',
          isSimulation: false,
        ),
      ));

      expect(find.text('Xin chào, tôi là Minh'), findsOneWidget);
    });

    testWidgets('replaces + with spaces in transcript', (tester) async {
      await tester.pumpWidget(wrap(
        const LiveConversation(
          transcript: 'Hello+World+Test',
          isSimulation: false,
        ),
      ));

      expect(find.text('Hello World Test'), findsOneWidget);
    });

    testWidgets('updates when transcript changes', (tester) async {
      await tester.pumpWidget(wrap(
        const LiveConversation(transcript: 'First', isSimulation: false),
      ));

      expect(find.text('First'), findsOneWidget);

      await tester.pumpWidget(wrap(
        const LiveConversation(transcript: 'Second', isSimulation: false),
      ));

      expect(find.text('Second'), findsOneWidget);
    });
  });
}
