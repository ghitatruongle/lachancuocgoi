import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/ui/history_page/history_page.dart';

import 'test_helpers.dart';

void main() {
  Future<Widget> buildPage({String initialRoute = '/history'}) async {
    return ProviderScope(
      overrides: [
        // Provide a never-resolving future so the page stays in loading/error
        // state without needing sqflite FFI.
        appDatabaseFutureProvider.overrideWith(
          (ref) => Future<AppDatabase>.error(
            UnsupportedError('Database not available in tests'),
          ),
        ),
        bridgeOverride(),
        settingsOverride(),
        devModeOverride(),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: initialRoute,
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('Home')),
            ),
            GoRoute(path: '/history', builder: (_, __) => const HistoryPage()),
            GoRoute(
              path: '/result/:id',
              builder: (_, __) => const Scaffold(body: Text('Result')),
            ),
          ],
        ),
      ),
    );
  }

  group('HistoryPage', () {
    testWidgets('shows app bar title', (tester) async {
      await tester.pumpWidget(await buildPage());
      await tester.pump();

      expect(find.text('Lịch sử giám sát'), findsOneWidget);
    });

    testWidgets('shows settings button', (tester) async {
      await tester.pumpWidget(await buildPage());
      await tester.pump();

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('back button navigates to home', (tester) async {
      await tester.pumpWidget(await buildPage());
      // Let the router render but don't wait for DB
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('settings button opens dialog', (tester) async {
      await tester.pumpWidget(await buildPage());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Cài đặt'), findsWidgets);
    });

    testWidgets('shows error state when database fails', (tester) async {
      await tester.pumpWidget(await buildPage());
      await tester.pumpAndSettle();

      // The history provider should show error because the DB future threw
      expect(find.textContaining('Lỗi'), findsOneWidget);
    });
  });
}
