import 'dart:async';

import '../models/sync_entity.dart';
import '../models/sync_status.dart';
import '../models/conflict_resolution.dart';
import '../database/offline_database.dart';
import '../network/network_manager.dart';
import '../utils/logger.dart';

/// The core sync engine that handles synchronization between local and remote data.
class SyncEngine {
  final OfflineDatabase _database;
  final NetworkManager _networkManager;
  final Logger _logger = Logger('SyncEngine');

  final Map<String, String> _endpointMappings = {};
  final Map<String, ConflictResolver> _conflictResolvers = {};
  final List<SyncEntity Function(Map<String, dynamic>)> _entityFactories = [];

  StreamController<SyncStatus>? _statusController;
  SyncStatus _currentStatus = const SyncStatus(
    isOnline: false,
    isSyncing: false,
  );

  Timer? _autoSyncTimer;
  Duration _autoSyncInterval = const Duration(minutes: 5);
  int _maxRetries = 3;

  SyncEngine(this._database, this._networkManager) {
    _statusController = StreamController<SyncStatus>.broadcast();
    _initializeDefaultResolvers();
  }

  /// Initializes the sync engine.
  Future<void> initialize() async {
    _logger.info('Initializing sync engine');

    // Listen to network connectivity changes
    _networkManager.connectivityStream.listen(_onConnectivityChanged);

    // Update initial status
    await _updateStatus(isOnline: _networkManager.isOnline);

    _logger.info('Sync engine initialized');
  }

  /// Initializes default conflict resolvers.
  void _initializeDefaultResolvers() {
    _conflictResolvers['default'] = const DefaultConflictResolver();
  }

  /// Registers an entity type for synchronization.
  void registerEntity<T extends SyncEntity>(
    String tableName,
    String endpoint,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    _endpointMappings[tableName] = endpoint;
    _entityFactories.add(fromJson);
    _database.registerEntity(
      tableName,
      'CREATE TABLE $tableName (id TEXT PRIMARY KEY, data TEXT, created_at INTEGER, updated_at INTEGER, sync_status TEXT)',
      fromJson,
    );
    _logger.info('Registered entity: $tableName -> $endpoint');
  }

  /// Registers a custom conflict resolver.
  void registerConflictResolver(String name, ConflictResolver resolver) {
    _conflictResolvers[name] = resolver;
    _logger.info('Registered conflict resolver: $name');
  }

  /// Sets the auto-sync interval.
  void setAutoSyncInterval(Duration interval) {
    _autoSyncInterval = interval;
    _logger.info('Auto-sync interval set to: ${interval.inMinutes} minutes');
  }

  /// Sets the maximum number of retries for failed sync operations.
  void setMaxRetries(int maxRetries) {
    _maxRetries = maxRetries;
    _logger.info('Max retries set to: $maxRetries');
  }

  /// Enables or disables auto-sync.
  void setAutoSyncEnabled(bool enabled) {
    if (enabled) {
      _startAutoSync();
    } else {
      _stopAutoSync();
    }

    _updateStatus(autoSyncEnabled: enabled);
    _logger.info('Auto-sync ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Starts the auto-sync timer.
  void _startAutoSync() {
    _stopAutoSync();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      if (_currentStatus.isOnline && !_currentStatus.isSyncing) {
        syncAll();
      }
    });
  }

  /// Stops the auto-sync timer.
  void _stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Handles connectivity changes.
  void _onConnectivityChanged(bool isOnline) {
    _updateStatus(isOnline: isOnline);

    if (isOnline && _currentStatus.autoSyncEnabled) {
      // Trigger sync when coming back online
      syncAll();
    }
  }

  /// Updates the current sync status.
  Future<void> _updateStatus({
    bool? isOnline,
    bool? isSyncing,
    DateTime? lastSyncAt,
    int? pendingCount,
    int? failedCount,
    String? lastError,
    double? syncProgress,
    bool? autoSyncEnabled,
    SyncMode? syncMode,
    DateTime? nextSyncAt,
  }) async {
    _currentStatus = _currentStatus.copyWith(
      isOnline: isOnline,
      isSyncing: isSyncing,
      lastSyncAt: lastSyncAt,
      pendingCount: pendingCount,
      failedCount: failedCount,
      lastError: lastError,
      syncProgress: syncProgress,
      autoSyncEnabled: autoSyncEnabled,
      syncMode: syncMode,
      nextSyncAt: nextSyncAt,
    );

    _statusController?.add(_currentStatus);
  }

