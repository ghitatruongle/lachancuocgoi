import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';

void main() {
  late InMemoryAppDatabase db;

  setUp(() {
    db = InMemoryAppDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  CallHistory makeHistory({
    int id = 0,
    String summary = 'test',
    String riskLevel = 'GREEN',
    String transcript = '',
  }) {
    return CallHistory(
      id: id,
      dateTime: '2025-01-01 12:00',
      riskLevel: riskLevel,
      summary: summary,
      duration: '01:00',
      flagCount: 0,
      transcript: transcript,
    );
  }

  group('InMemoryAppDatabase', () {
    test(
      'insert returns monotonically increasing IDs starting from 1',
      () async {
        final id1 = await db.insert(makeHistory(summary: 'first'));
        final id2 = await db.insert(makeHistory(summary: 'second'));
        final id3 = await db.insert(makeHistory(summary: 'third'));
        expect(id1, 1);
        expect(id2, 2);
        expect(id3, 3);
      },
    );

    test('insert places newest first', () async {
      await db.insert(makeHistory(summary: 'old'));
      await db.insert(makeHistory(summary: 'new'));
      final all = await db.getAll();
      expect(all.first.summary, 'new');
      expect(all.last.summary, 'old');
    });

    test('getAll returns all entries', () async {
      await db.insert(makeHistory(summary: 'a'));
      await db.insert(makeHistory(summary: 'b'));
      await db.insert(makeHistory(summary: 'c'));
      final all = await db.getAll();
      expect(all.length, 3);
    });

    test('getAllPaginated respects limit', () async {
      for (var i = 0; i < 10; i++) {
        await db.insert(makeHistory(summary: 'item $i'));
      }
      final page = await db.getAllPaginated(limit: 3, offset: 0);
      expect(page.length, 3);
    });

    test('getAllPaginated respects offset', () async {
      for (var i = 0; i < 10; i++) {
        await db.insert(makeHistory(summary: 'item $i'));
      }
      final page = await db.getAllPaginated(limit: 3, offset: 7);
      expect(page.length, 3);
    });

    test('getAllPaginated returns empty when offset beyond length', () async {
      await db.insert(makeHistory(summary: 'a'));
      final page = await db.getAllPaginated(limit: 10, offset: 100);
      expect(page, isEmpty);
    });

    test('count returns correct count', () async {
      expect(await db.count(), 0);
      await db.insert(makeHistory(summary: 'a'));
      expect(await db.count(), 1);
      await db.insert(makeHistory(summary: 'b'));
      expect(await db.count(), 2);
    });

    test('search is case-insensitive on summary', () async {
      await db.insert(makeHistory(summary: 'Hello World'));
      await db.insert(makeHistory(summary: 'Goodbye'));
      final results = await db.search('hello');
      expect(results.length, 1);
      expect(results.first.summary, 'Hello World');
    });

    test('search matches transcript', () async {
      await db.insert(makeHistory(summary: 'a', transcript: 'OTP code 123'));
      await db.insert(makeHistory(summary: 'b', transcript: 'nothing'));
      final results = await db.search('OTP');
      expect(results.length, 1);
    });

    test('search with empty query returns all', () async {
      await db.insert(makeHistory(summary: 'a'));
      await db.insert(makeHistory(summary: 'b'));
      final results = await db.search('');
      expect(results.length, 2);
    });

    test('search with no matches returns empty', () async {
      await db.insert(makeHistory(summary: 'abc'));
      final results = await db.search('xyz');
      expect(results, isEmpty);
    });

    test('search pagination works', () async {
      for (var i = 0; i < 5; i++) {
        await db.insert(makeHistory(summary: 'match $i'));
      }
      final page = await db.search('match', limit: 2, offset: 2);
      expect(page.length, 2);
    });

    test('searchCount matches search result count', () async {
      await db.insert(makeHistory(summary: 'hello'));
      await db.insert(makeHistory(summary: 'world'));
      await db.insert(makeHistory(summary: 'hello world'));
      expect(await db.searchCount('hello'), 2);
    });

    test('getById returns correct entry', () async {
      final id = await db.insert(makeHistory(summary: 'target'));
      await db.insert(makeHistory(summary: 'other'));
      final result = await db.getById(id);
      expect(result, isNotNull);
      expect(result!.summary, 'target');
    });

    test('getById returns null for non-existent ID', () async {
      final result = await db.getById(999);
      expect(result, isNull);
    });

    test('deleteAll clears all entries', () async {
      await db.insert(makeHistory(summary: 'a'));
      await db.insert(makeHistory(summary: 'b'));
      await db.deleteAll();
      expect(await db.count(), 0);
    });

    test('deleteById removes specific entry', () async {
      await db.insert(makeHistory(summary: 'keep'));
      final id2 = await db.insert(makeHistory(summary: 'remove'));
      await db.deleteById(id2);
      final all = await db.getAll();
      expect(all.length, 1);
      expect(all.first.summary, 'keep');
    });

    test('updateRiskLevel updates the correct entry', () async {
      final id = await db.insert(makeHistory(summary: 'a', riskLevel: 'GREEN'));
      await db.updateRiskLevel(id, 'RED');
      final updated = await db.getById(id);
      expect(updated!.riskLevel, 'RED');
    });

    test('update replaces the entry with matching ID', () async {
      final id = await db.insert(makeHistory(summary: 'old'));
      final updated = makeHistory(id: id, summary: 'new');
      await db.update(updated);
      final result = await db.getById(id);
      expect(result!.summary, 'new');
    });

    test('watchAll stream emits on insert', () async {
      // The initial empty event was emitted in the constructor (setUp),
      // so we start a fresh listener here to catch subsequent events.
      final emissions = <List<CallHistory>>[];
      final sub = db.watchAll().listen(emissions.add);

      await db.insert(makeHistory(summary: 'a'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(emissions, isNotEmpty);
      expect(emissions.last.length, 1);
      expect(emissions.last.first.summary, 'a');
      await sub.cancel();
    });

    test('database/callHistoryDao getters throw UnimplementedError', () {
      expect(() => db.database, throwsUnimplementedError);
      expect(() => db.callHistoryDao, throwsUnimplementedError);
    });
  });
}
