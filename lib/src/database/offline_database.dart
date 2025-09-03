import 'dart:async';

import '../models/sync_entity.dart';
import '../utils/logger.dart';
import 'platform_database.dart';

/// Manages the local database for offline storage.
class OfflineDatabase {
  PlatformDatabase? _database;
  final Map<String, String> _tableDefinitions = {};
  final List<SyncEntity Function(Map<String, dynamic>)> _entityFactories = [];
  final Logger _logger = Logger('OfflineDatabase');

  /// Initializes the database and creates necessary tables.
  Future<void> initialize() async {
    try {
      // Use platform-agnostic in-memory database for all platforms
      _database = InMemoryDatabase();
      await _database!.initialize();
      await _onCreate();
      _logger.info('Database initialized with in-memory implementation');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize database', e, stackTrace);
      rethrow;
    }
  }

  /// Closes the database connection.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _logger.info('Database closed');
    }
  }

  /// Creates the database tables.
  Future<void> _onCreate() async {
    _logger.info('Creating database tables');

    // Create sync metadata table
    await _database!.createTable('sync_metadata', '''
      CREATE TABLE sync_metadata (
        id TEXT PRIMARY KEY,
        last_sync_at INTEGER,
        sync_status TEXT,
        pending_count INTEGER DEFAULT 0,
        failed_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create sync conflicts table
    await _database!.createTable('sync_conflicts', '''
      CREATE TABLE sync_conflicts (
        id TEXT PRIMARY KEY,
        entity_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        local_data TEXT NOT NULL,
        remote_data TEXT NOT NULL,
        conflict_type TEXT NOT NULL,
        detected_at INTEGER NOT NULL,
        is_resolved INTEGER DEFAULT 0,
        resolved_at INTEGER,
        resolution_strategy TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create registered entity tables
    for (final entry in _tableDefinitions.entries) {
      await _database!.createTable(entry.key, entry.value);
      _logger.info('Created table: ${entry.key}');
    }
  }

  /// Registers an entity type with the database.
  void registerEntity<T extends SyncEntity>(
    String tableName,
    String createTableSql,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    _tableDefinitions[tableName] = createTableSql;
    _entityFactories.add(fromJson);
    _logger.info('Registered entity: $tableName');
  }

  /// Creates a table for the given entity type.
  Future<void> createTable(String tableName, String sql) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    await _database!.createTable(tableName, sql);
    _logger.info('Created table: $tableName');
  }

  /// Inserts an entity into the database.
  Future<int> insert(String table, Map<String, dynamic> values) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    values['created_at'] = now;
    values['updated_at'] = now;

    final id = await _database!.insert(table, values);
    _logger.debug('Inserted into $table with id: $id');
    return id;
  }

  /// Updates an entity in the database.
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    values['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    final rowsAffected = await _database!.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
    );
    _logger.debug('Updated $rowsAffected rows in $table');
    return rowsAffected;
  }

  /// Deletes an entity from the database.
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    final rowsAffected = await _database!.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
    _logger.debug('Deleted $rowsAffected rows from $table');
    return rowsAffected;
  }

  /// Soft deletes an entity by setting deleted_at timestamp.
  Future<int> softDelete(String table, String id) async {
    return await update(
      table,
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Finds an entity by ID.
  Future<Map<String, dynamic>?> findById(String table, String id) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    final results = await _database!.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );

    return results.isNotEmpty ? results.first : null;
  }

  /// Finds all entities in a table.
  Future<List<Map<String, dynamic>>> findAll(String table) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    return await _database!.query(table);
  }

  /// Finds unsynced entities.
  Future<List<Map<String, dynamic>>> findUnsynced(String table) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    return await _database!.query(
      table,
      where: 'sync_status != ? OR sync_status IS NULL',
      whereArgs: ['synced'],
    );
  }

  /// Counts entities in a table.
  Future<int> count(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    final results = await _database!.query(
      table,
      columns: ['COUNT(*) as count'],
      where: where,
      whereArgs: whereArgs,
    );

    return results.isNotEmpty ? (results.first['count'] as int? ?? 0) : 0;
  }

  /// Executes a raw SQL query.
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    return await _database!.rawQuery(sql, arguments);
  }

  /// Executes a raw SQL statement.
  Future<int> rawExecute(String sql, [List<dynamic>? arguments]) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    return await _database!.rawExecute(sql, arguments);
  }

  /// Executes a database transaction.
  Future<T> transaction<T>(Future<T> Function(dynamic txn) action) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    return await _database!.transaction(action);
  }

  /// Checks if the database is initialized.
  bool get isInitialized => _database != null;

  /// Gets the database instance.
  PlatformDatabase? get database => _database;
}