  /// Syncs all registered entities.
  Future<void> syncAll() async {
    if (_currentStatus.isSyncing) {
      _logger.warning('Sync already in progress');
      return;
    }

    if (!_currentStatus.isOnline) {
      _logger.warning('Cannot sync: device is offline');
      return;
    }

    _logger.info('Starting full sync');
    await _updateStatus(isSyncing: true, syncProgress: 0.0);

    try {
      final totalTables = _endpointMappings.length;
      int completedTables = 0;

      for (final entry in _endpointMappings.entries) {
        final tableName = entry.key;
        final endpoint = entry.value;

        _logger.info('Syncing table: $tableName');

        try {
          await _syncTable(tableName, endpoint);
          completedTables++;

          final progress = completedTables / totalTables;
          await _updateStatus(syncProgress: progress);
        } catch (e) {
          _logger.error('Failed to sync table: $tableName', e);
          await _updateStatus(failedCount: _currentStatus.failedCount + 1);
        }
      }

      await _updateStatus(
        isSyncing: false,
        lastSyncAt: DateTime.now(),
        syncProgress: 1.0,
        lastError: null,
      );

      _logger.info('Full sync completed');
    } catch (e) {
      _logger.error('Full sync failed', e);
      await _updateStatus(
        isSyncing: false,
        failedCount: _currentStatus.failedCount + 1,
        lastError: e.toString(),
      );
    }
  }

  /// Syncs a specific table.
  Future<void> _syncTable(String tableName, String endpoint) async {
    // First, push local changes to server
    await _pushLocalChanges(tableName, endpoint);

    // Then, pull remote changes from server
    await _pullRemoteChanges(tableName, endpoint);

    // Finally, resolve any conflicts
    await _resolveConflicts(tableName);
  }

  /// Pushes local changes to the server.
  Future<void> _pushLocalChanges(String tableName, String endpoint) async {
    final unsyncedEntities = await _database.findUnsynced(tableName);

    if (unsyncedEntities.isEmpty) {
      _logger.debug('No unsynced entities to push for table: $tableName');
      return;
    }

    _logger.info(
      'Pushing ${unsyncedEntities.length} entities for table: $tableName',
    );

    for (final entityData in unsyncedEntities) {
      try {
        // Convert Map to SyncEntity using the appropriate factory
        final factory = _entityFactories.firstWhere(
          (factory) =>
              factory(entityData).runtimeType.toString().contains('SyncEntity'),
          orElse: () => throw StateError('No factory found for entity data'),
        );
        final entity = factory(entityData);

        await _pushEntity(entity, endpoint);
      } catch (e) {
        _logger.error('Failed to push entity: ${entityData['id']}', e);
        // Create a temporary entity for the sync queue
        final tempEntity = _createTempEntity(entityData);
        await _addToSyncQueue(tempEntity, 'push', endpoint);
      }
    }
  }

