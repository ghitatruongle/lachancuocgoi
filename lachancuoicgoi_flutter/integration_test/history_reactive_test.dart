// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/ui/history_page/history_page.dart';

import 'helpers/integration_test_harness.dart';

CallHistory _row({
  String riskLevel = 'GREEN',
  String summary = 'No risk',
  String transcript = '',
  String dateTime = '12:00:00 01/06/2026',
}) {
  return CallHistory(
    dateTime: dateTime,
    riskLevel: riskLevel,
    summary: summary,
    duration: '00:30',
    flagCount: 0,
    transcript: transcript,
    audioPath: null,
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.testTextInput.register();

  group('Sprint 4 — history reactive updates', () {
    late IntegrationTestHarness harness;

    setUp(() async {
      harness = await IntegrationTestHarness.build(initialRoute: '/history');
    });

    tearDown(() async {
      await harness.dispose();
    });

    Future<void> bootHistory(WidgetTester tester) async {
      await tester.pumpWidget(harness.widget);
      // Bounded pumps so the RefreshIndicator's overscroll physics
      // doesn't keep the test waiting forever.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(HistoryPage), findsOneWidget,
          reason: 'HistoryPage should be mounted');
    }

    testWidgets('Insert CallHistory → history list updates without remount',
        (tester) async {
      await bootHistory(tester);

      expect(find.text('Lịch sử trống.'), findsOneWidget,
          reason: 'Should show empty state when no rows exist');

      await harness.db.insert(_row(
        summary: 'Test scam call',
        transcript: 'OTP',
      ));

      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Lịch sử trống.'), findsNothing,
          reason: 'Empty state should disappear after insert');
      expect(find.text('Test scam call'), findsOneWidget,
          reason: 'Inserted row should appear in list');
    });

    testWidgets('Pull-to-refresh updates the list (idempotent)', (tester) async {
      await bootHistory(tester);

      await harness.db.insert(_row(summary: 'Alpha', riskLevel: 'GREEN'));
      await harness.db.insert(_row(summary: 'Beta', riskLevel: 'ORANGE'));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      final listFinder = find.byType(ListView).first;
      await tester.fling(listFinder, const Offset(0, 300), 1000);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('Search filters the list', (tester) async {
      await bootHistory(tester);

      await harness.db.insert(_row(summary: 'Green call', riskLevel: 'GREEN'));
      await harness.db
          .insert(_row(summary: 'Orange call', riskLevel: 'ORANGE'));
      await harness.db.insert(_row(summary: 'Red call', riskLevel: 'RED'));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Green call'), findsOneWidget);
      expect(find.text('Orange call'), findsOneWidget);
      expect(find.text('Red call'), findsOneWidget);

      final searchField = find.byType(EditableText).first;
      await tester.tap(searchField);
      await tester.pumpAndSettle();
      await tester.enterText(searchField, 'red');
      await tester.pumpAndSettle();
      // Wait for 300ms debounce + async SQLite query to complete.
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      expect(find.text('Red call'), findsOneWidget,
          reason: 'The RED record should be the only visible row');
      expect(find.text('Green call'), findsNothing,
          reason: 'The GREEN record should be filtered out');
      expect(find.text('Orange call'), findsNothing,
          reason: 'The ORANGE record should be filtered out');
    });
  });
}
