import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'sync_entity.dart';

part 'conflict_resolution.g.dart';

/// Represents a conflict between local and remote versions of an entity.
@JsonSerializable()
class SyncConflict extends Equatable {
  /// The ID of the conflicting entity
  final String entityId;

  /// The local version of the entity
  final SyncEntity localEntity;

  /// The remote version of the entity
  final SyncEntity remoteEntity;

  /// The type of conflict
  final ConflictType conflictType;

  /// The timestamp when the conflict was detected
  @JsonKey(name: 'detected_at')
  final DateTime detectedAt;

  /// Whether the conflict has been resolved
  @JsonKey(name: 'is_resolved')
  final bool isResolved;

  /// The resolution strategy used to resolve the conflict
  @JsonKey(name: 'resolution_strategy')
  final ConflictResolutionStrategy? resolutionStrategy;

  /// The resolved entity (if conflict has been resolved)
  @JsonKey(name: 'resolved_entity')
  final SyncEntity? resolvedEntity;

  const SyncConflict({
    required this.entityId,
    required this.localEntity,
    required this.remoteEntity,
    required this.conflictType,
    required this.detectedAt,
    this.isResolved = false,
    this.resolutionStrategy,
    this.resolvedEntity,
  });

  /// Creates a copy of this conflict with the given fields replaced with new values.
  SyncConflict copyWith({
    String? entityId,
    SyncEntity? localEntity,
    SyncEntity? remoteEntity,
    ConflictType? conflictType,
    DateTime? detectedAt,
    bool? isResolved,
    ConflictResolutionStrategy? resolutionStrategy,
    SyncEntity? resolvedEntity,
  }) {
    return SyncConflict(
      entityId: entityId ?? this.entityId,
      localEntity: localEntity ?? this.localEntity,
      remoteEntity: remoteEntity ?? this.remoteEntity,
      conflictType: conflictType ?? this.conflictType,
      detectedAt: detectedAt ?? this.detectedAt,
      isResolved: isResolved ?? this.isResolved,
      resolutionStrategy: resolutionStrategy ?? this.resolutionStrategy,
      resolvedEntity: resolvedEntity ?? this.resolvedEntity,
    );
  }

  /// Converts the conflict to a JSON map.
  Map<String, dynamic> toJson() => _$SyncConflictToJson(this);

  /// Creates a conflict from a JSON map.
  factory SyncConflict.fromJson(Map<String, dynamic> json) =>
      _$SyncConflictFromJson(json);

  @override
  List<Object?> get props => [
    entityId,
    localEntity,
    remoteEntity,
    conflictType,
    detectedAt,
    isResolved,
    resolutionStrategy,
    resolvedEntity,
  ];

  @override
  String toString() {
    return 'SyncConflict(entityId: $entityId, conflictType: $conflictType, '
        'detectedAt: $detectedAt, isResolved: $isResolved)';
  }
}

/// Enum representing different types of conflicts.
enum ConflictType {
  /// Both local and remote versions have been modified
  bothModified,

  /// Local version was deleted but remote version was modified
  localDeletedRemoteModified,

  /// Local version was modified but remote version was deleted
  localModifiedRemoteDeleted,

  /// Both versions were deleted
  bothDeleted,

  /// Version mismatch (different version numbers)
  versionMismatch,

  /// Data corruption or integrity issues
  dataCorruption,
}

/// Enum representing different conflict resolution strategies.
enum ConflictResolutionStrategy {
  /// Use the local version (last-write-wins locally)
  useLocal,

  /// Use the remote version (last-write-wins remotely)
  useRemote,

  /// Merge both versions (custom merge logic)
  merge,

  /// Use the version with the latest timestamp
  useLatest,

  /// Use the version with the highest version number
  useHighestVersion,

  /// Custom resolution strategy
  custom,

  /// Skip the conflict (don't sync this entity)
  skip,
}

/// Abstract class for custom conflict resolvers.
abstract class ConflictResolver {
  /// Resolves a conflict between local and remote entities.
  ///
  /// Returns the resolved entity, or null if the conflict cannot be resolved.
  Future<SyncEntity?> resolve(SyncConflict conflict);

  /// Returns true if this resolver can handle the given conflict type.
  bool canResolve(ConflictType conflictType);

  /// Returns the priority of this resolver (higher numbers = higher priority).
  int get priority => 0;
}

/// Default conflict resolver that uses last-write-wins strategy.
class DefaultConflictResolver implements ConflictResolver {
  final ConflictResolutionStrategy defaultStrategy;

  const DefaultConflictResolver({
    this.defaultStrategy = ConflictResolutionStrategy.useLatest,
  });