  /// Creates a temporary entity from map data for sync queue.
  SyncEntity _createTempEntity(Map<String, dynamic> data) {
    // Create a basic SyncEntity implementation
    return _TempSyncEntity(
      id: data['id'] ?? '',
      tableName: data['table_name'] ?? 'unknown',
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data['updated_at'] ?? 0),
    );
  }

  /// Pushes a single entity to the server.
  Future<void> _pushEntity(SyncEntity entity, String endpoint) async {
    int retryCount = 0;

    while (retryCount <= _maxRetries) {
      try {
        final response = await _networkManager.post(
          endpoint,
          data: entity.toJson(),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Mark as synced
          final syncedEntity = entity.copyWith(syncedAt: DateTime.now());
          await _database.update(
            entity.tableName,
            syncedEntity.toJson(),
            where: 'id = ?',
            whereArgs: [entity.id],
          );
          _logger.debug('Successfully pushed entity: ${entity.id}');
          return;
        } else {
          throw Exception('Server returned status: ${response.statusCode}');
        }
      } catch (e) {
        retryCount++;
        if (retryCount > _maxRetries) {
          _logger.error(
            'Failed to push entity after $retryCount retries: ${entity.id}',
            e,
          );
          rethrow;
        }
        _logger.warning(
          'Retry $retryCount/$_maxRetries for entity: ${entity.id}',
        );
        await Future.delayed(
          Duration(seconds: retryCount * 2),
        ); // Exponential backoff
      }
    }
  }

  /// Pulls remote changes from the server.
  Future<void> _pullRemoteChanges(String tableName, String endpoint) async {
    int retryCount = 0;

    while (retryCount <= _maxRetries) {
      try {
        final response = await _networkManager.get(endpoint);

        if (response.statusCode == 200) {
          final List<dynamic> remoteData = response.data;
          _logger.info(
            'Pulled ${remoteData.length} entities for table: $tableName',
          );

          for (final data in remoteData) {
            try {
              await _processRemoteEntity(data, tableName);
            } catch (e) {
              _logger.error('Failed to process remote entity', e);
            }
          }
          return;
        } else {
          throw Exception('Server returned status: ${response.statusCode}');
        }
      } catch (e) {
        retryCount++;
        if (retryCount > _maxRetries) {
          _logger.error(
            'Failed to pull remote changes after $retryCount retries for table: $tableName',
            e,
          );
          return;
        }
        _logger.warning(
          'Retry $retryCount/$_maxRetries for pulling table: $tableName',
        );
        await Future.delayed(
          Duration(seconds: retryCount * 2),
        ); // Exponential backoff
      }
    }
  }

  /// Processes a remote entity.
  Future<void> _processRemoteEntity(
    Map<String, dynamic> data,
    String tableName,
  ) async {
    final remoteEntity = _createEntityFromData(data, tableName);
    final localEntityData = await _database.findById(
      tableName,
      remoteEntity.id,
    );
    final localEntity = localEntityData != null
        ? _createEntityFromData(localEntityData, tableName)
        : null;

    if (localEntity == null) {
      // New entity, insert it
      await _database.insert(tableName, remoteEntity.toJson());
      _logger.debug('Inserted new remote entity: ${remoteEntity.id}');
    } else {
      // Check for conflicts
      if (_hasConflict(localEntity, remoteEntity)) {
        await _handleConflict(localEntity, remoteEntity, tableName);
      } else {
        // No conflict, update local entity
        await _database.update(
          tableName,
          remoteEntity.toJson(),
          where: 'id = ?',
          whereArgs: [remoteEntity.id],
        );
        _logger.debug('Updated local entity: ${remoteEntity.id}');
      }
    }
  }

  /// Creates an entity from remote data.
  SyncEntity _createEntityFromData(
    Map<String, dynamic> data,
    String tableName,
  ) {
    for (final factory in _entityFactories) {
      try {
        final entity = factory(data);
        if (entity.tableName == tableName) {
          return entity;
        }
      } catch (e) {
        // Continue to next factory
      }
    }

    throw StateError('No factory found for table: $tableName');
  }

  /// Checks if there's a conflict between local and remote entities.
  bool _hasConflict(SyncEntity local, SyncEntity remote) {
    // Check if both have been modified since last sync
    if (local.syncedAt != null &&
        local.updatedAt.isAfter(local.syncedAt!) &&
        remote.updatedAt.isAfter(local.syncedAt!)) {
      return true;
    }

    // Check version mismatch
    if (local.version != remote.version) {
      return true;
    }

    return false;
  }

  /// Handles a conflict between local and remote entities.
  Future<void> _handleConflict(
    SyncEntity local,
    SyncEntity remote,
    String tableName,
  ) async {
    final conflict = SyncConflict(
      entityId: local.id,
      localEntity: local,
      remoteEntity: remote,
      conflictType: ConflictType.bothModified,
      detectedAt: DateTime.now(),
    );

    _logger.warning('Conflict detected for entity: ${local.id}');

    // Try to resolve the conflict
    final resolvedEntity = await _resolveConflict(conflict);

    if (resolvedEntity != null) {
      await _database.update(
        tableName,
        resolvedEntity.toJson(),
        where: 'id = ?',
        whereArgs: [resolvedEntity.id],
      );
      _logger.info('Conflict resolved for entity: ${local.id}');
    } else {
      // Store conflict for manual resolution
      await _storeConflict(conflict);
      _logger.warning('Conflict stored for manual resolution: ${local.id}');
    }
  }

  /// Resolves a conflict using registered resolvers.
  Future<SyncEntity?> _resolveConflict(SyncConflict conflict) async {
    // Try resolvers in order of priority
    final resolvers = _conflictResolvers.values.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final resolver in resolvers) {
      if (resolver.canResolve(conflict.conflictType)) {
        try {
          final resolved = await resolver.resolve(conflict);
          if (resolved != null) {
            return resolved;
          }
        } catch (e) {
          _logger.error(
            'Resolver failed for conflict: ${conflict.entityId}',
            e,
          );
        }
      }
    }

    return null;
  }

  /// Stores a conflict for manual resolution.
  Future<void> _storeConflict(SyncConflict conflict) async {
    // Implementation would store the conflict in the database
    // This is a simplified version
    _logger.info(
      'Storing conflict for manual resolution: ${conflict.entityId}',
    );
  }

  /// Resolves stored conflicts.
  Future<void> _resolveConflicts(String tableName) async {
    // Implementation would retrieve and resolve stored conflicts
    // This is a simplified version
    _logger.debug('Resolving conflicts for table: $tableName');
  }

  /// Adds an entity to the sync queue for retry.
  Future<void> _addToSyncQueue(
    SyncEntity entity,
    String operation,
    String endpoint,
  ) async {
    // Implementation would add the entity to a retry queue
    // This is a simplified version
    _logger.info('Added entity to sync queue: ${entity.id}');
  }

  /// Gets the current sync status.
  SyncStatus get status => _currentStatus;

  /// Stream of sync status changes.
  Stream<SyncStatus> get statusStream =>
      _statusController?.stream ?? Stream.value(_currentStatus);

  /// Disposes of the sync engine.
  Future<void> dispose() async {
    _stopAutoSync();
    await _statusController?.close();
    _logger.info('Sync engine disposed');
  }
}

/// Temporary SyncEntity implementation for sync queue.
class _TempSyncEntity extends SyncEntity {
  final String _tableName;

  _TempSyncEntity({
    required String id,
    required String tableName,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : _tableName = tableName,
       super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  String get tableName => _tableName;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'table_name': tableName,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  @override
  SyncEntity copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool? isDeleted,
    int? version,
    Map<String, dynamic>? metadata,
  }) {
    return _TempSyncEntity(
      id: id ?? this.id,
      tableName: _tableName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
