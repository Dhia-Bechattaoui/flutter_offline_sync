import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../utils/logger.dart';
import 'platform_database.dart';

/// SQLite-backed implementation of [PlatformDatabase] that supports
/// all Flutter platforms, including web (via a WASM-backed virtual FS).
class SqlitePlatformDatabase implements PlatformDatabase {
  final Logger _logger;
  final String _databaseName;

  Database? _database;
  DatabaseFactory? _databaseFactory;
  bool _initialized = false;

  SqlitePlatformDatabase({
    String databaseName = 'offline_sync.db',
    Logger? logger,
  }) : _databaseName = databaseName,
       _logger = logger ?? const Logger('SqlitePlatformDatabase');

  @override
  Future<void> initialize() async {
    if (_initialized) {
      _logger.debug('Database already initialized');
      return;
    }

    _databaseFactory = await _resolveDatabaseFactory();
    final path = await _resolveDatabasePath(_databaseFactory!);

    _logger.info('Opening SQLite database at $path');
    _database = await _databaseFactory!.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );

    _initialized = true;
    _logger.info('SQLite database initialized');
  }

  @override
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _initialized = false;
      _logger.info('SQLite database closed');
    }
  }

  @override
  Future<void> createTable(String tableName, String sql) async {
    final db = _ensureDatabase();
    _logger.debug('Creating table $tableName');
    try {
      await db.execute(sql);
    } on DatabaseException catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('already exists')) {
        _logger.debug('Table $tableName already exists; skipping creation');
        return;
      }
      rethrow;
    }
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> values) async {
    final db = _ensureDatabase();
    final id = await db.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _logger.debug('Inserted row into $table with id $id');
    return id;
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = _ensureDatabase();
    final rows = await db.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _logger.debug('Updated $rows rows in $table');
    return rows;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = _ensureDatabase();
    final rows = await db.delete(table, where: where, whereArgs: whereArgs);
    _logger.debug('Deleted $rows rows from $table');
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = _ensureDatabase();
    return await db.query(
      table,
      distinct: distinct ?? false,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = _ensureDatabase();
    return await db.rawQuery(sql, arguments);
  }

  @override
  Future<int> rawExecute(String sql, [List<dynamic>? arguments]) async {
    final db = _ensureDatabase();
    return await db.rawUpdate(sql, arguments);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(dynamic txn) action, {
    bool? exclusive,
  }) async {
    final db = _ensureDatabase();
    return db.transaction<T>(
      (txn) => action(txn),
      exclusive: exclusive ?? false,
    );
  }

  Database _ensureDatabase() {
    final db = _database;
    if (db == null) {
      throw StateError(
        'Database not initialized. Call initialize() before using it.',
      );
    }
    return db;
  }

  Future<DatabaseFactory> _resolveDatabaseFactory() async {
    if (kIsWeb) {
      _logger.info('Using WebAssembly-backed SQLite database factory');
      return databaseFactoryFfiWeb;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        _logger.info('Initializing FFI database factory for desktop platform');
        sqfliteFfiInit();
        return databaseFactoryFfi;
      default:
        _logger.info('Using native sqflite database factory');
        return databaseFactory;
    }
  }

  Future<String> _resolveDatabasePath(DatabaseFactory factory) async {
    if (kIsWeb) {
      // On the web, the name identifies the IndexedDB-backed virtual file.
      return _databaseName;
    }

    final databasesPath = await factory.getDatabasesPath();
    return p.join(databasesPath, _databaseName);
  }
}
