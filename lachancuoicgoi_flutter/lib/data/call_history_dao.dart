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

  Stream<void> get changes => _changeController.stream;

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

  Future<int> count() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM call_history',
    );
    if (result.isEmpty) return 0;
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<List<CallHistory>> search(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    if (query.isEmpty) {
      return getAllPaginated(limit: limit, offset: offset);
    }
    final escaped = _escapeLike(query);
    final like = '%$escaped%';
    final rows = await _db.query(
      'call_history',
      where:
          r"transcript LIKE ? ESCAPE '\' OR summary LIKE ? ESCAPE '\' OR riskLevel LIKE ? ESCAPE '\' "
          r"OR dateTime LIKE ? ESCAPE '\' OR analysisType LIKE ? ESCAPE '\'",
      whereArgs: [like, like, like, like, like],
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(CallHistory.fromMap).toList();
  }

  Future<int> searchCount(String query) async {
    if (query.isEmpty) return count();
    final escaped = _escapeLike(query);
    final like = '%$escaped%';
    final result = await _db.rawQuery(
      r'SELECT COUNT(*) as cnt FROM call_history WHERE '
      r"transcript LIKE ? ESCAPE '\' OR summary LIKE ? ESCAPE '\' OR riskLevel LIKE ? ESCAPE '\' "
      r"OR dateTime LIKE ? ESCAPE '\' OR analysisType LIKE ? ESCAPE '\'",
      [like, like, like, like, like],
    );
    if (result.isEmpty) return 0;
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

  Future<void> deleteAll() async {
    await _db.delete('call_history');
    _notifyChanged();
  }

  Future<void> deleteById(int id) async {
    await _db.delete('call_history', where: 'id = ?', whereArgs: [id]);
    _notifyChanged();
  }

  Future<int> deleteOlderThan(DateTime cutoff) async {
    final rows = await _db.query(
      'call_history',
      columns: const ['id', 'dateTime'],
    );
    final ids = <int>[];
    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      final stored = row['dateTime'] as String?;
      final recordedAt = stored == null
          ? null
          : CallHistory.parseStoredDateTime(stored);

      if (id != null && recordedAt != null && recordedAt.isBefore(cutoff)) {
        ids.add(id);
      }
    }
    if (ids.isEmpty) return 0;

    var deleted = 0;
    await _db.transaction((txn) async {
      for (var start = 0; start < ids.length; start += 500) {
        final end = start + 500 < ids.length ? start + 500 : ids.length;
        final chunk = ids.sublist(start, end);
        final placeholders = List.filled(chunk.length, '?').join(',');
        deleted += await txn.delete(
          'call_history',
          where: 'id IN ($placeholders)',
          whereArgs: chunk,
        );
      }
    });
    if (deleted > 0) _notifyChanged();
    return deleted;
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

  static String _escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  void _notifyChanged() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }
}
