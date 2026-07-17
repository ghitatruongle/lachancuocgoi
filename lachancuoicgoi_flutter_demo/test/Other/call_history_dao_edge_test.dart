import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  group('CallHistoryDao - edge cases', () {
    late AppDatabase db;

    setUp(() async {
      db = await AppDatabase.open(
        databaseFactory: databaseFactoryFfi,
        inMemory: true,
      );
    });

    tearDown(() async {
      await db.database.close();
    });

    CallHistory makeEntry({
      String risk = 'RED',
      String transcript = 'Test transcript',
      String summary = 'Summary',
    }) {
      return CallHistory(
        dateTime: '10:00:00 01/06/2026',
        riskLevel: risk,
        summary: summary,
        duration: '30s',
        flagCount: 1,
        transcript: transcript,
      );
    }

    group('Update non-existent record', () {
      test('update non-existent record does not throw', () async {
        const ghost = CallHistory(
          id: 99999,
          dateTime: 'now',
          riskLevel: 'GREEN',
          summary: 'ghost',
          duration: '0s',
          flagCount: 0,
          transcript: 'ghost',
        );

        // Should not throw — SQLite UPDATE affects 0 rows silently
        await db.callHistoryDao.update(ghost);

        // Verify no records were affected
        final all = await db.callHistoryDao.getAll();
        expect(all, isEmpty);
      });

      test('updateRiskLevel for non-existent ID does not throw', () async {
        // Insert one record to ensure the table is not empty
        await db.callHistoryDao.insert(makeEntry());

        // Update non-existent ID
        await db.callHistoryDao.updateRiskLevel(99999, 'ORANGE');

        // Original record should be unchanged
        final all = await db.callHistoryDao.getAll();
        expect(all, hasLength(1));
        expect(all[0].riskLevel, 'RED');
      });
    });

    group('Delete by non-existent ID', () {
      test('deleteById with non-existent ID does not throw', () async {
        await db.callHistoryDao.insert(makeEntry(transcript: 'Keep me'));

        // Delete non-existent
        await db.callHistoryDao.deleteById(99999);

        // Original record survives
        final all = await db.callHistoryDao.getAll();
        expect(all, hasLength(1));
        expect(all[0].transcript, 'Keep me');
      });

      test('deleteById on empty table does not throw', () async {
        await db.callHistoryDao.deleteById(1);
        final all = await db.callHistoryDao.getAll();
        expect(all, isEmpty);
      });
    });

    group('Search edge cases', () {
      setUp(() async {
        await db.callHistoryDao.insert(
          makeEntry(transcript: 'OTP lừa đảo ngân hàng', risk: 'RED'),
        );
        await db.callHistoryDao.insert(
          makeEntry(transcript: 'Cuộc gọi bình thường', risk: 'GREEN'),
        );
        await db.callHistoryDao.insert(
          makeEntry(transcript: 'Chuyển khoản ngay lập tức', risk: 'ORANGE'),
        );
      });

      test('search with empty string returns all records', () async {
        final results = await db.callHistoryDao.search('');
        expect(results, hasLength(3));
      });

      test('search with SQL wildcard % does not break query', () async {
        // % is LIKE wildcard but should be treated as literal in parameterized query
        final results = await db.callHistoryDao.search('%');
        // Should not crash; results depend on actual data containing '%'
        expect(results, isA<List<CallHistory>>());
      });

      test('search with SQL wildcard _ does not break query', () async {
        final results = await db.callHistoryDao.search('_');
        expect(results, isA<List<CallHistory>>());
      });

      test('search with SQL injection string does not break query', () async {
        final results = await db.callHistoryDao.search(
          "'; DROP TABLE call_history; --",
        );
        expect(results, isEmpty);

        // Table should still exist and work
        final count = await db.callHistoryDao.count();
        expect(count, 3);
      });

      test('search with LIKE injection does not return all rows', () async {
        final results = await db.callHistoryDao.search("' OR '1'='1");
        expect(results, isEmpty);
      });

      test('search with very long query string does not crash', () async {
        final longQuery = 'a' * 10000;
        final results = await db.callHistoryDao.search(longQuery);
        expect(results, isEmpty);
      });

      test('searchCount with empty string returns total count', () async {
        final count = await db.callHistoryDao.searchCount('');
        expect(count, 3);
      });

      test('searchCount with no match returns 0', () async {
        final count = await db.callHistoryDao.searchCount('nonexistent_xyz');
        expect(count, 0);
      });
    });

    group('getAllPaginated edge cases', () {
      setUp(() async {
        for (var i = 0; i < 10; i++) {
          await db.callHistoryDao.insert(makeEntry(transcript: 'Item $i'));
        }
      });

      test('getAllPaginated with limit=0 returns empty', () async {
        final results = await db.callHistoryDao.getAllPaginated(
          limit: 0,
          offset: 0,
        );
        expect(results, isEmpty);
      });

      test('getAllPaginated with offset=0, limit=0 returns empty', () async {
        final results = await db.callHistoryDao.getAllPaginated(
          limit: 0,
          offset: 0,
        );
        expect(results, isEmpty);
      });

      test('getAllPaginated with offset beyond total returns empty', () async {
        final results = await db.callHistoryDao.getAllPaginated(
          limit: 10,
          offset: 100,
        );
        expect(results, isEmpty);
      });

      test('getAllPaginated returns correct page with large offset', () async {
        final page = await db.callHistoryDao.getAllPaginated(
          limit: 3,
          offset: 7,
        );
        expect(page, hasLength(3));
      });

      test('getAllPaginated default parameters return first 20', () async {
        // Insert 25 items
        for (var i = 10; i < 25; i++) {
          await db.callHistoryDao.insert(makeEntry(transcript: 'Extra $i'));
        }
        final results = await db.callHistoryDao.getAllPaginated();
        expect(results, hasLength(20));
      });
    });

    group('watchAll stream edge cases', () {
      test('watchAll emits on delete', () async {
        // Insert a record first
        final id = await db.callHistoryDao.insert(
          makeEntry(transcript: 'To be deleted'),
        );

        final emissions = <List<CallHistory>>[];
        final firstEmission = Completer<void>();
        final deleteEmission = Completer<void>();

        final subscription = db.callHistoryDao.watchAll().listen((items) {
          emissions.add(items);
          if (emissions.length == 1 && !firstEmission.isCompleted) {
            firstEmission.complete();
          }
          if (emissions.length == 2 && !deleteEmission.isCompleted) {
            deleteEmission.complete();
          }
        });
        addTearDown(subscription.cancel);

        // Wait for initial emission
        await firstEmission.future.timeout(const Duration(seconds: 2));
        expect(emissions.last, hasLength(1));

        // Delete the record
        await db.callHistoryDao.deleteById(id);

        // Wait for delete emission
        await deleteEmission.future.timeout(const Duration(seconds: 2));
        expect(emissions.last, isEmpty);
      });

      test('watchAll emits on updateRiskLevel', () async {
        final id = await db.callHistoryDao.insert(makeEntry(risk: 'GREEN'));

        final emissions = <List<CallHistory>>[];
        final firstEmission = Completer<void>();
        final updateEmission = Completer<void>();

        final subscription = db.callHistoryDao.watchAll().listen((items) {
          emissions.add(items);
          if (emissions.length == 1 && !firstEmission.isCompleted) {
            firstEmission.complete();
          }
          if (emissions.length == 2 && !updateEmission.isCompleted) {
            updateEmission.complete();
          }
        });
        addTearDown(subscription.cancel);

        await firstEmission.future.timeout(const Duration(seconds: 2));
        expect(emissions.last.first.riskLevel, 'GREEN');

        await db.callHistoryDao.updateRiskLevel(id, 'RED');

        await updateEmission.future.timeout(const Duration(seconds: 2));
        expect(emissions.last.first.riskLevel, 'RED');
      });

      test('watchAll emits on deleteAll', () async {
        await db.callHistoryDao.insert(makeEntry(transcript: 'A'));
        await db.callHistoryDao.insert(makeEntry(transcript: 'B'));

        final emissions = <List<CallHistory>>[];
        final firstEmission = Completer<void>();
        final deleteAllEmission = Completer<void>();

        final subscription = db.callHistoryDao.watchAll().listen((items) {
          emissions.add(items);
          if (emissions.length == 1 && !firstEmission.isCompleted) {
            firstEmission.complete();
          }
          if (emissions.length == 2 && !deleteAllEmission.isCompleted) {
            deleteAllEmission.complete();
          }
        });
        addTearDown(subscription.cancel);

        await firstEmission.future.timeout(const Duration(seconds: 2));
        expect(emissions.last, hasLength(2));

        await db.callHistoryDao.deleteAll();

        await deleteAllEmission.future.timeout(const Duration(seconds: 2));
        expect(emissions.last, isEmpty);
      });
    });

    group('dispose edge cases', () {
      test('dispose closes stream controller', () async {
        final dao = db.callHistoryDao;

        // Start listening
        final emissions = <List<CallHistory>>[];
        final sub = dao.watchAll().listen((items) {
          emissions.add(items);
        });
        addTearDown(sub.cancel);

        // Wait for initial emission
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(emissions, isNotEmpty);

        // Dispose should close the controller
        await dao.dispose();

        // Subscription should be done
        await sub.asFuture<void>();
      });
    });

    group('getById edge cases', () {
      test('getById returns null for non-existent ID', () async {
        final result = await db.callHistoryDao.getById(99999);
        expect(result, isNull);
      });

      test('getById (alias check) returns null for non-existent ID', () async {
        final result = await db.callHistoryDao.getById(99999);
        expect(result, isNull);
      });

      test('getById after insert returns correct record', () async {
        final id = await db.callHistoryDao.insert(
          makeEntry(transcript: 'findme'),
        );
        final record = await db.callHistoryDao.getById(id);
        expect(record, isNotNull);
        expect(record!.transcript, 'findme');
        expect(record.id, id);
      });
    });

    group('Multiple operations in sequence', () {
      test('insert-update-delete cycle works correctly', () async {
        // Insert
        final id = await db.callHistoryDao.insert(
          makeEntry(transcript: 'original', risk: 'GREEN'),
        );
        expect(await db.callHistoryDao.count(), 1);

        // Update
        await db.callHistoryDao.updateRiskLevel(id, 'RED');
        final updated = await db.callHistoryDao.getById(id);
        expect(updated!.riskLevel, 'RED');

        // Delete
        await db.callHistoryDao.deleteById(id);
        expect(await db.callHistoryDao.count(), 0);
        expect(await db.callHistoryDao.getById(id), isNull);
      });

      test('rapid sequential inserts maintain order', () async {
        for (var i = 0; i < 50; i++) {
          await db.callHistoryDao.insert(makeEntry(transcript: 'Rapid $i'));
        }

        final all = await db.callHistoryDao.getAll();
        expect(all, hasLength(50));

        // DESC order: highest ID first
        expect(all.first.transcript, 'Rapid 49');
        expect(all.last.transcript, 'Rapid 0');
      });
    });
  });
}
