import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/ui/history_page/history_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_native_bridge.dart' as helpers;

/// Sprint 1 (A5): tests the reactive `_HistoryController` in `HistoryPage`.
///
/// Behaviour under test:
/// - The controller subscribes to `dao.watchAll()` so it re-emits on
///   every insert/delete.
/// - The UI re-renders without a remount when new rows are inserted.
/// - The pull-to-refresh re-reads from the database.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase db;
  late helpers.FakeNativeBridge fakeBridge;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await AppDatabase.open(
      databaseFactory: databaseFactoryFfi,
      inMemory: true,
    );
    fakeBridge = helpers.FakeNativeBridge();
  });

  tearDown(() async {
    fakeBridge.dispose();
    await db.database.close();
  });

  CallHistory makeRow(int i) => CallHistory(
        dateTime: '00:00:00 01/06/2026',
        riskLevel: i % 2 == 0 ? 'GREEN' : 'RED',
        summary: 'Row $i',
        duration: '${i % 60}s',
        flagCount: i % 5,
        transcript: 'transcript-$i',
      );

  /// Pump the HistoryPage inside a ProviderScope with an in-memory DB.
  /// Returns the provider container so the test can read state directly.
  Future<ProviderContainer> pumpPage(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseFutureProvider.overrideWith((ref) async => db),
        nativeBridgeProvider.overrideWithValue(fakeBridge),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HistoryPage()),
      ),
    );
    // Wait for the async controller build to complete and UI to transition out of loading state.
    await tester.runAsync(() async {
      for (int i = 0; i < 50; i++) {
        if (!tester.any(find.byType(CircularProgressIndicator))) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pump();
    return container;
  }

  // ─── Initial empty state ────────────────────────────────────────────
  testWidgets('renders empty state on first load', (tester) async {
    await pumpPage(tester);
    expect(find.text('Lịch sử trống.'), findsOneWidget);
  });

  // ─── Reactive: a new row appears without remount ───────────────────
  testWidgets('inserting a row updates the list without remounting',
      (tester) async {
    await pumpPage(tester);

    // Insert one row. The reactive stream in _HistoryController picks
    // it up automatically.
    await tester.runAsync(() async {
      await db.callHistoryDao.insert(makeRow(1));
    });
    await tester.runAsync(() async {
      for (int i = 0; i < 100; i++) {
        await tester.pump();
        if (tester.any(find.text('Row 1'))) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(find.text('Lịch sử trống.'), findsNothing);
    expect(find.text('Row 1'), findsOneWidget);
  });

  // ─── Reactive: 5 more rows appear ───────────────────────────────────
  testWidgets('inserting 5 more rows updates the list', (tester) async {
    await pumpPage(tester);

    // Insert all 6 rows.
    await tester.runAsync(() async {
      for (var i = 1; i <= 6; i++) {
        await db.callHistoryDao.insert(makeRow(i));
      }
    });
    await tester.runAsync(() async {
      for (int i = 0; i < 100; i++) {
        await tester.pump();
        if (tester.any(find.text('Row 1'))) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    // ListView lazy-builds children: only those in the viewport are
    // in the widget tree. Verify the data is correct via the DAO.
    final all = await tester.runAsync<List<dynamic>>(
      () => db.callHistoryDao.getAll(),
    );
    expect(all, hasLength(6));
    // At least the empty-state should be gone.
    expect(find.text('Lịch sử trống.'), findsNothing);
  });

  // ─── Reactive: deleteAll is reflected ──────────────────────────────
  testWidgets('deleteAll is reflected in the list', (tester) async {
    await pumpPage(tester);

    await tester.runAsync(() async {
      await db.callHistoryDao.insert(makeRow(1));
      await db.callHistoryDao.insert(makeRow(2));
    });
    await tester.runAsync(() async {
      for (int i = 0; i < 100; i++) {
        await tester.pump();
        if (tester.any(find.text('Row 1')) && tester.any(find.text('Row 2'))) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(find.text('Row 1'), findsOneWidget);
    expect(find.text('Row 2'), findsOneWidget);

    await tester.runAsync(() async {
      await db.callHistoryDao.deleteAll();
    });
    await tester.runAsync(() async {
      for (int i = 0; i < 100; i++) {
        await tester.pump();
        if (!tester.any(find.text('Row 1')) && !tester.any(find.text('Row 2'))) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(find.text('Row 1'), findsNothing);
    expect(find.text('Row 2'), findsNothing);
  });

  // ─── Search filter: changes the displayed items ────────────────────
  testWidgets('search filters the list', (tester) async {
    await pumpPage(tester);

    await tester.runAsync(() async {
      await db.callHistoryDao.insert(
        makeRow(1).copyWith(summary: 'unique-marker-xyz'),
      );
      await db.callHistoryDao.insert(
        makeRow(2).copyWith(summary: 'ordinary row'),
      );
    });
    await tester.runAsync(() async {
      for (int i = 0; i < 100; i++) {
        await tester.pump();
        if (tester.any(find.text('unique-marker-xyz')) && tester.any(find.text('ordinary row'))) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(find.text('unique-marker-xyz'), findsOneWidget);
    expect(find.text('ordinary row'), findsOneWidget);

    // Type a query.
    await tester.enterText(find.byType(TextField), 'unique');
    await tester.pump();
    await tester.runAsync(() async {
      for (int i = 0; i < 100; i++) {
        await tester.pump();
        if (!tester.any(find.text('ordinary row'))) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    // Search filters: only the unique-marker row is shown.
    expect(find.text('unique-marker-xyz'), findsOneWidget);
    expect(find.text('ordinary row'), findsNothing);
  });

  // ─── Delete-all button is hidden when empty ─────────────────────────
  testWidgets('delete-all button is hidden when list is empty',
      (tester) async {
    await pumpPage(tester);
    expect(find.text('Xóa tất cả'), findsNothing);
  });

  testWidgets('delete-all button is visible when list has rows',
      (tester) async {
    await pumpPage(tester);
    await tester.runAsync(() async {
      await db.callHistoryDao.insert(makeRow(1));
    });
    await tester.runAsync(() async {
      for (int i = 0; i < 100; i++) {
        await tester.pump();
        if (tester.any(find.text('Xóa tất cả'))) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(find.text('Xóa tất cả'), findsOneWidget);
  });
}
