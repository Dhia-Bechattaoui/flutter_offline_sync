// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conflict_resolution.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncConflict _$SyncConflictFromJson(Map<String, dynamic> json) => SyncConflict(
  entityId: json['entityId'] as String,
  localEntity: SyncEntity.fromJson(json['localEntity'] as Map<String, dynamic>),
  remoteEntity: SyncEntity.fromJson(
    json['remoteEntity'] as Map<String, dynamic>,
  ),
  conflictType: $enumDecode(_$ConflictTypeEnumMap, json['conflictType']),
  detectedAt: DateTime.parse(json['detected_at'] as String),
  isResolved: json['is_resolved'] as bool? ?? false,
  resolutionStrategy: $enumDecodeNullable(
    _$ConflictResolutionStrategyEnumMap,
    json['resolution_strategy'],
  ),
  resolvedEntity: json['resolved_entity'] == null
      ? null
      : SyncEntity.fromJson(json['resolved_entity'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SyncConflictToJson(SyncConflict instance) =>
    <String, dynamic>{
      'entityId': instance.entityId,
      'localEntity': instance.localEntity,
      'remoteEntity': instance.remoteEntity,
      'conflictType': _$ConflictTypeEnumMap[instance.conflictType]!,
      'detected_at': instance.detectedAt.toIso8601String(),
      'is_resolved': instance.isResolved,
      'resolution_strategy':
          _$ConflictResolutionStrategyEnumMap[instance.resolutionStrategy],
      'resolved_entity': instance.resolvedEntity,
    };

const _$ConflictTypeEnumMap = {
  ConflictType.bothModified: 'bothModified',
  ConflictType.localDeletedRemoteModified: 'localDeletedRemoteModified',
  ConflictType.localModifiedRemoteDeleted: 'localModifiedRemoteDeleted',
  ConflictType.bothDeleted: 'bothDeleted',
  ConflictType.versionMismatch: 'versionMismatch',
  ConflictType.dataCorruption: 'dataCorruption',
};

const _$ConflictResolutionStrategyEnumMap = {
  ConflictResolutionStrategy.useLocal: 'useLocal',
  ConflictResolutionStrategy.useRemote: 'useRemote',
  ConflictResolutionStrategy.merge: 'merge',
  ConflictResolutionStrategy.useLatest: 'useLatest',
  ConflictResolutionStrategy.useHighestVersion: 'useHighestVersion',
  ConflictResolutionStrategy.custom: 'custom',
  ConflictResolutionStrategy.skip: 'skip',
};
