import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lachancuocgoi_flutter/data/alert_history_entry.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/alert_history_section.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    );
  }

  AlertHistoryEntry makeEntry({
    String riskLevel = 'RED',
    String displayedReason = 'Test reason',
    int alertCount = 1,
    int? timestamp,
    List<String>? allReasons,
  }) {
    return AlertHistoryEntry(
      timestamp: timestamp ?? DateTime(2026, 1, 1, 10, 30, 0).millisecondsSinceEpoch,
      analysisLevel: 'L2',
      riskLevel: riskLevel,
      alertCount: alertCount,
      displayedReason: displayedReason,
      allReasons: allReasons,
    );
  }

  group('AlertHistorySection', () {
    testWidgets('renders empty state when no alerts', (tester) async {
      await tester.pumpWidget(wrap(
        const AlertHistorySection(alertHistory: []),
      ));
      await tester.pumpAndSettle();

      // Empty list => SizedBox.shrink
      expect(find.byType(Card), findsNothing);
      expect(find.textContaining('LỊCH SỬ CẢNH BÁO'), findsNothing);
    });

    testWidgets('shows section header when alerts exist', (tester) async {
      await tester.pumpWidget(wrap(
        AlertHistorySection(
          alertHistory: [makeEntry()],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('LỊCH SỬ CẢNH BÁO'), findsOneWidget);
    });

    testWidgets('shows alert entries with timestamps', (tester) async {
      final entry = makeEntry(
        timestamp: DateTime(2026, 1, 1, 14, 30, 45).millisecondsSinceEpoch,
        displayedReason: 'Phát hiện lừa đảo OTP',
      );
      await tester.pumpWidget(wrap(
        AlertHistorySection(alertHistory: [entry]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('14:30:45'), findsOneWidget);
      expect(find.text('Phát hiện lừa đảo OTP'), findsOneWidget);
    });

    testWidgets('shows risk level colors for RED', (tester) async {
      final entry = makeEntry(riskLevel: 'RED');
      await tester.pumpWidget(wrap(
        AlertHistorySection(alertHistory: [entry]),
      ));
      await tester.pumpAndSettle();

      // RED risk level shows red circle emoji
      expect(find.textContaining('🔴'), findsOneWidget);
    });

    testWidgets('shows risk level colors for ORANGE', (tester) async {
      final entry = makeEntry(riskLevel: 'ORANGE');
      await tester.pumpWidget(wrap(
        AlertHistorySection(alertHistory: [entry]),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('🟠'), findsOneWidget);
    });

    testWidgets('shows multiple alert entries', (tester) async {
      final entries = [
        makeEntry(
          riskLevel: 'RED',
          displayedReason: 'First alert',
          timestamp: DateTime(2026, 1, 1, 10, 0, 0).millisecondsSinceEpoch,
        ),
        makeEntry(
          riskLevel: 'ORANGE',
          displayedReason: 'Second alert',
          timestamp: DateTime(2026, 1, 1, 10, 5, 0).millisecondsSinceEpoch,
        ),
      ];
      await tester.pumpWidget(wrap(
        AlertHistorySection(alertHistory: entries),
      ));
      await tester.pumpAndSettle();

      // Entries are shown in reverse order
      expect(find.text('First alert'), findsOneWidget);
      expect(find.text('Second alert'), findsOneWidget);
    });

    testWidgets('shows alert count when count > 1', (tester) async {
      final entry = makeEntry(
        alertCount: 3,
        riskLevel: 'RED',
      );
      await tester.pumpWidget(wrap(
        AlertHistorySection(alertHistory: [entry]),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 cảnh báo'), findsOneWidget);
    });

    testWidgets('shows detail reasons when multiple reasons exist', (tester) async {
      final entry = makeEntry(
        allReasons: ['Reason A', 'Reason B', 'Reason C'],
      );
      await tester.pumpWidget(wrap(
        AlertHistorySection(alertHistory: [entry]),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Chi tiết:'), findsOneWidget);
    });
  });
}