  @override
  Future<SyncEntity?> resolve(SyncConflict conflict) async {
    switch (defaultStrategy) {
      case ConflictResolutionStrategy.useLocal:
        return conflict.localEntity;
      case ConflictResolutionStrategy.useRemote:
        return conflict.remoteEntity;
      case ConflictResolutionStrategy.useLatest:
        return _useLatest(conflict);
      case ConflictResolutionStrategy.useHighestVersion:
        return _useHighestVersion(conflict);
      case ConflictResolutionStrategy.merge:
        return _merge(conflict);
      case ConflictResolutionStrategy.custom:
        return null; // Custom resolvers should be implemented separately
      case ConflictResolutionStrategy.skip:
        return null; // Skip this conflict
    }
  }

  @override
  bool canResolve(ConflictType conflictType) {
    return conflictType != ConflictType.dataCorruption;
  }

  @override
  int get priority => 0;

  /// Uses the entity with the latest updated timestamp.
  SyncEntity _useLatest(SyncConflict conflict) {
    if (conflict.localEntity.updatedAt.isAfter(
      conflict.remoteEntity.updatedAt,
    )) {
      return conflict.localEntity;
    } else {
      return conflict.remoteEntity;
    }
  }

  /// Uses the entity with the highest version number.
  SyncEntity _useHighestVersion(SyncConflict conflict) {
    if (conflict.localEntity.version > conflict.remoteEntity.version) {
      return conflict.localEntity;
    } else {
      return conflict.remoteEntity;
    }
  }

  /// Attempts to merge both entities (basic implementation).
  SyncEntity _merge(SyncConflict conflict) {
    // This is a basic merge implementation
    // In a real application, you would implement more sophisticated merge logic

    // For now, just use the latest version
    return _useLatest(conflict);
  }
}

/// Extension methods for ConflictType enum.
extension ConflictTypeExtension on ConflictType {
  /// Returns the string representation of the conflict type.
  String get value {
    switch (this) {
      case ConflictType.bothModified:
        return 'both_modified';
      case ConflictType.localDeletedRemoteModified:
        return 'local_deleted_remote_modified';
      case ConflictType.localModifiedRemoteDeleted:
        return 'local_modified_remote_deleted';
      case ConflictType.bothDeleted:
        return 'both_deleted';
      case ConflictType.versionMismatch:
        return 'version_mismatch';
      case ConflictType.dataCorruption:
        return 'data_corruption';
    }
  }

  /// Creates a ConflictType from its string representation.
  static ConflictType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'both_modified':
        return ConflictType.bothModified;
      case 'local_deleted_remote_modified':
        return ConflictType.localDeletedRemoteModified;
      case 'local_modified_remote_deleted':
        return ConflictType.localModifiedRemoteDeleted;
      case 'both_deleted':
        return ConflictType.bothDeleted;
      case 'version_mismatch':
        return ConflictType.versionMismatch;
      case 'data_corruption':
        return ConflictType.dataCorruption;
      default:
        throw ArgumentError('Invalid conflict type: $value');
    }
  }
}

/// Extension methods for ConflictResolutionStrategy enum.
extension ConflictResolutionStrategyExtension on ConflictResolutionStrategy {
  /// Returns the string representation of the resolution strategy.
  String get value {
    switch (this) {
      case ConflictResolutionStrategy.useLocal:
        return 'use_local';
      case ConflictResolutionStrategy.useRemote:
        return 'use_remote';
      case ConflictResolutionStrategy.merge:
        return 'merge';
      case ConflictResolutionStrategy.useLatest:
        return 'use_latest';
      case ConflictResolutionStrategy.useHighestVersion:
        return 'use_highest_version';
      case ConflictResolutionStrategy.custom:
        return 'custom';
      case ConflictResolutionStrategy.skip:
        return 'skip';
    }
  }

  /// Creates a ConflictResolutionStrategy from its string representation.
  static ConflictResolutionStrategy fromString(String value) {
    switch (value.toLowerCase()) {
      case 'use_local':
        return ConflictResolutionStrategy.useLocal;
      case 'use_remote':
        return ConflictResolutionStrategy.useRemote;
      case 'merge':
        return ConflictResolutionStrategy.merge;
      case 'use_latest':
        return ConflictResolutionStrategy.useLatest;
      case 'use_highest_version':
        return ConflictResolutionStrategy.useHighestVersion;
      case 'custom':
        return ConflictResolutionStrategy.custom;
      case 'skip':
        return ConflictResolutionStrategy.skip;
      default:
        throw ArgumentError('Invalid resolution strategy: $value');
    }
  }
}
