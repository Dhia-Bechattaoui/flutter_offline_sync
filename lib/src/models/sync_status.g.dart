// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncStatus _$SyncStatusFromJson(Map<String, dynamic> json) => SyncStatus(
  isOnline: json['isOnline'] as bool,
  isSyncing: json['isSyncing'] as bool,
  lastSyncAt: _dateTimeFromTimestamp(json['last_sync_at']),
  pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
  failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
  lastError: json['last_error'] as String?,
  syncProgress: (json['sync_progress'] as num?)?.toDouble() ?? 0.0,
  autoSyncEnabled: json['auto_sync_enabled'] as bool? ?? true,
  syncMode:
      $enumDecodeNullable(_$SyncModeEnumMap, json['sync_mode']) ??
      SyncMode.automatic,
  nextSyncAt: _dateTimeFromTimestamp(json['next_sync_at']),
);

Map<String, dynamic> _$SyncStatusToJson(SyncStatus instance) =>
    <String, dynamic>{
      'isOnline': instance.isOnline,
      'isSyncing': instance.isSyncing,
      'last_sync_at': _dateTimeToTimestamp(instance.lastSyncAt),
      'pending_count': instance.pendingCount,
      'failed_count': instance.failedCount,
      'last_error': instance.lastError,
      'sync_progress': instance.syncProgress,
      'auto_sync_enabled': instance.autoSyncEnabled,
      'sync_mode': _$SyncModeEnumMap[instance.syncMode]!,
      'next_sync_at': _dateTimeToTimestamp(instance.nextSyncAt),
    };

const _$SyncModeEnumMap = {
  SyncMode.manual: 'manual',
  SyncMode.automatic: 'automatic',
  SyncMode.scheduled: 'scheduled',
};
