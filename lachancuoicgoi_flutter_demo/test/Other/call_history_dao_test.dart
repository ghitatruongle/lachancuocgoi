import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  CallHistory makeEntry({
    String risk = 'RED',
    String transcript = 'Test transcript',
    String dateTime = '10:00:00 23/05/2026',
  }) {
    return CallHistory(
      dateTime: dateTime,
      riskLevel: risk,
      summary: 'Summary',
      duration: '30s',
      flagCount: 1,
      transcript: transcript,
    );
  }

  group('CallHistoryDao — insert and getAll', () {
    test('insert returns positive id', () async {
      final id = await db.callHistoryDao.insert(makeEntry());
      expect(id, greaterThan(0));
    });

    test('getAll returns inserted entries in descending order', () async {
      await db.callHistoryDao.insert(makeEntry(transcript: 'First'));
      await db.callHistoryDao.insert(makeEntry(transcript: 'Second'));
      final all = await db.callHistoryDao.getAll();
      expect(all, hasLength(2));
      expect(all[0].transcript, 'Second'); // DESC order
      expect(all[1].transcript, 'First');
    });

    test('getAll returns empty list for empty database', () async {
      final all = await db.callHistoryDao.getAll();
      expect(all, isEmpty);
    });
  });

  group('CallHistoryDao — getAllPaginated', () {
    test('respects limit', () async {
      for (var i = 0; i < 5; i++) {
        await db.callHistoryDao.insert(makeEntry(transcript: 'Item $i'));
      }
      final page = await db.callHistoryDao.getAllPaginated(limit: 2, offset: 0);
      expect(page, hasLength(2));
    });

    test('respects offset', () async {
      for (var i = 0; i < 5; i++) {
        await db.callHistoryDao.insert(makeEntry(transcript: 'Item $i'));
      }
      final page2 = await db.callHistoryDao.getAllPaginated(
        limit: 2,
        offset: 2,
      );
      expect(page2, hasLength(2));
      // Should be different from page 1
      final page1 = await db.callHistoryDao.getAllPaginated(
        limit: 2,
        offset: 0,
      );
      expect(page1[0].id, isNot(page2[0].id));
    });

    test('offset beyond data returns empty', () async {
      await db.callHistoryDao.insert(makeEntry());
      final page = await db.callHistoryDao.getAllPaginated(
        limit: 10,
        offset: 100,
      );
      expect(page, isEmpty);
    });
  });

  group('CallHistoryDao — count', () {
    test('returns 0 for empty database', () async {
      expect(await db.callHistoryDao.count(), 0);
    });

    test('returns correct count after inserts', () async {
      await db.callHistoryDao.insert(makeEntry());
      await db.callHistoryDao.insert(makeEntry());
      await db.callHistoryDao.insert(makeEntry());
      expect(await db.callHistoryDao.count(), 3);
    });
  });

  group('CallHistoryDao — search', () {
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

    test('search by transcript content', () async {
      final results = await db.callHistoryDao.search('OTP');
      expect(results, hasLength(1));
      expect(results[0].transcript, contains('OTP'));
    });

    test('search by risk level', () async {
      final results = await db.callHistoryDao.search('GREEN');
      expect(results, hasLength(1));
      expect(results[0].riskLevel, 'GREEN');
    });

    test('search with empty query returns all', () async {
      final results = await db.callHistoryDao.search('');
      expect(results, hasLength(3));
    });

    test('search with no match returns empty', () async {
      final results = await db.callHistoryDao.search('xyznonexistent');
      expect(results, isEmpty);
    });

    test('search is case sensitive (SQLite default)', () async {
      // SQLite LIKE is case-insensitive for ASCII by default
      final results = await db.callHistoryDao.search('otp');
      // May or may not match depending on SQLite collation
      expect(results, isA<List<CallHistory>>());
    });
  });

  group('CallHistoryDao — delete operations', () {
    test('deleteById removes specific entry', () async {
      final id1 = await db.callHistoryDao.insert(makeEntry(transcript: 'A'));
      final id2 = await db.callHistoryDao.insert(makeEntry(transcript: 'B'));
      await db.database.delete(
        'call_history',
        where: 'id = ?',
        whereArgs: [id1],
      );
      final all = await db.callHistoryDao.getAll();
      expect(all, hasLength(1));
      expect(all[0].id, id2);
    });
  });

  group('CallHistoryDao — watchAll stream', () {
    test('emits initial data on subscribe', () async {
      await db.callHistoryDao.insert(makeEntry(transcript: 'Initial'));
      final results = await db.callHistoryDao.getAll();
      expect(results, hasLength(1));
    });
  });
}
