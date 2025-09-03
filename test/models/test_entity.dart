import 'package:flutter_offline_sync/flutter_offline_sync.dart';

class TestEntity extends SyncEntity {
  final String name;
  final int value;

  const TestEntity({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.name,
    required this.value,
    super.syncedAt,
    super.isDeleted,
    super.version,
    super.metadata,
  });

  @override
  TestEntity copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool? isDeleted,
    int? version,
    Map<String, dynamic>? metadata,
    String? name,
    int? value,
  }) {
    return TestEntity(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      metadata: metadata ?? this.metadata,
      name: name ?? this.name,
      value: value ?? this.value,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'value': value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'is_deleted': isDeleted,
      'version': version,
      'metadata': metadata,
    };
  }

  @override
  factory TestEntity.fromJson(Map<String, dynamic> json) {
    return TestEntity(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      value: json['value'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'])
          : null,
      isDeleted: json['is_deleted'] ?? false,
      version: json['version'] ?? 1,
      metadata: json['metadata'],
    );
  }

  @override
  String get tableName => 'test_entities';

  @override
  List<Object?> get props => [...super.props, name, value];

  @override
  String toString() {
    return 'TestEntity(id: $id, name: $name, value: $value, createdAt: $createdAt, updatedAt: $updatedAt, syncedAt: $syncedAt, isDeleted: $isDeleted, version: $version)';
  }
}
