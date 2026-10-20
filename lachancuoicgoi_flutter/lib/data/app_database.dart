import 'dart:async';
import 'dart:math' show max, min;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'call_history.dart';
import 'call_history_dao.dart';
import 'call_history_repository.dart';
import 'local_call_history_repository.dart';

final appDatabaseFutureProvider = FutureProvider<AppDatabase>((ref) async {
  if (kIsWeb) {
    return InMemoryAppDatabase();
  }
  final db = await AppDatabase.open();
  ref.onDispose(() => db.close());
  return db;
});

class AppDatabase {
  AppDatabase._(this.database, this.callHistoryDao)
    : callHistoryRepository = LocalCallHistoryRepository(callHistoryDao);

  static const int schemaVersion = 6;
  static const String databaseName = 'call_shield_database.db';

  final Database database;
  final CallHistoryDao callHistoryDao;
  final CallHistoryRepository callHistoryRepository;

  static Future<AppDatabase> open({
    DatabaseFactory? databaseFactory,
    String? databasePath,
    bool inMemory = false,
  }) async {
    final factory =
        databaseFactory ?? databaseFactoryOrNull ?? databaseFactoryFfiSafe();
    final resolvedPath = inMemory
        ? inMemoryDatabasePath
        : databasePath ?? path.join(await getDatabasesPath(), databaseName);

    final db = await factory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) async {
          await db.transaction((txn) => _createSchema(txn));
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await db.transaction(
            (txn) => _upgradeSchema(txn, oldVersion, newVersion),
          );
        },
      ),
    );

    return AppDatabase._(db, CallHistoryDao(db));
  }

  static DatabaseFactory? get databaseFactoryOrNull {
    try {
      return databaseFactory;
    } on Object catch (_) {
      return null;
    }
  }

  static DatabaseFactory databaseFactoryFfiSafe() {
    try {
      return databaseFactory;
    } on Object catch (_) {
      throw StateError(
        'databaseFactory is null. On desktop, call sqfliteFfiInit() before '
        'opening the database.',
      );
    }
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS call_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dateTime TEXT NOT NULL,
  riskLevel TEXT NOT NULL,
  summary TEXT NOT NULL,
  duration TEXT NOT NULL,
  flagCount INTEGER NOT NULL,
  transcript TEXT NOT NULL,
  audioPath TEXT,
  analysisResult TEXT,
  analysisType TEXT,
  alert_history TEXT,
  recordingError TEXT
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_call_history_dateTime ON call_history(dateTime)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_call_history_riskLevel ON call_history(riskLevel)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_call_history_dateTime_riskLevel ON call_history(dateTime, riskLevel)',
    );
  }

  static Future<void> _upgradeSchema(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion == 0) {
      await _createSchema(db);
      return;
    }

    if (oldVersion < 5) {
      await _addColumnIfMissing(db, 'call_history', 'audioPath', 'TEXT');
      await _addColumnIfMissing(db, 'call_history', 'analysisResult', 'TEXT');
      await _addColumnIfMissing(db, 'call_history', 'analysisType', 'TEXT');
      await _addColumnIfMissing(db, 'call_history', 'alert_history', 'TEXT');
      await _addColumnIfMissing(db, 'call_history', 'recordingError', 'TEXT');
    }

    if (oldVersion < 6) {
      await _addColumnIfMissing(db, 'call_history', 'recordingError', 'TEXT');
    }

    await _createIndexesIfNotExist(db);
  }

  static Future<void> _createIndexesIfNotExist(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_call_history_dateTime ON call_history(dateTime)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_call_history_riskLevel ON call_history(riskLevel)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_call_history_dateTime_riskLevel ON call_history(dateTime, riskLevel)',
    );
  }

  static const _allowedTables = <String>['call_history'];
  static const _allowedColumns = <String>[
    'id',
    'dateTime',
    'riskLevel',
    'summary',
    'duration',
    'flagCount',
    'transcript',
    'audioPath',
    'analysisResult',
    'analysisType',
    'alert_history',
    'recordingError',
  ];
  static const _allowedTypes = <String>['TEXT', 'INTEGER', 'REAL', 'BLOB'];

  static Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String type,
  ) async {
    if (!_allowedTables.contains(table) ||
        !_allowedColumns.contains(column) ||
        !_allowedTypes.contains(type)) {
      throw ArgumentError('Invalid table, column, or type parameter');
    }

    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<int> insert(CallHistory callHistory) =>
      callHistoryRepository.insert(callHistory);

  Future<List<CallHistory>> getAll() => callHistoryRepository.getAll();

  Future<List<CallHistory>> getAllPaginated({int limit = 20, int offset = 0}) =>
      callHistoryRepository.getAllPaginated(limit: limit, offset: offset);

  Future<int> count() => callHistoryRepository.count();

  Future<List<CallHistory>> search(
    String query, {
    int limit = 20,
    int offset = 0,
  }) => callHistoryRepository.search(query, limit: limit, offset: offset);

  Future<int> searchCount(String query) =>
      callHistoryRepository.searchCount(query);

  Stream<List<CallHistory>> watchAll() => callHistoryRepository.watchAll();

  Stream<void> get changes => callHistoryRepository.changes;

  Future<CallHistory?> getById(int id) => callHistoryRepository.getById(id);

  Future<void> deleteAll() => callHistoryRepository.deleteAll();

  Future<void> deleteById(int id) => callHistoryRepository.deleteById(id);

  Future<int> deleteOlderThan(DateTime cutoff) =>
      callHistoryRepository.deleteOlderThan(cutoff);

  Future<int> pruneOldHistoryAndVacuum({int retentionDays = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    final count = await deleteOlderThan(cutoff);
    if (count > 0 && database.isOpen) {
      try {
        await database.execute('VACUUM');
      } on Object catch (_) {}
    }
    return count;
  }

  Future<void> close() async {
    await callHistoryRepository.dispose();
    await database.close();
  }

  @visibleForTesting
  AppDatabase.withDatabase(Database db) : this._(db, CallHistoryDao(db));
}

class InMemoryAppDatabase implements AppDatabase, CallHistoryRepository {
  final List<CallHistory> _history = [];
  final _streamController = StreamController<List<CallHistory>>.broadcast();

  InMemoryAppDatabase() {
    _streamController.add([]);
  }

  @override
  Database get database => throw UnimplementedError();

  @override
  CallHistoryDao get callHistoryDao => throw UnimplementedError();

  @override
  CallHistoryRepository get callHistoryRepository => this;

  @override
  Future<int> insert(CallHistory callHistory) async {
    final newId = _history.isEmpty
        ? 1
        : (_history.map((e) => e.id).reduce(max) + 1);
    final historyWithId = callHistory.copyWith(id: newId);
    _history.insert(0, historyWithId);
    _streamController.add(List.unmodifiable(_history));
    return newId;
  }

  @override
  Future<List<CallHistory>> getAll() async {
    return List.from(_history);
  }

  @override
  Future<List<CallHistory>> getAllPaginated({
    int limit = 20,
    int offset = 0,
  }) async {
    if (offset >= _history.length) return [];
    return _history.sublist(offset, min(offset + limit, _history.length));
  }

  @override
  Future<int> count() async => _history.length;

  @override
  Future<List<CallHistory>> search(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final queryLower = query.toLowerCase();
    final filtered = _history.where((e) {
      return e.summary.toLowerCase().contains(queryLower) ||
          e.transcript.toLowerCase().contains(queryLower);
    }).toList();
    if (offset >= filtered.length) return [];
    return filtered.sublist(offset, min(offset + limit, filtered.length));
  }

  @override
  Future<int> searchCount(String query) async {
    final queryLower = query.toLowerCase();
    return _history.where((e) {
      return e.summary.toLowerCase().contains(queryLower) ||
          e.transcript.toLowerCase().contains(queryLower);
    }).length;
  }

  @override
  Stream<List<CallHistory>> watchAll() => _streamController.stream;

  @override
  Stream<void> get changes => _streamController.stream.map((_) {});

  @override
  Future<CallHistory?> getById(int id) async {
    return _history.firstWhereOrNull((e) => e.id == id);
  }

  @override
  Future<void> deleteAll() async {
    _history.clear();
    _streamController.add([]);
  }

  @override
  Future<void> deleteById(int id) async {
    _history.removeWhere((e) => e.id == id);
    _streamController.add(List.unmodifiable(_history));
  }

  @override
  Future<int> deleteOlderThan(DateTime cutoff) async {
    final before = _history.length;
    _history.removeWhere((entry) {
      final recordedAt = entry.recordedAt;
      return recordedAt != null && recordedAt.isBefore(cutoff);
    });
    final deleted = before - _history.length;
    if (deleted > 0) {
      _streamController.add(List.unmodifiable(_history));
    }
    return deleted;
  }

  @override
  Future<int> pruneOldHistoryAndVacuum({int retentionDays = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    return deleteOlderThan(cutoff);
  }

  @override
  Future<void> updateRiskLevel(int id, String riskLevel) async {
    final idx = _history.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _history[idx] = _history[idx].copyWith(riskLevel: riskLevel);
      _streamController.add(List.unmodifiable(_history));
    }
  }

  @override
  Future<void> update(CallHistory callHistory) async {
    final idx = _history.indexWhere((e) => e.id == callHistory.id);
    if (idx != -1) {
      _history[idx] = callHistory;
      _streamController.add(List.unmodifiable(_history));
    }
  }

  @override
  Future<void> dispose() async {
    await close();
  }

  @override
  Future<void> close() async {
    await _streamController.close();
  }
}
