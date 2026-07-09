import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/data/call_history_dao.dart';
import 'package:lachancuocgoi_flutter/data/local_call_history_repository.dart';

/// A spy DAO that records method calls for verification.
class SpyCallHistoryDao implements CallHistoryDao {
  final List<String> calls = [];
  final List<CallHistory> insertedItems = [];
  int insertReturn = 1;
  List<CallHistory> getAllReturn = [];
  int countReturn = 0;

  @override
  Future<int> insert(CallHistory callHistory) async {
    calls.add('insert');
    insertedItems.add(callHistory);
    return insertReturn;
  }

  @override
  Future<List<CallHistory>> getAll() async {
    calls.add('getAll');
    return getAllReturn;
  }

  @override
  Future<List<CallHistory>> getAllPaginated({int limit = 20, int offset = 0}) async {
    calls.add('getAllPaginated($limit,$offset)');
    return [];
  }

  @override
  Future<int> count() async {
    calls.add('count');
    return countReturn;
  }

  @override
  Future<List<CallHistory>> search(String query, {int limit = 20, int offset = 0}) async {
    calls.add('search($query,$limit,$offset)');
    return [];
  }

  @override
  Future<int> searchCount(String query) async {
    calls.add('searchCount($query)');
    return 0;
  }

  @override
  Future<CallHistory?> getById(int id) async {
    calls.add('getById($id)');
    return null;
  }

  @override
  Future<void> deleteAll() async {
    calls.add('deleteAll');
  }

  @override
  Future<void> deleteById(int id) async {
    calls.add('deleteById($id)');
  }

  @override
  Future<void> updateRiskLevel(int id, String riskLevel) async {
    calls.add('updateRiskLevel($id,$riskLevel)');
  }

  @override
  Future<void> update(CallHistory callHistory) async {
    calls.add('update(${callHistory.id})');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
  }

  @override
  Stream<List<CallHistory>> watchAll() => const Stream.empty();

  @override
  Stream<void> get changes => const Stream.empty();
}

void main() {
  late SpyCallHistoryDao spy;
  late LocalCallHistoryRepository repo;

  setUp(() {
    spy = SpyCallHistoryDao();
    repo = LocalCallHistoryRepository(spy);
  });

  CallHistory makeHistory({int id = 0}) => CallHistory(
    id: id,
    dateTime: '2025-01-01',
    riskLevel: 'GREEN',
    summary: 'test',
    duration: '01:00',
    flagCount: 0,
    transcript: '',
  );

  group('LocalCallHistoryRepository delegation', () {
    test('insert delegates to _dao.insert()', () async {
      final result = await repo.insert(makeHistory());
      expect(spy.calls, ['insert']);
      expect(result, 1);
    });

    test('getAll delegates to _dao.getAll()', () async {
      spy.getAllReturn = [makeHistory(id: 1)];
      final result = await repo.getAll();
      expect(spy.calls, ['getAll']);
      expect(result.length, 1);
    });

    test('getAllPaginated passes correct limit and offset', () async {
      await repo.getAllPaginated(limit: 5, offset: 10);
      expect(spy.calls, ['getAllPaginated(5,10)']);
    });

    test('count delegates to _dao.count()', () async {
      spy.countReturn = 42;
      final result = await repo.count();
      expect(spy.calls, ['count']);
      expect(result, 42);
    });

    test('search passes correct query, limit, offset', () async {
      await repo.search('hello', limit: 15, offset: 5);
      expect(spy.calls, ['search(hello,15,5)']);
    });

    test('searchCount passes correct query', () async {
      await repo.searchCount('test');
      expect(spy.calls, ['searchCount(test)']);
    });

    test('getById passes correct id', () async {
      await repo.getById(42);
      expect(spy.calls, ['getById(42)']);
    });

    test('deleteAll delegates to _dao.deleteAll()', () async {
      await repo.deleteAll();
      expect(spy.calls, ['deleteAll']);
    });

    test('deleteById passes correct id', () async {
      await repo.deleteById(7);
      expect(spy.calls, ['deleteById(7)']);
    });

    test('updateRiskLevel passes correct id and level', () async {
      await repo.updateRiskLevel(3, 'RED');
      expect(spy.calls, ['updateRiskLevel(3,RED)']);
    });

    test('update passes correct CallHistory', () async {
      final h = makeHistory(id: 5);
      await repo.update(h);
      expect(spy.calls, ['update(5)']);
    });

    test('dispose delegates to _dao.dispose()', () async {
      await repo.dispose();
      expect(spy.calls, ['dispose']);
    });

    test('watchAll returns _dao.watchAll() stream', () {
      expect(repo.watchAll(), same(spy.watchAll()));
    });

    test('changes returns _dao.changes stream', () {
      expect(repo.changes, same(spy.changes));
    });
  });
}
