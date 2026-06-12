import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/ui/result_page/result_page.dart';

import 'test_helpers.dart';

void main() {
  Future<Widget> buildPage({
    required int historyId,
    String initialRoute = '/result/1',
  }) async {
    return ProviderScope(
      overrides: [
        // Provide a failing database future so tests don't need sqflite FFI.
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
            GoRoute(
              path: '/history',
              builder: (_, __) => const Scaffold(body: Text('History')),
            ),
            GoRoute(
              path: '/result/:id',
              builder: (_, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                return ResultPage(historyId: id);
              },
            ),
          ],
        ),
      ),
    );
  }

  group('ResultPage', () {
    testWidgets('shows loading indicator initially', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseFutureProvider.overrideWith(
            (ref) => Completer<AppDatabase>().future,
          ),
          bridgeOverride(),
          settingsOverride(),
          devModeOverride(),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ResultPage(historyId: 1),
          ),
        ),
      );

      // First frame should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      container.dispose();
    });

    testWidgets('shows error when database fails', (tester) async {
      await tester.pumpWidget(await buildPage(historyId: 1));
      await tester.pumpAndSettle();

      // Should show an error message because the DB future threw
      expect(find.textContaining('Lỗi'), findsOneWidget);
    });

    testWidgets('back button navigates to home on error state', (tester) async {
      await tester.pumpWidget(await buildPage(historyId: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });
  });
}
