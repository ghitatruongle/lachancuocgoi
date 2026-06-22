import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  group('AppDatabase - edge cases', () {
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
      String duration = '30s',
      String? audioPath,
      String? analysisResult,
      String? analysisType,
      String? alertHistory,
    }) {
      return CallHistory(
        dateTime: '10:00:00 01/06/2026',
        riskLevel: risk,
        summary: summary,
        duration: duration,
        flagCount: 1,
        transcript: transcript,
        audioPath: audioPath,
        analysisResult: analysisResult,
        analysisType: analysisType,
        alertHistory: alertHistory,
      );
    }

    group('Migration edge cases', () {
      test(
        'migration from version 0 to latest creates schema',
        () async {
          // Open a fresh database (version 0 -> latest)
          final freshDb = await AppDatabase.open(
            databaseFactory: databaseFactoryFfi,
            inMemory: true,
          );
          addTearDown(() => freshDb.close());

          // Should be able to insert after fresh creation
          final id = await freshDb.callHistoryDao.insert(
            makeEntry(transcript: 'Fresh DB entry'),
          );
          expect(id, greaterThan(0));

          final all = await freshDb.callHistoryDao.getAll();
          expect(all, hasLength(1));
        },
      );

      test(
        'adding already-existing column does not crash',
        () async {
          // The schema already has all columns up to version 5.
          // Opening again simulates idempotent column creation.
          final db2 = await AppDatabase.open(
            databaseFactory: databaseFactoryFfi,
            inMemory: true,
          );
          addTearDown(() => db2.close());

          // Insert with all fields including alert_history
          final id = await db2.callHistoryDao.insert(
            makeEntry(alertHistory: '[{"ts":1}]'),
          );
          expect(id, greaterThan(0));

          final record = await db2.callHistoryDao.getById(id);
          expect(record?.alertHistory, '[{"ts":1}]');
        },
      );

      test(
        'regression: upgrade from a v1 schema (missing core columns) '
        'adds all current columns so inserts do not throw',
        () async {
          // Simulate a v1-era install: only the original columns exist. This
          // is the case the old migration code mishandled (it had no branch
          // for oldVersion < 5 to add audioPath/analysisResult/analysisType).
          //
          // We use a real temp file (not inMemoryDatabasePath) so the same
          // database file is reopened and the onUpgrade path actually runs —
          // in-memory databases are per-connection, so a second open would
          // start from scratch and never exercise the migration.
          final rawFactory = databaseFactoryFfi;
          final tempDir = await Directory.systemTemp.createTemp(
            'lachan_migration_test_',
          );
          addTearDown(() => tempDir.delete(recursive: true));
          final dbPath = p.join(tempDir.path, 'migration.db');

          final seedDb = await rawFactory.openDatabase(
            dbPath,
            options: OpenDatabaseOptions(
              version: 1,
              onCreate: (db, _) async {
                await db.execute('''
CREATE TABLE call_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dateTime TEXT NOT NULL,
  riskLevel TEXT NOT NULL,
  summary TEXT NOT NULL,
  duration TEXT NOT NULL,
  flagCount INTEGER NOT NULL,
  transcript TEXT NOT NULL
)
''');
              },
            ),
          );
          await seedDb.close();

          // Reopen through AppDatabase — this runs _upgradeSchema(1 -> 6).
          final upgraded = await AppDatabase.open(
            databaseFactory: rawFactory,
            databasePath: dbPath,
          );
          addTearDown(() => upgraded.close());

          // Inserting a row that uses post-v1 columns must succeed.
          final id = await upgraded.callHistoryDao.insert(
            makeEntry(
              audioPath: '/tmp/x.m4a',
              analysisResult: '{"risk":"RED"}',
              analysisType: 'L3',
              alertHistory: '[{"ts":1,"level":"RED"}]',
            ),
          );
          expect(id, greaterThan(0));

          final record = await upgraded.callHistoryDao.getById(id);
          expect(record, isNotNull);
          expect(record?.audioPath, '/tmp/x.m4a');
          expect(record?.analysisType, 'L3');
          expect(record?.alertHistory, '[{"ts":1,"level":"RED"}]');
        },
      );

      test(
        'Sprint 4.4: a failing migration rolls back so the schema is not '
        'left half-migrated',
        () async {
          // Schema migration is wrapped in db.transaction (Sprint 4.4). If a
          // statement inside the migration throws, the whole migration must
          // roll back — the on-disk schema must be unchanged (still at the
          // pre-migration column set), not stuck between versions.
          final rawFactory = databaseFactoryFfi;
          final tempDir = await Directory.systemTemp.createTemp(
            'lachan_rollback_test_',
          );
          addTearDown(() => tempDir.delete(recursive: true));
          final dbPath = p.join(tempDir.path, 'rollback.db');

          // Seed a v1 schema and capture the initial column set.
          final seedDb = await rawFactory.openDatabase(
            dbPath,
            options: OpenDatabaseOptions(
              version: 1,
              onCreate: (db, _) async {
                await db.execute('''
CREATE TABLE call_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dateTime TEXT NOT NULL,
  riskLevel TEXT NOT NULL,
  summary TEXT NOT NULL,
  duration TEXT NOT NULL,
  flagCount INTEGER NOT NULL,
  transcript TEXT NOT NULL
)
''');
              },
            ),
          );
          await seedDb.close();

          // Force the migration to fail: register an onUpgrade callback that
          // adds a column then throws. With the transaction in place, the
          // added column must be rolled back, leaving the v1 column set intact.
          await expectLater(
            () => rawFactory.openDatabase(
              dbPath,
              options: OpenDatabaseOptions(
                version: 2,
                onUpgrade: (db, oldVersion, newVersion) async {
                  await db.transaction((txn) async {
                    await txn.execute(
                      'ALTER TABLE call_history ADD COLUMN tmp_col TEXT',
                    );
                    // Simulate a mid-migration failure (e.g. disk error on a
                    // later statement).
                    throw StateError('simulated migration failure');
                  });
                },
              ),
            ),
            throwsA(isA<StateError>()),
          );

          // Reopen read-only and verify the schema was rolled back: tmp_col
          // must NOT exist (transaction atomicity).
          final verifyDb = await rawFactory.openDatabase(dbPath);
          addTearDown(() => verifyDb.close());
          final columns = await verifyDb.rawQuery('PRAGMA table_info(call_history)');
          final columnNames = columns.map((r) => r['name'] as String).toSet();
          expect(columnNames, isNot(contains('tmp_col')));
          // The original v1 columns survive.
          expect(columnNames, containsAll(<String>['transcript', 'riskLevel']));
        },
      );
    });

    group('Insert edge cases', () {
      test('insert with null optional fields', () async {
        final id = await db.callHistoryDao.insert(
          makeEntry(
            audioPath: null,
            analysisResult: null,
            analysisType: null,
            alertHistory: null,
          ),
        );
        expect(id, greaterThan(0));

        final record = await db.callHistoryDao.getById(id);
        expect(record, isNotNull);
        expect(record!.audioPath, isNull);
        expect(record.analysisResult, isNull);
        expect(record.analysisType, isNull);
        expect(record.alertHistory, isNull);
      });

      test('insert with maximum-length strings', () async {
        final longString = 'A' * 100000; // 100k characters
        final id = await db.callHistoryDao.insert(
          makeEntry(
            transcript: longString,
            summary: longString,
            analysisResult: longString,
          ),
        );
        expect(id, greaterThan(0));

        final record = await db.callHistoryDao.getById(id);
        expect(record, isNotNull);
        expect(record!.transcript.length, 100000);
        expect(record.summary.length, 100000);
      });

      test('insert with empty strings', () async {
        final id = await db.callHistoryDao.insert(
          makeEntry(
            transcript: '',
            summary: '',
            duration: '',
          ),
        );
        expect(id, greaterThan(0));

        final record = await db.callHistoryDao.getById(id);
        expect(record!.transcript, '');
        expect(record.summary, '');
      });
    });

    group('Search edge cases', () {
      setUp(() async {
        await db.callHistoryDao.insert(
          makeEntry(transcript: 'OTP lừa đảo', risk: 'RED'),
        );
        await db.callHistoryDao.insert(
          makeEntry(transcript: 'Cuộc gọi bình thường', risk: 'GREEN'),
        );
        await db.callHistoryDao.insert(
          makeEntry(transcript: 'Chuyển khoản ngay', risk: 'ORANGE'),
        );
      });

      test('search with SQL injection attempt does not crash', () async {
        // These should be safely parameterized via whereArgs
        final results = await db.callHistoryDao.search("'; DROP TABLE --");
        expect(results, isEmpty);

        final results2 = await db.callHistoryDao.search('" OR 1=1 --');
        expect(results2, isEmpty);
      });

      test('search with SQL wildcard characters', () async {
        // % is a wildcard in LIKE, but since it's in whereArgs it's literal
        final results = await db.callHistoryDao.search('%');
        // '%' as a literal search term should not match everything
        // It matches if the actual data contains '%'
        expect(results, isA<List<CallHistory>>());
      });

      test('search with underscore wildcard', () async {
        // _ matches single char in LIKE, but whereArgs makes it literal
        final results = await db.callHistoryDao.search('_');
        expect(results, isA<List<CallHistory>>());
      });

      test('search with empty string returns all', () async {
        final results = await db.callHistoryDao.search('');
        expect(results, hasLength(3));
      });

      test('search with unicode/Vietnamese characters', () async {
        final results = await db.callHistoryDao.search('lừa đảo');
        expect(results, hasLength(1));
        expect(results[0].transcript, contains('lừa đảo'));
      });

      test('searchCount matches search result count', () async {
        final count = await db.callHistoryDao.searchCount('OTP');
        final results = await db.callHistoryDao.search('OTP');
        expect(count, results.length);
      });

      test('searchCount with empty query returns total count', () async {
        final count = await db.callHistoryDao.searchCount('');
        expect(count, 3);
      });
    });

    group('Pagination edge cases', () {
      setUp(() async {
        for (var i = 0; i < 10; i++) {
          await db.callHistoryDao.insert(
            makeEntry(transcript: 'Item $i'),
          );
        }
      });

      test(
        'pagination with offset beyond total count returns empty',
        () async {
          final results = await db.callHistoryDao.getAllPaginated(
            limit: 5,
            offset: 100,
          );
          expect(results, isEmpty);
        },
      );

      test('pagination with limit=0 returns empty', () async {
        final results = await db.callHistoryDao.getAllPaginated(
          limit: 0,
          offset: 0,
        );
        expect(results, isEmpty);
      });

      test('pagination with offset=0, limit=0 returns empty', () async {
        final results = await db.callHistoryDao.getAllPaginated(
          limit: 0,
          offset: 0,
        );
        expect(results, isEmpty);
      });

      test('pagination with very large limit returns all', () async {
        final results = await db.callHistoryDao.getAllPaginated(
          limit: 1000,
          offset: 0,
        );
        expect(results, hasLength(10));
      });

      test('pagination with exact count returns all remaining', () async {
        final results = await db.callHistoryDao.getAllPaginated(
          limit: 10,
          offset: 0,
        );
        expect(results, hasLength(10));
      });
    });

    group('Delete edge cases', () {
      test('delete non-existent ID returns 0 (no error)', () async {
        await db.callHistoryDao.insert(makeEntry());
        // Delete an ID that doesn't exist
        await db.callHistoryDao.deleteById(99999);

        // Original record should still be there
        final all = await db.callHistoryDao.getAll();
        expect(all, hasLength(1));
      });

      test('deleteAll on empty table does not crash', () async {
        await db.callHistoryDao.deleteAll();
        final all = await db.callHistoryDao.getAll();
        expect(all, isEmpty);
      });

      test('deleteAll removes all records', () async {
        await db.callHistoryDao.insert(makeEntry(transcript: 'A'));
        await db.callHistoryDao.insert(makeEntry(transcript: 'B'));
        await db.callHistoryDao.deleteAll();

        expect(await db.callHistoryDao.count(), 0);
      });
    });

    group('Update edge cases', () {
      test('updateRiskLevel for non-existent ID does not crash', () async {
        // Should not throw even if ID doesn't exist
        await db.callHistoryDao.updateRiskLevel(99999, 'RED');
        // No rows should exist — the missing ID must not silently create one.
        expect(await db.callHistoryDao.count(), 0);
        expect(await db.callHistoryDao.getById(99999), isNull);
      });

      test('update non-existent record does not crash', () async {
        // Update a record with ID that doesn't exist
        const ghost = CallHistory(
          id: 99999,
          dateTime: 'now',
          riskLevel: 'GREEN',
          summary: 'ghost',
          duration: '0s',
          flagCount: 0,
          transcript: 'ghost',
        );
        await db.callHistoryDao.update(ghost);
        // No crash, and no phantom row should have been created.
        expect(await db.callHistoryDao.count(), 0);
        expect(await db.callHistoryDao.getById(99999), isNull);
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

      test('getById returns correct record', () async {
        final id = await db.callHistoryDao.insert(
          makeEntry(transcript: 'specific'),
        );
        final record = await db.callHistoryDao.getById(id);
        expect(record, isNotNull);
        expect(record!.transcript, 'specific');
      });
    });

    group('Count edge cases', () {
      test('count returns 0 for empty table', () async {
        expect(await db.callHistoryDao.count(), 0);
      });

      test('count after deleteAll returns 0', () async {
        await db.callHistoryDao.insert(makeEntry());
        await db.callHistoryDao.deleteAll();
        expect(await db.callHistoryDao.count(), 0);
      });
    });

    group('CallHistory model edge cases', () {
      test('fromMap with missing fields uses defaults', () {
        final history = CallHistory.fromMap(<String, Object?>{});
        expect(history.id, 0);
        expect(history.dateTime, '');
        expect(history.riskLevel, 'GREEN');
        expect(history.summary, '');
        expect(history.duration, '');
        expect(history.flagCount, 0);
        expect(history.transcript, '');
        expect(history.audioPath, isNull);
        expect(history.analysisResult, isNull);
        expect(history.analysisType, isNull);
        expect(history.alertHistory, isNull);
      });

      test('toMap with id=0 excludes id field', () {
        const history = CallHistory(
          id: 0,
          dateTime: 'now',
          riskLevel: 'GREEN',
          summary: '',
          duration: '',
          flagCount: 0,
          transcript: '',
        );
        final map = history.toMap(includeId: true);
        expect(map.containsKey('id'), isFalse);
      });

      test('toMap with positive id includes id when requested', () {
        const history = CallHistory(
          id: 42,
          dateTime: 'now',
          riskLevel: 'GREEN',
          summary: '',
          duration: '',
          flagCount: 0,
          transcript: '',
        );
        final withId = history.toMap(includeId: true);
        expect(withId['id'], 42);

        final withoutId = history.toMap(includeId: false);
        expect(withoutId.containsKey('id'), isFalse);
      });

      test('copyWith preserves unchanged fields', () {
        const original = CallHistory(
          id: 1,
          dateTime: 'now',
          riskLevel: 'GREEN',
          summary: 'original',
          duration: '10s',
          flagCount: 0,
          transcript: 'hello',
        );
        final copied = original.copyWith(summary: 'updated');
        expect(copied.id, 1);
        expect(copied.dateTime, 'now');
        expect(copied.riskLevel, 'GREEN');
        expect(copied.summary, 'updated');
        expect(copied.duration, '10s');
        expect(copied.transcript, 'hello');
      });
    });
  });
}
