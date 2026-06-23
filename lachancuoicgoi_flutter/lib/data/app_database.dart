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
          // Schema creation is multi-statement (table + 3 indexes); wrap it in
          // a transaction so a mid-way failure rolls the whole schema back
          // instead of leaving a half-built table (Sprint 4.4).
          await db.transaction((txn) => _createSchema(txn));
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Migration runs several ALTER TABLE + index creations that must be
          // atomic — a crash mid-migration must not leave the DB between
          // versions (Sprint 4.4).
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
      // Global databaseFactory not set — on mobile the plugin always sets
      // it, so this only happens on desktop/FFI. Re-throw with context.
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

    // Bring the table up to the full current column set regardless of which
    // pre-5 version we're upgrading from. The original Android→Flutter
    // migration only added columns in branches for versions >=5/6, which left
    // installs on schema v1–v4 (e.g. early internal builds) missing core
    // columns like audioPath/analysisResult/analysisType — inserts would then
    // throw "no such column". _addColumnIfMissing is idempotent, so listing
    // every column here is safe even if the column already exists.
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
    DatabaseExecutor db,
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
      callHistoryRepository.insert(callHistory);

  Future<List<CallHistory>> getAll() => callHistoryRepository.getAll();

  Future<List<CallHistory>> getAllPaginated({
    int limit = 20,
    int offset = 0,
  }) =>
      callHistoryRepository.getAllPaginated(limit: limit, offset: offset);

  Future<int> count() => callHistoryRepository.count();

  Future<List<CallHistory>> search(String query, {int limit = 20, int offset = 0}) =>
      callHistoryRepository.search(query, limit: limit, offset: offset);

  Future<int> searchCount(String query) => callHistoryRepository.searchCount(query);

  Stream<List<CallHistory>> watchAll() => callHistoryRepository.watchAll();

  /// Emits whenever call_history changes (insert/delete/update).
  Stream<void> get changes => callHistoryRepository.changes;

  Future<CallHistory?> getById(int id) => callHistoryRepository.getById(id);

  Future<void> deleteAll() => callHistoryRepository.deleteAll();

  Future<void> deleteById(int id) => callHistoryRepository.deleteById(id);

  Future<void> close() async {
    await callHistoryRepository.dispose();
    await database.close();
  }

  /// Creates an [AppDatabase] wrapping an existing [Database] instance.
  /// Used in tests to inject a fake/mock database without sqflite FFI.
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
