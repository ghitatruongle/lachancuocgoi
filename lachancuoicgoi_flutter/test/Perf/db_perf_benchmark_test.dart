@Tags(['perf'])
library;

// ignore_for_file: invalid_annotation_target
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Slow benchmark tests. Tagged so the default CI invocation
/// (`flutter test --exclude-tags perf`) skips them. Run them with
/// `flutter test --tags perf` to keep the baseline numbers in the
/// sprint-4 handoff document up to date.
///
/// Performance budget (Windows + sqflite_common_ffi):
///   - 1000-row insert          : < 5s
///   - 1000-row getAll()         : < 200ms
///   - 1000-row substring search : < 500ms
///   - watchAll re-emit latency  : < 100ms
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

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

  CallHistory makeRow(int i) => CallHistory(
        dateTime: '00:00:00 01/06/2026',
        riskLevel: i % 2 == 0 ? 'GREEN' : 'RED',
        summary: 'Summary $i',
        duration: '${i % 60}s',
        flagCount: i % 5,
        transcript: 'transcript-$i ${"x" * 50}',
        recordingError: i % 100 == 0 ? 'noAudio' : null,
      );

  test('insert 1000 rows in < 5s', () async {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      await db.callHistoryDao.insert(makeRow(i));
    }
    sw.stop();
    expect(
      sw.elapsedMilliseconds,
      lessThan(5000),
      reason: '1000-row insert took ${sw.elapsedMilliseconds}ms '
          '(budget 5000ms)',
    );
  });

  test('getAll on 1000 rows in < 200ms', () async {
    for (var i = 0; i < 1000; i++) {
      await db.callHistoryDao.insert(makeRow(i));
    }
    final sw = Stopwatch()..start();
    final rows = await db.callHistoryDao.getAll();
    sw.stop();
    expect(rows, hasLength(1000));
    expect(
      sw.elapsedMilliseconds,
      lessThan(200),
      reason: 'getAll(1000) took ${sw.elapsedMilliseconds}ms (budget 200ms)',
    );
  });

  test('search common substring on 1000 rows in < 500ms', () async {
    for (var i = 0; i < 1000; i++) {
      await db.callHistoryDao.insert(makeRow(i));
    }
    final sw = Stopwatch()..start();
    final hits = await db.callHistoryDao.search('Summary', limit: 2000);
    sw.stop();
    expect(hits, hasLength(1000));
    expect(
      sw.elapsedMilliseconds,
      lessThan(500),
      reason: 'search("Summary") on 1000 rows took '
          '${sw.elapsedMilliseconds}ms (budget 500ms)',
    );
  });

  test('watchAll re-emit latency after insert < 100ms', () async {
    final stopwatch = Stopwatch();
    final firstEmission = Completer<void>();
    final secondEmission = Completer<void>();

    final sub = db.callHistoryDao.watchAll().listen((items) {
      if (items.isEmpty && !firstEmission.isCompleted) {
        firstEmission.complete();
      } else if (items.isNotEmpty && !secondEmission.isCompleted) {
        stopwatch.start();
        secondEmission.complete();
      }
    });
    addTearDown(sub.cancel);

    await firstEmission.future.timeout(const Duration(seconds: 2));
    await db.callHistoryDao.insert(makeRow(1));
    await secondEmission.future.timeout(const Duration(seconds: 2));
    stopwatch.stop();

    expect(
      stopwatch.elapsedMilliseconds,
      lessThan(100),
      reason: 'watchAll re-emit took ${stopwatch.elapsedMilliseconds}ms '
          '(budget 100ms)',
    );
  });

  test('getAllPaginated on 1000 rows completes in < 200ms', () async {
    for (var i = 0; i < 1000; i++) {
      await db.callHistoryDao.insert(makeRow(i));
    }
    final sw = Stopwatch()..start();
    final page = await db.callHistoryDao.getAllPaginated(
      limit: 50,
      offset: 0,
    );
    sw.stop();
    expect(page, hasLength(50));
    expect(
      sw.elapsedMilliseconds,
      lessThan(200),
      reason: 'getAllPaginated(50) on 1000 rows took '
          '${sw.elapsedMilliseconds}ms (budget 200ms)',
    );
  });

  test('schema version is exactly 6 (Sprint 1+2)', () {
    expect(AppDatabase.schemaVersion, 6);
  });

  test('recordingError column exists in v6 schema', () async {
    final rows = await db.database.rawQuery('PRAGMA table_info(call_history)');
    final columnNames = rows.map((r) => r['name'] as String).toSet();
    expect(columnNames, contains('recordingError'));
    expect(columnNames, contains('alert_history'));
    expect(columnNames, contains('id'));
    expect(columnNames, contains('dateTime'));
    expect(columnNames, contains('riskLevel'));
  });

  test('all 5 allowed recordingError values survive insertion', () async {
    // Note: copyWith can't set recordingError to null (it uses `??`
    // semantics). We test the non-null values via copyWith and the
    // null value via a fresh construction.
    for (final v in const ['noAudio', 'sttFailed', 'partial', 'killed']) {
      final id = await db.callHistoryDao.insert(
        makeRow(0).copyWith(recordingError: v),
      );
      final restored = await db.callHistoryDao.getById(id);
      expect(restored, isNotNull);
      expect(restored!.recordingError, v);
    }
    // null case: construct fresh (no copyWith).
    final idNull = await db.callHistoryDao.insert(
      const CallHistory(
        dateTime: '00:00:00 01/06/2026',
        riskLevel: 'GREEN',
        summary: 's',
        duration: '0s',
        flagCount: 0,
        transcript: 't',
        recordingError: null,
      ),
    );
    final restoredNull = await db.callHistoryDao.getById(idNull);
    expect(restoredNull, isNotNull);
    expect(restoredNull!.recordingError, isNull);
  });
}
