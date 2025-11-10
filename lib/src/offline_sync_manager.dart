import 'dart:async';

import 'database/entity_codec.dart';
import 'database/offline_database.dart';
import 'network/network_manager.dart';
import 'sync/sync_engine.dart';
import 'models/sync_entity.dart';
import 'models/sync_status.dart';
import 'models/conflict_resolution.dart';
import 'utils/logger.dart';

/// The main manager class for offline synchronization functionality.
///
/// This class provides a high-level API for managing offline data storage
/// and synchronization across all supported platforms.
class OfflineSyncManager {
  static OfflineSyncManager? _instance;
  static final Logger _logger = Logger('OfflineSyncManager');

  late final OfflineDatabase _database;
  late final NetworkManager _networkManager;
  late final SyncEngine _syncEngine;

  bool _isInitialized = false;
  StreamController<SyncStatus>? _statusController;

  OfflineSyncManager._();

  /// Gets the singleton instance of the offline sync manager.
  static OfflineSyncManager get instance {
    _instance ??= OfflineSyncManager._();
    return _instance!;
  }

  /// Initializes the offline sync manager.
  ///
  /// This method must be called before using any other functionality.
  ///
  /// [baseUrl] - The base URL for API requests
  /// [defaultHeaders] - Default headers to include in all requests
  /// [timeout] - Request timeout duration
  /// [autoSyncEnabled] - Whether to enable automatic background sync
  /// [autoSyncInterval] - Interval for automatic sync operations
  /// [maxRetries] - Maximum number of retries for failed operations
  /// [batchSize] - Number of entities to process in each batch
  Future<void> initialize({
    String? baseUrl,
    Map<String, String>? defaultHeaders,
    Duration? timeout,
    bool autoSyncEnabled = true,
    Duration? autoSyncInterval,
    int maxRetries = 3,
    int batchSize = 50,
  }) async {
    if (_isInitialized) {
      _logger.warning('OfflineSyncManager already initialized');
      return;
    }

    try {
      _logger.info('Initializing OfflineSyncManager');

      // Initialize database
      _database = OfflineDatabase();
      await _database.initialize();

      // Initialize network manager
      _networkManager = NetworkManager();
      await _networkManager.initialize(
        baseUrl: baseUrl,
        defaultHeaders: defaultHeaders,
        timeout: timeout,
      );

      // Initialize sync engine
      _syncEngine = SyncEngine(_database, _networkManager);
      await _syncEngine.initialize();

      // Configure sync engine
      if (autoSyncInterval != null) {
        _syncEngine.setAutoSyncInterval(autoSyncInterval);
      }
      _syncEngine.setMaxRetries(maxRetries);
      _syncEngine.setBatchSize(batchSize);
      _syncEngine.setAutoSyncEnabled(autoSyncEnabled);

      // Initialize status controller
      _statusController = StreamController<SyncStatus>.broadcast();

      // Listen to sync engine status changes
      _syncEngine.statusStream.listen((status) {
        _statusController?.add(status);
      });

      _isInitialized = true;
      _logger.info('OfflineSyncManager initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize OfflineSyncManager', e, stackTrace);
      rethrow;
    }
  }

  /// Registers an entity type with the sync manager.
  void registerEntity<T extends SyncEntity>(
    String tableName,
    String endpoint,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    _syncEngine.registerEntity<T>(tableName, endpoint, fromJson);
    _logger.info('Registered entity: $tableName');
  }

  /// Registers a custom conflict resolver.
  ///
  /// [name] - Unique name for the resolver
  /// [resolver] - The conflict resolver implementation
  void registerConflictResolver(String name, ConflictResolver resolver) {
    _ensureInitialized();
    _syncEngine.registerConflictResolver(name, resolver);
    _logger.info('Registered conflict resolver: $name');
  }

