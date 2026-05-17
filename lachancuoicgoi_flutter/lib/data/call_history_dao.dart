import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'call_history.dart';

class CallHistoryDao {
  CallHistoryDao(this._db);

  final Database _db;
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  Stream<List<CallHistory>> watchAll() async* {
    yield await getAll();
    yield* _changeController.stream.asyncMap((_) => getAll());
  }

  Future<int> insert(CallHistory callHistory) async {
    final id = await _db.insert(
      'call_history',
      callHistory.toMap(includeId: false),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyChanged();
    return id;
  }

  Future<List<CallHistory>> getAll() async {
    final rows = await _db.query('call_history', orderBy: 'id DESC');
    return rows.map(CallHistory.fromMap).toList();
  }

  /// Returns [limit] items starting at [offset], ordered by id DESC.
  Future<List<CallHistory>> getAllPaginated({
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _db.query(
      'call_history',
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(CallHistory.fromMap).toList();
  }

  /// Returns total number of records.
  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as cnt FROM call_history');
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<CallHistory?> getById(int id) async {
    final rows = await _db.query(
      'call_history',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CallHistory.fromMap(rows.first);
  }

  Future<CallHistory?> getByIdSync(int id) => getById(id);

  Future<void> deleteAll() async {
    await _db.delete('call_history');
    _notifyChanged();
  }

  Future<void> deleteById(int id) async {
    await _db.delete(
      'call_history',
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged();
  }

  Future<void> updateRiskLevel(int id, String riskLevel) async {
    await _db.update(
      'call_history',
      {'riskLevel': riskLevel},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged();
  }

  Future<void> update(CallHistory callHistory) async {
    await _db.update(
      'call_history',
      callHistory.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [callHistory.id],
    );
    _notifyChanged();
  }

  Future<void> dispose() async {
    await _changeController.close();
  }

  void _notifyChanged() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }
}
