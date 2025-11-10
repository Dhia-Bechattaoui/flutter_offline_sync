import 'dart:convert';

import '../models/sync_entity.dart';
import 'offline_database.dart';

/// Utility helpers for encoding/decoding [SyncEntity] instances to/from
/// persistent storage representations.
class EntityCodec {
  const EntityCodec._();

  /// Serializes an entity into a storage-ready map.
  static Map<String, dynamic> serializeForStorage(
    SyncEntity entity, {
    String syncStatus = 'pending',
    bool includeId = true,
    String? lastError,
  }) {
    final payload = serializePayload(entity);

    final row = <String, dynamic>{
      'payload': jsonEncode(payload),
      'sync_status': syncStatus,
      'is_deleted': entity.isDeleted ? 1 : 0,
      'version': entity.version,
      'created_at': entity.createdAt.millisecondsSinceEpoch,
      'updated_at': entity.updatedAt.millisecondsSinceEpoch,
      'synced_at': entity.syncedAt?.millisecondsSinceEpoch,
      'metadata': entity.metadata != null ? jsonEncode(entity.metadata) : null,
      'last_error': lastError,
    };

    if (includeId) {
      row['id'] = entity.id;
    }

    return row;
  }

  /// Serializes only the payload (JSON representation) for storage.
  static Map<String, dynamic> serializePayload(SyncEntity entity) {
    final payload = Map<String, dynamic>.from(entity.toJson());

    payload['id'] = entity.id;
    payload['created_at'] ??= entity.createdAt.millisecondsSinceEpoch;
    payload['updated_at'] = entity.updatedAt.millisecondsSinceEpoch;
    payload['synced_at'] ??= entity.syncedAt?.millisecondsSinceEpoch;
    payload['version'] ??= entity.version;
    payload['is_deleted'] ??= entity.isDeleted;
    if (entity.metadata != null) {
      payload['metadata'] ??= entity.metadata;
    }

    return payload;
  }

  /// Recreates an entity from a stored database row.
  static SyncEntity materialize(
    OfflineDatabase database,
    String tableName,
    Map<String, dynamic> row,
  ) {
    final payload = _decodePayload(row['payload']);

    payload['id'] ??= row['id'];
    payload['created_at'] ??= row['created_at'];
    payload['updated_at'] = row['updated_at'];
    payload['synced_at'] ??= row['synced_at'];
    payload['version'] ??= row['version'];
    payload['is_deleted'] = row['is_deleted'] == 1;
    payload['metadata'] ??= _decodeMetadata(row['metadata']);
    payload['sync_status'] ??= row['sync_status'];
    if (row.containsKey('deleted_at')) {
      payload['deleted_at'] ??= row['deleted_at'];
    }
    if (row.containsKey('last_error')) {
      payload['last_error'] ??= row['last_error'];
    }

    return database.createEntity(tableName, payload);
  }

  static Map<String, dynamic> _decodePayload(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload);
    }
    if (payload is String && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // ignore malformed payloads
      }
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic>? _decodeMetadata(dynamic metadata) {
    if (metadata == null) return null;
    if (metadata is Map<String, dynamic>) {
      return Map<String, dynamic>.from(metadata);
    }
    if (metadata is String && metadata.isNotEmpty) {
      try {
        final decoded = jsonDecode(metadata);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // ignore malformed metadata
      }
    }
    return null;
  }
}