  /// Saves an entity to the local database.
  ///
  /// [entity] - The entity to save
  /// Returns the saved entity with updated timestamps
  Future<T> save<T extends SyncEntity>(T entity) async {
    _ensureInitialized();

    try {
      final now = DateTime.now();
      final savedEntity = entity.copyWith(updatedAt: now, syncedAt: null);

      final storageMap = EntityCodec.serializeForStorage(
        savedEntity,
        syncStatus: 'pending',
      );

      await _database.insert(entity.tableName, storageMap);
      _logger.debug('Saved entity: ${entity.id}');

      return savedEntity as T;
    } catch (e, stackTrace) {
      _logger.error('Failed to save entity: ${entity.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Updates an entity in the local database.
  ///
  /// [entity] - The entity to update
  /// Returns the updated entity
  Future<T> update<T extends SyncEntity>(T entity) async {
    _ensureInitialized();

    try {
      final updatedEntity = entity.copyWith(
        updatedAt: DateTime.now(),
        syncedAt: null,
      );

      final storageMap = EntityCodec.serializeForStorage(
        updatedEntity,
        syncStatus: 'pending',
      );
      storageMap.remove('id');

      await _database.update(
        entity.tableName,
        storageMap,
        where: 'id = ?',
        whereArgs: [entity.id],
      );
      _logger.debug('Updated entity: ${entity.id}');

      return updatedEntity as T;
    } catch (e, stackTrace) {
      _logger.error('Failed to update entity: ${entity.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Deletes an entity from the local database.
  ///
  /// [id] - The ID of the entity to delete
  /// [tableName] - The table name for the entity
  /// [softDelete] - Whether to perform a soft delete (default: true)
  Future<void> delete(
    String id,
    String tableName, {
    bool softDelete = true,
  }) async {
    _ensureInitialized();

    try {
      if (softDelete) {
        await _database.softDelete(tableName, id);
        _logger.debug('Soft deleted entity: $id');
      } else {
        await _database.delete(tableName, where: 'id = ?', whereArgs: [id]);
        _logger.debug('Hard deleted entity: $id');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to delete entity: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Finds an entity by ID.
  ///
  /// [id] - The ID of the entity to find
  /// [tableName] - The table name for the entity
  /// Returns the entity if found, null otherwise
  Future<T?> findById<T extends SyncEntity>(String id, String tableName) async {
    _ensureInitialized();

    try {
      final result = await _database.findById(tableName, id);
      if (result == null) return null;

      final entity = EntityCodec.materialize(_database, tableName, result);
      if (entity is! T) {
        throw StateError(
          'Entity type mismatch. Expected $T but found ${entity.runtimeType}',
        );
      }
      return entity;
    } catch (e, stackTrace) {
      _logger.error('Failed to find entity: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Finds all entities of a given type.
  ///
  /// [tableName] - The table name for the entity
  /// [includeDeleted] - Whether to include soft-deleted entities
  /// [limit] - Maximum number of entities to return
  /// [offset] - Number of entities to skip
  /// [orderBy] - Field to order by
  /// [ascending] - Whether to sort in ascending order
  /// Returns a list of entities
  Future<List<T>> findAll<T extends SyncEntity>(
    String tableName, {
    bool includeDeleted = false,
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = true,
  }) async {
    _ensureInitialized();

    try {
      final results = await _database.findAll(tableName);

      Iterable<Map<String, dynamic>> filtered = includeDeleted
          ? results
          : results.where((row) => (row['is_deleted'] ?? 0) == 0);

      if (orderBy != null) {
        final sorted = filtered.toList()
          ..sort((a, b) {
            final aValue = a[orderBy];
            final bValue = b[orderBy];
            if (aValue is Comparable && bValue is Comparable) {
              return ascending
                  ? aValue.compareTo(bValue)
                  : bValue.compareTo(aValue);
            }
            return 0;
          });
        filtered = sorted;
      }

      if (offset != null && offset > 0) {
        filtered = filtered.skip(offset);
      }

      if (limit != null && limit > 0) {
        filtered = filtered.take(limit);
      }

      final entities = <T>[];
      for (final row in filtered) {
        final entity = EntityCodec.materialize(_database, tableName, row);
        if (entity is! T) {
          throw StateError(
            'Entity type mismatch. Expected $T but found ${entity.runtimeType}',
          );
        }
        entities.add(entity);
      }

      return entities;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to find all entities in table: $tableName',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Counts entities in a table.
  ///
  /// [tableName] - The table name for the entity
  /// [includeDeleted] - Whether to include soft-deleted entities
  /// Returns the count of entities
  Future<int> count(String tableName, {bool includeDeleted = false}) async {
    _ensureInitialized();

    try {
      return await _database.count(
        tableName,
        where: includeDeleted ? null : 'is_deleted = 0',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to count entities in table: $tableName',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Executes a raw SQL query.
  ///
  /// [sql] - The SQL query to execute
  /// [arguments] - Arguments for the query
  /// Returns the query results
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    _ensureInitialized();

    try {
      return await _database.rawQuery(sql, arguments);
    } catch (e, stackTrace) {
      _logger.error('Failed to execute raw query', e, stackTrace);
      rethrow;
    }
  }

  /// Executes a raw SQL command.
  ///
  /// [sql] - The SQL command to execute
  /// [arguments] - Arguments for the command
  /// Returns the number of affected rows
  Future<int> rawExecute(String sql, [List<dynamic>? arguments]) async {
    _ensureInitialized();

    try {
      return await _database.rawExecute(sql, arguments);
    } catch (e, stackTrace) {
      _logger.error('Failed to execute raw command', e, stackTrace);
      rethrow;
    }
  }

  /// Begins a database transaction.
  ///
  /// [action] - The action to perform within the transaction
  /// Returns the result of the action
  Future<T> transaction<T>(Future<T> Function(dynamic txn) action) async {
    _ensureInitialized();

    try {
      return await _database.transaction(action);
    } catch (e, stackTrace) {
      _logger.error('Failed to execute transaction', e, stackTrace);
      rethrow;
    }
  }

  /// Triggers a manual synchronization.
  ///
  /// This method will sync all registered entities with the server.
  Future<void> sync() async {
    _ensureInitialized();

    try {
      await _syncEngine.syncAll();
    } catch (e, stackTrace) {
      _logger.error('Failed to sync', e, stackTrace);
      rethrow;
    }
  }

  /// Enables or disables automatic synchronization.
  ///
  /// [enabled] - Whether to enable auto-sync
  void setAutoSyncEnabled(bool enabled) {
    _ensureInitialized();
    _syncEngine.setAutoSyncEnabled(enabled);
  }

  /// Sets the auto-sync interval.
  ///
  /// [interval] - The interval between auto-sync operations
  void setAutoSyncInterval(Duration interval) {
    _ensureInitialized();
    _syncEngine.setAutoSyncInterval(interval);
  }

  /// Sets the maximum number of retries for failed operations.
  ///
  /// [maxRetries] - The maximum number of retries
  void setMaxRetries(int maxRetries) {
    _ensureInitialized();
    _syncEngine.setMaxRetries(maxRetries);
  }

  /// Gets the current sync status.
  ///
  /// Returns the current sync status
  SyncStatus get status {
    _ensureInitialized();
    return _syncEngine.status;
  }

  /// Stream of sync status changes.
  ///
  /// Returns a stream that emits sync status updates
  Stream<SyncStatus> get statusStream {
    _ensureInitialized();
    return _statusController?.stream ?? Stream.value(_syncEngine.status);
  }

  /// Checks if the device is currently online.
  ///
  /// Returns true if online, false otherwise
  bool get isOnline {
    _ensureInitialized();
    return _networkManager.isOnline;
  }

  /// Stream of connectivity status changes.
  ///
  /// Returns a stream that emits connectivity status updates
  Stream<bool> get connectivityStream {
    _ensureInitialized();
    return _networkManager.connectivityStream;
  }

  /// Tests the network connection.
  ///
  /// [testUrl] - Optional URL to test connectivity
  /// Returns true if the connection test succeeds
  Future<bool> testConnection({String? testUrl}) async {
    _ensureInitialized();

    try {
      return await _networkManager.testConnection(testUrl: testUrl);
    } catch (e, stackTrace) {
      _logger.error('Failed to test connection', e, stackTrace);
      return false;
    }
  }

  /// Sets the base URL for API requests.
  ///
  /// [baseUrl] - The base URL to set
  void setBaseUrl(String baseUrl) {
    _ensureInitialized();
    _networkManager.setBaseUrl(baseUrl);
  }

  /// Sets default headers for all requests.
  ///
  /// [headers] - The headers to set
  void setDefaultHeaders(Map<String, String> headers) {
    _ensureInitialized();
    _networkManager.setDefaultHeaders(headers);
  }

  /// Sets the timeout for requests.
  ///
  /// [timeout] - The timeout duration
  void setTimeout(Duration timeout) {
    _ensureInitialized();
    _networkManager.setTimeout(timeout);
  }

  /// Gets the database instance for advanced usage.
  ///
  /// Returns the database instance
  OfflineDatabase get database {
    _ensureInitialized();
    return _database;
  }

  /// Gets the network manager instance for advanced usage.
  ///
  /// Returns the network manager instance
  NetworkManager get networkManager {
    _ensureInitialized();
    return _networkManager;
  }

  /// Gets the sync engine instance for advanced usage.
  ///
  /// Returns the sync engine instance
  SyncEngine get syncEngine {
    _ensureInitialized();
    return _syncEngine;
  }

  /// Ensures that the manager is initialized.
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'OfflineSyncManager not initialized. Call initialize() first.',
      );
    }
  }

  /// Disposes of the offline sync manager.
  ///
  /// This method should be called when the manager is no longer needed.
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      _logger.info('Disposing OfflineSyncManager');

      await _syncEngine.dispose();
      await _networkManager.dispose();
      await _database.close();
      await _statusController?.close();

      _isInitialized = false;
      _logger.info('OfflineSyncManager disposed');
    } catch (e, stackTrace) {
      _logger.error('Failed to dispose OfflineSyncManager', e, stackTrace);
    }
  }
}
