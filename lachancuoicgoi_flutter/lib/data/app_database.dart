import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'call_history.dart';
import 'call_history_dao.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase must be provided at app startup.');
});

class AppDatabase {
  AppDatabase._(this.database) : callHistoryDao = CallHistoryDao(database);

  static const int schemaVersion = 5;
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
    return databaseFactory;
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
  alert_history TEXT
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

    await _createIndexesIfNotExist(db);
  }

  static Future<void> _createIndexesIfNotExist(Database db) async {
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_call_history_dateTime ON call_history(dateTime)',
      );
    } catch (_) {}
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_call_history_riskLevel ON call_history(riskLevel)',
      );
    } catch (_) {}
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_call_history_dateTime_riskLevel ON call_history(dateTime, riskLevel)',
      );
    } catch (_) {}
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

  Stream<List<CallHistory>> watchAll() => callHistoryDao.watchAll();

  Future<CallHistory?> getById(int id) => callHistoryDao.getById(id);

  Future<void> deleteAll() => callHistoryDao.deleteAll();

  Future<void> deleteById(int id) => callHistoryDao.deleteById(id);

  Future<void> close() async {
    await callHistoryDao.dispose();
    await database.close();
  }
}
