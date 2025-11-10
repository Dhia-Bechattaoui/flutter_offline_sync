import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../database/entity_codec.dart';
import '../models/conflict_resolution.dart';
import '../models/sync_entity.dart';
import '../models/sync_status.dart';
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
  final Uuid _uuid = const Uuid();

  StreamController<SyncStatus>? _statusController;
  SyncStatus _currentStatus = const SyncStatus(
    isOnline: false,
    isSyncing: false,
  );

  Timer? _autoSyncTimer;
  Duration _autoSyncInterval = const Duration(minutes: 5);
  int _maxRetries = 3;
  int _batchSize = 50;

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
    _database.registerEntity(tableName, '''
      CREATE TABLE IF NOT EXISTS $tableName (
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        version INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced_at INTEGER,
        deleted_at INTEGER,
        metadata TEXT,
        last_error TEXT
      )
      ''', fromJson);
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

  /// Sets the batch size for sync operations.
  void setBatchSize(int batchSize) {
    _batchSize = batchSize.clamp(1, 500);
    _logger.info('Batch size set to: $_batchSize');
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
      await _processSyncQueue();

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
        pendingCount: await _calculatePendingCount(),
      );

      _logger.info('Full sync completed');
    } catch (e) {
      _logger.error('Full sync failed', e);
      await _updateStatus(
        isSyncing: false,
        failedCount: _currentStatus.failedCount + 1,
        lastError: e.toString(),
        pendingCount: await _calculatePendingCount(),
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

  Future<void> _processSyncQueue() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final queued = await _database.rawQuery(
      '''
      SELECT * FROM sync_queue
      WHERE next_retry_at IS NULL OR next_retry_at <= ?
      ''',
      [now],
    );

    if (queued.isEmpty) {
      return;
    }

    _logger.info('Processing ${queued.length} queued sync operations');

    for (final item in queued) {
      final operation = (item['operation'] as String?) ?? 'push';
      final tableName = item['table_name'] as String;
      final endpoint = item['endpoint'] as String;
      final payload = item['payload'] as String? ?? '{}';

      try {
        switch (operation) {
          case 'push':
            final decoded = jsonDecode(payload) as Map<String, dynamic>;
            final entity = _database.createEntity(
              tableName,
              Map<String, dynamic>.from(decoded),
            );
            await _pushEntity(entity, endpoint, queueOnFailure: false);
            await _database.delete(
              'sync_queue',
              where: 'id = ?',
              whereArgs: [item['id']],
            );
            break;
          default:
            _logger.warning('Unsupported queue operation: $operation');
            await _database.delete(
              'sync_queue',
              where: 'id = ?',
              whereArgs: [item['id']],
            );
        }
      } catch (e, stackTrace) {
        final retryCount = (item['retry_count'] as int? ?? 0) + 1;
        final maxRetries = item['max_retries'] as int? ?? _maxRetries;

        if (retryCount >= maxRetries) {
          _logger.error(
            'Dropping queued operation ${item['id']} after $retryCount retries',
            e,
            stackTrace,
          );

          await _database.update(
            tableName,
            {
              'sync_status': 'error',
              'last_error': e.toString(),
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [item['entity_id']],
          );

          await _database.delete(
            'sync_queue',
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        } else {
          final nextRetry = DateTime.now().add(
            Duration(seconds: (retryCount + 1) * 3),
          );
          await _database.update(
            'sync_queue',
            {
              'retry_count': retryCount,
              'next_retry_at': nextRetry.millisecondsSinceEpoch,
              'last_error': e.toString(),
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        }
      }
    }
  }

  List<List<Map<String, dynamic>>> _chunkRows(
    List<Map<String, dynamic>> rows,
    int size,
  ) {
    if (rows.isEmpty || size <= 0) {
      return [];
    }

    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < rows.length; i += size) {
      chunks.add(rows.sublist(i, math.min(i + size, rows.length)));
    }
    return chunks;
  }

  List<List<dynamic>> _chunkDynamic(List<dynamic> items, int size) {
    if (items.isEmpty || size <= 0) {
      return [];
    }

    final chunks = <List<dynamic>>[];
    for (var i = 0; i < items.length; i += size) {
      chunks.add(items.sublist(i, math.min(i + size, items.length)));
    }
    return chunks;
  }

  /// Pushes local changes to the server.
  Future<void> _pushLocalChanges(String tableName, String endpoint) async {
    final unsyncedRows = await _database.findUnsynced(tableName);

    if (unsyncedRows.isEmpty) {
      _logger.debug('No unsynced entities to push for table: $tableName');
      return;
    }

    _logger.info(
      'Pushing ${unsyncedRows.length} entities for table: $tableName',
    );

    final batches = _chunkRows(unsyncedRows, _batchSize);

    for (final batch in batches) {
      for (final row in batch) {
        try {
          final entity = EntityCodec.materialize(_database, tableName, row);
          await _pushEntity(entity, endpoint);
        } catch (e, stackTrace) {
          final id = row['id'];
          _logger.error('Failed to push entity: $id', e, stackTrace);
          final tempEntity = _createTempEntity(tableName, row);
          await _addToSyncQueue(
            tempEntity,
            operation: 'push',
            endpoint: endpoint,
            payloadOverride: row['payload'] as String?,
            lastError: e.toString(),
          );
        }
      }
    }
  }

  /// Creates a temporary entity from persisted data for queue fallback.
  SyncEntity _createTempEntity(String tableName, Map<String, dynamic> row) {
    final createdAtMillis =
        (row['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
    final updatedAtMillis =
        (row['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch;

    return _TempSyncEntity(
      id: (row['id'] ?? '') as String,
      tableName: tableName,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMillis),
      payload: row['payload'] as String?,
    );
  }

  /// Pushes a single entity to the server.
  Future<void> _pushEntity(
    SyncEntity entity,
    String endpoint, {
    bool queueOnFailure = true,
  }) async {
    int retryCount = 0;

    while (retryCount <= _maxRetries) {
      try {
        final response = await _networkManager.post(
          endpoint,
          data: entity.toJson(),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final syncedAt = DateTime.now();
          final syncedEntity = entity.copyWith(syncedAt: syncedAt);
          final storageUpdate =
              EntityCodec.serializeForStorage(
                  syncedEntity,
                  syncStatus: 'synced',
                  includeId: false,
                  lastError: null,
                )
                ..remove('id')
                ..['last_error'] = null;

          await _database.update(
            entity.tableName,
            storageUpdate,
            where: 'id = ?',
            whereArgs: [entity.id],
          );
          _logger.debug('Successfully pushed entity: ${entity.id}');
          return;
        } else {
          throw Exception('Server returned status: ${response.statusCode}');
        }
      } catch (e, stackTrace) {
        retryCount++;
        if (retryCount > _maxRetries) {
          final errorMessage = e.toString();
          _logger.error(
            'Failed to push entity after $retryCount retries: ${entity.id}',
            e,
            stackTrace,
          );

          await _database.update(
            entity.tableName,
            {
              'sync_status': 'error',
              'last_error': errorMessage,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [entity.id],
          );

          if (queueOnFailure) {
            await _addToSyncQueue(
              entity,
              operation: 'push',
              endpoint: endpoint,
              payloadOverride: jsonEncode(EntityCodec.serializePayload(entity)),
              lastError: errorMessage,
            );
            return;
          }

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
          final List<dynamic> remoteData = response.data is List
              ? response.data as List<dynamic>
              : [];
          _logger.info(
            'Pulled ${remoteData.length} entities for table: $tableName',
          );

          final batches = _chunkDynamic(remoteData, _batchSize);
          for (final batch in batches) {
            for (final data in batch) {
              try {
                if (data is Map<String, dynamic>) {
                  await _processRemoteEntity(data, tableName);
                } else {
                  _logger.warning(
                    'Skipping remote entity with unexpected type: '
                    '${data.runtimeType}',
                  );
                }
              } catch (e, stackTrace) {
                _logger.error('Failed to process remote entity', e, stackTrace);
              }
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
    final remoteEntity = _createEntityFromData(
      data,
      tableName,
    ).copyWith(syncedAt: DateTime.now());
    final localRow = await _database.findById(tableName, remoteEntity.id);
    final localEntity = localRow != null
        ? EntityCodec.materialize(_database, tableName, localRow)
        : null;

    if (localEntity == null) {
      final storage = EntityCodec.serializeForStorage(
        remoteEntity,
        syncStatus: 'synced',
      );
      await _database.insert(tableName, storage);
      _logger.debug('Inserted new remote entity: ${remoteEntity.id}');
    } else {
      if (_hasConflict(localEntity, remoteEntity)) {
        await _handleConflict(localEntity, remoteEntity, tableName);
      } else {
        final storage =
            EntityCodec.serializeForStorage(remoteEntity, syncStatus: 'synced')
              ..remove('id')
              ..['last_error'] = null;
        await _database.update(
          tableName,
          storage,
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
    if (data.containsKey('payload')) {
      return EntityCodec.materialize(_database, tableName, data);
    }

    return _database.createEntity(tableName, Map<String, dynamic>.from(data));
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
      final storage =
          EntityCodec.serializeForStorage(
              resolvedEntity.copyWith(syncedAt: DateTime.now()),
              syncStatus: 'synced',
            )
            ..remove('id')
            ..['last_error'] = null;

      await _database.update(
        tableName,
        storage,
        where: 'id = ?',
        whereArgs: [resolvedEntity.id],
      );
      _logger.info('Conflict resolved for entity: ${local.id}');
    } else {
      // Store conflict for manual resolution
      await _storeConflict(conflict);
      await _database.update(
        tableName,
        {
          'sync_status': 'conflict',
          'last_error': 'Conflict requires manual resolution',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [local.id],
      );
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
    final conflictId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final localPayload = jsonEncode(
      EntityCodec.serializePayload(conflict.localEntity),
    );
    final remotePayload = jsonEncode(
      EntityCodec.serializePayload(conflict.remoteEntity),
    );

    await _database.insert('sync_conflicts', {
      'id': conflictId,
      'entity_id': conflict.entityId,
      'entity_type': conflict.localEntity.tableName,
      'local_data': localPayload,
      'remote_data': remotePayload,
      'conflict_type': conflict.conflictType.value,
      'detected_at': conflict.detectedAt.millisecondsSinceEpoch,
      'is_resolved': 0,
      'resolution_strategy': conflict.resolutionStrategy?.value,
      'created_at': now,
      'updated_at': now,
    });

    _logger.info(
      'Stored conflict ${conflictId} for entity: ${conflict.entityId}',
    );
  }

  /// Resolves stored conflicts.
  Future<void> _resolveConflicts(String tableName) async {
    final conflicts = await _database.rawQuery(
      'SELECT * FROM sync_conflicts WHERE entity_type = ? AND is_resolved = 0',
      [tableName],
    );

    if (conflicts.isEmpty) {
      return;
    }

    _logger.info('Attempting to resolve ${conflicts.length} stored conflicts');

    for (final row in conflicts) {
      try {
        final conflictType = ConflictTypeExtension.fromString(
          (row['conflict_type'] as String?) ?? 'both_modified',
        );
        final localData =
            jsonDecode(row['local_data'] as String) as Map<String, dynamic>;
        final remoteData =
            jsonDecode(row['remote_data'] as String) as Map<String, dynamic>;

        final conflict = SyncConflict(
          entityId: row['entity_id'] as String,
          localEntity: _database.createEntity(
            tableName,
            Map<String, dynamic>.from(localData),
          ),
          remoteEntity: _database.createEntity(
            tableName,
            Map<String, dynamic>.from(remoteData),
          ),
          conflictType: conflictType,
          detectedAt: DateTime.fromMillisecondsSinceEpoch(
            row['detected_at'] as int,
          ),
        );

        final resolved = await _resolveConflict(conflict);
        if (resolved != null) {
          final storage =
              EntityCodec.serializeForStorage(
                  resolved.copyWith(syncedAt: DateTime.now()),
                  syncStatus: 'synced',
                )
                ..remove('id')
                ..['last_error'] = null;

          await _database.update(
            tableName,
            storage,
            where: 'id = ?',
            whereArgs: [resolved.id],
          );

          await _database.update(
            'sync_conflicts',
            {
              'is_resolved': 1,
              'resolved_at': DateTime.now().millisecondsSinceEpoch,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [row['id']],
          );

          _logger.info('Resolved stored conflict for entity: ${resolved.id}');
        }
      } catch (e, stackTrace) {
        _logger.error('Failed to resolve stored conflict', e, stackTrace);
      }
    }
  }

  /// Adds an entity to the sync queue for retry.
  Future<void> _addToSyncQueue(
    SyncEntity entity, {
    required String operation,
    required String endpoint,
    String? payloadOverride,
    String? lastError,
  }) async {
    final now = DateTime.now();
    final payload =
        payloadOverride ?? jsonEncode(EntityCodec.serializePayload(entity));

    await _database.insert('sync_queue', {
      'id': _uuid.v4(),
      'entity_id': entity.id,
      'table_name': entity.tableName,
      'endpoint': endpoint,
      'operation': operation,
      'payload': payload,
      'retry_count': 0,
      'max_retries': _maxRetries,
      'next_retry_at': now
          .add(const Duration(minutes: 1))
          .millisecondsSinceEpoch,
      'last_error': lastError,
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    });

    await _database.update(
      entity.tableName,
      {
        'sync_status': 'queued',
        'last_error': lastError,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [entity.id],
    );

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

  Future<int> _calculatePendingCount() async {
    var total = 0;
    for (final tableName in _endpointMappings.keys) {
      total += await _database.count(
        tableName,
        where: 'sync_status != ?',
        whereArgs: ['synced'],
      );
    }
    return total;
  }
}

/// Temporary SyncEntity implementation for sync queue.
class _TempSyncEntity extends SyncEntity {
  final String _tableName;
  final String? payload;

  _TempSyncEntity({
    required String id,
    required String tableName,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.payload,
  }) : _tableName = tableName,
       super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  String get tableName => _tableName;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'table_name': tableName,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'synced_at': null,
    'is_deleted': 0,
    'version': 1,
    'metadata': null,
    if (payload != null) 'payload': payload,
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
      payload: payload,
    );
  }
}
