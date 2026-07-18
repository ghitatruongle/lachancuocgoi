import 'dart:async';
import 'call_history.dart';
import 'call_history_dao.dart';
import 'call_history_repository.dart';

class LocalCallHistoryRepository implements CallHistoryRepository {
  LocalCallHistoryRepository(this._dao);

  final CallHistoryDao _dao;

  @override
  Stream<List<CallHistory>> watchAll() => _dao.watchAll();

  @override
  Stream<void> get changes => _dao.changes;

  @override
  Future<int> insert(CallHistory callHistory) => _dao.insert(callHistory);

  @override
  Future<List<CallHistory>> getAll() => _dao.getAll();

  @override
  Future<List<CallHistory>> getAllPaginated({int limit = 20, int offset = 0}) =>
      _dao.getAllPaginated(limit: limit, offset: offset);

  @override
  Future<int> count() => _dao.count();

  @override
  Future<List<CallHistory>> search(
    String query, {
    int limit = 20,
    int offset = 0,
  }) => _dao.search(query, limit: limit, offset: offset);

  @override
  Future<int> searchCount(String query) => _dao.searchCount(query);

  @override
  Future<CallHistory?> getById(int id) => _dao.getById(id);

  @override
  Future<void> deleteAll() => _dao.deleteAll();

  @override
  Future<void> deleteById(int id) => _dao.deleteById(id);

  @override
  Future<int> deleteOlderThan(DateTime cutoff) => _dao.deleteOlderThan(cutoff);

  @override
  Future<void> updateRiskLevel(int id, String riskLevel) =>
      _dao.updateRiskLevel(id, riskLevel);

  @override
  Future<void> update(CallHistory callHistory) => _dao.update(callHistory);

  @override
  Future<void> dispose() => _dao.dispose();
}
