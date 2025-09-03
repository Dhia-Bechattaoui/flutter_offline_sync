import 'package:flutter_offline_sync/flutter_offline_sync.dart';

/// A simple TodoItem model that extends SyncEntity.
class TodoItem extends SyncEntity {
  final String title;
  final String description;
  final bool isCompleted;
  final int userId;

  const TodoItem({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.userId,
    super.syncedAt,
    super.isDeleted,
    super.version,
    super.metadata,
  });

  @override
  TodoItem copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool? isDeleted,
    int? version,
    Map<String, dynamic>? metadata,
    String? title,
    String? description,
    bool? isCompleted,
    int? userId,
  }) {
    return TodoItem(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      metadata: metadata ?? this.metadata,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      userId: userId ?? this.userId,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': isCompleted,
      'userId': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'is_deleted': isDeleted,
      'version': version,
      'metadata': metadata,
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      isCompleted: json['completed'] ?? false,
      userId: json['userId'] ?? 0,
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
  String get tableName => 'todos';

  @override
  List<Object?> get props => [
    ...super.props,
    title,
    description,
    isCompleted,
    userId,
  ];

  @override
  String toString() {
    return 'TodoItem(id: $id, title: $title, completed: $isCompleted)';
  }
}
