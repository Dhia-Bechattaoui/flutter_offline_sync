import 'package:equatable/equatable.dart';

/// Base class for all entities that can be synced offline.
///
/// This abstract class provides the necessary fields and methods
/// for offline synchronization functionality.
abstract class SyncEntity extends Equatable {
  /// Unique identifier for the entity
  final String id;

  /// Timestamp when the entity was created
  final DateTime createdAt;

  /// Timestamp when the entity was last updated
  final DateTime updatedAt;

  /// Timestamp when the entity was last synced with the server
  final DateTime? syncedAt;

  /// Whether the entity has been deleted (soft delete)
  final bool isDeleted;

  /// Version number for conflict resolution
  final int version;

  /// Custom metadata that can be attached to the entity
  final Map<String, dynamic>? metadata;

  const SyncEntity({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
    this.isDeleted = false,
    this.version = 1,
    this.metadata,
  });

  /// Creates a copy of this entity with the given fields replaced with new values.
  SyncEntity copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool? isDeleted,
    int? version,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('copyWith must be implemented by subclasses');
  }

  /// Converts the entity to a JSON map.
  Map<String, dynamic> toJson() {
    throw UnimplementedError('toJson must be implemented by subclasses');
  }

  /// Creates an entity from a JSON map.
  factory SyncEntity.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError('fromJson must be implemented by subclasses');
  }

  /// Returns the table name for database storage.
  String get tableName;

  /// Returns the primary key field name.
  String get primaryKey => 'id';

  /// Returns the fields that should be indexed for faster queries.
  List<String> get indexedFields => ['created_at', 'updated_at', 'synced_at'];

  /// Returns the fields that should be unique.
  List<String> get uniqueFields => ['id'];

  /// Returns the fields that should be not null.
  List<String> get notNullFields => [
    'id',
    'created_at',
    'updated_at',
    'version',
  ];

  /// Returns the SQLite column definitions for this entity.
  Map<String, String> get columnDefinitions => {
    'id': 'TEXT PRIMARY KEY',
    'created_at': 'INTEGER NOT NULL',
    'updated_at': 'INTEGER NOT NULL',
    'synced_at': 'INTEGER',
    'is_deleted': 'INTEGER NOT NULL DEFAULT 0',
    'version': 'INTEGER NOT NULL DEFAULT 1',
    'metadata': 'TEXT',
  };

  @override
  List<Object?> get props => [
    id,
    createdAt,
    updatedAt,
    syncedAt,
    isDeleted,
    version,
    metadata,
  ];

  @override
  String toString() {
    return 'SyncEntity(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, '
        'syncedAt: $syncedAt, isDeleted: $isDeleted, version: $version)';
  }
}
