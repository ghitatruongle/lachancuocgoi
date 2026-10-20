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

  testWidgets('renders empty state on first load', (tester) async {
    await pumpPage(tester);
    expect(find.text('Lịch sử trống.'), findsOneWidget);
  });

  testWidgets('inserting a row updates the list without remounting', (
    tester,
  ) async {
    await pumpPage(tester);

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

  testWidgets('inserting 5 more rows updates the list', (tester) async {
    await pumpPage(tester);

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

    final all = await tester.runAsync<List<dynamic>>(
      () => db.callHistoryDao.getAll(),
    );
    expect(all, hasLength(6));

    expect(find.text('Lịch sử trống.'), findsNothing);
  });

  testWidgets('deleteAll is reflected in the list', (tester) async {
    await pumpPage(tester);

    await tester.runAsync(() async {
      await db.callHistoryDao.insert(makeRow(1));
      await db.callHistoryDao.insert(makeRow(2));
    });
    await tester.runAsync(() async {
      for (int i = 0; i < 100; i++) {
        await tester.pump();
        if (tester.any(find.text('Row 1')) && tester.any(find.text('Row 2'))) {
          break;
        }
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
        if (!tester.any(find.text('Row 1')) &&
            !tester.any(find.text('Row 2'))) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(find.text('Row 1'), findsNothing);
    expect(find.text('Row 2'), findsNothing);
  });

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
        if (tester.any(find.text('unique-marker-xyz')) &&
            tester.any(find.text('ordinary row'))) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(find.text('unique-marker-xyz'), findsOneWidget);
    expect(find.text('ordinary row'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'unique');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      for (int i = 0; i < 100; i++) {
        await tester.pump();
        if (!tester.any(find.text('ordinary row'))) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(find.text('unique-marker-xyz'), findsOneWidget);
    expect(find.text('ordinary row'), findsNothing);
  });

  testWidgets('delete-all button is hidden when list is empty', (tester) async {
    await pumpPage(tester);
    expect(find.text('Xóa tất cả'), findsNothing);
  });

  testWidgets('delete-all button is visible when list has rows', (
    tester,
  ) async {
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
