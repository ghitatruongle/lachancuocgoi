import 'dart:async';
import 'dart:math' show max, min;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'call_history.dart';
import 'call_history_dao.dart';

/// Lazy database provider — opens the database on first read, not at app startup.
/// This avoids blocking runApp() with the SQLite open + schema creation.
final appDatabaseFutureProvider = FutureProvider<AppDatabase>((ref) async {
  if (kIsWeb) {
    return InMemoryAppDatabase();
  }
  final db = await AppDatabase.open();
  ref.onDispose(() => db.close());
  return db;
});

class AppDatabase {
  AppDatabase._(this.database) : callHistoryDao = CallHistoryDao(database);

  static const int schemaVersion = 6;
  static const String databaseName = 'call_shield_database.db';

  final Database database;
  final CallHistoryDao callHistoryDao;

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
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _upgradeSchema(db, oldVersion, newVersion);
        },
      ),
    );

    return AppDatabase._(db);
  }

  static DatabaseFactory? get databaseFactoryOrNull {
    try {
      return databaseFactory;
    } catch (_) {
      return null;
    }
  }

  static DatabaseFactory databaseFactoryFfiSafe() {
    try {
      return databaseFactory;
    } catch (_) {
      // Global databaseFactory not set — on mobile the plugin always sets
      // it, so this only happens on desktop/FFI. Re-throw with context.
      throw StateError(
        'databaseFactory is null. On desktop, call sqfliteFfiInit() before '
        'opening the database.',
      );
    }
  }

  static Future<void> _createSchema(Database db) async {
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
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion == 0) {
      await _createSchema(db);
      return;
    }

    if (oldVersion < 5) {
      await _addColumnIfMissing(db, 'call_history', 'alert_history', 'TEXT');
    }

    if (oldVersion < 6) {
      await _addColumnIfMissing(db, 'call_history', 'recordingError', 'TEXT');
    }

    await _createIndexesIfNotExist(db);
  }

  static Future<void> _createIndexesIfNotExist(Database db) async {
    // IF NOT EXISTS makes these idempotent — failures here signal real
    // I/O problems (disk full, permission) and must surface to the caller.
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
    Database db,
    String table,
    String column,
    String type,
  ) async {
    // Whitelist validation to prevent SQL injection
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
      callHistoryDao.insert(callHistory);

  Future<List<CallHistory>> getAll() => callHistoryDao.getAll();

  Future<List<CallHistory>> getAllPaginated({
    int limit = 20,
    int offset = 0,
  }) =>
      callHistoryDao.getAllPaginated(limit: limit, offset: offset);

  Future<int> count() => callHistoryDao.count();

  Future<List<CallHistory>> search(String query, {int limit = 20, int offset = 0}) =>
      callHistoryDao.search(query, limit: limit, offset: offset);

  Future<int> searchCount(String query) => callHistoryDao.searchCount(query);

  Stream<List<CallHistory>> watchAll() => callHistoryDao.watchAll();

  /// Emits whenever call_history changes (insert/delete/update).
  Stream<void> get changes => callHistoryDao.changes;

  Future<CallHistory?> getById(int id) => callHistoryDao.getById(id);

  Future<void> deleteAll() => callHistoryDao.deleteAll();

  Future<void> deleteById(int id) => callHistoryDao.deleteById(id);

  Future<void> close() async {
    await callHistoryDao.dispose();
    await database.close();
  }

  /// Creates an [AppDatabase] wrapping an existing [Database] instance.
  /// Used in tests to inject a fake/mock database without sqflite FFI.
  @visibleForTesting
  AppDatabase.withDatabase(Database db)
      : database = db,
        callHistoryDao = CallHistoryDao(db);
}

class InMemoryAppDatabase implements AppDatabase {
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
  Future<int> insert(CallHistory callHistory) async {
    final newId = _history.isEmpty ? 1 : (_history.map((e) => e.id).reduce(max) + 1);
    final historyWithId = callHistory.copyWith(id: newId);
    _history.insert(0, historyWithId); // Newest first
    _streamController.add(List.unmodifiable(_history));
    return newId;
  }

  @override
  Future<List<CallHistory>> getAll() async {
    return List.from(_history);
  }

  @override
  Future<List<CallHistory>> getAllPaginated({int limit = 20, int offset = 0}) async {
    if (offset >= _history.length) return [];
    return _history.sublist(offset, min(offset + limit, _history.length));
  }

  @override
  Future<int> count() async => _history.length;

  @override
  Future<List<CallHistory>> search(String query, {int limit = 20, int offset = 0}) async {
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
  Future<void> close() async {
    await _streamController.close();
  }
}
