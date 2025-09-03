import 'package:flutter_test/flutter_test.dart';
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

void main() {
  group('SyncEntity', () {
    late TestEntity entity;
    late DateTime now;

    setUp(() {
      now = DateTime.now();
      entity = TestEntity(
        id: 'test-id',
        createdAt: now,
        updatedAt: now,
        name: 'Test Entity',
        value: 42,
      );
    });

    test('should create entity with required fields', () {
      expect(entity.id, 'test-id');
      expect(entity.name, 'Test Entity');
      expect(entity.value, 42);
      expect(entity.createdAt, now);
      expect(entity.updatedAt, now);
      expect(entity.isDeleted, false);
      expect(entity.version, 1);
    });

    test('should create entity with optional fields', () {
      final syncedAt = DateTime.now().add(const Duration(minutes: 1));
      final metadata = {'key': 'value'};

      final entityWithOptional = TestEntity(
        id: 'test-id-2',
        createdAt: now,
        updatedAt: now,
        name: 'Test Entity 2',
        value: 100,
        syncedAt: syncedAt,
        isDeleted: true,
        version: 2,
        metadata: metadata,
      );

      expect(entityWithOptional.syncedAt, syncedAt);
      expect(entityWithOptional.isDeleted, true);
      expect(entityWithOptional.version, 2);
      expect(entityWithOptional.metadata, metadata);
    });

    test('should copy entity with new values', () {
      final newName = 'Updated Entity';
      final newValue = 99;
      final newUpdatedAt = DateTime.now().add(const Duration(hours: 1));

      final copiedEntity = entity.copyWith(
        name: newName,
        value: newValue,
        updatedAt: newUpdatedAt,
      );

      expect(copiedEntity.id, entity.id);
      expect(copiedEntity.name, newName);
      expect(copiedEntity.value, newValue);
      expect(copiedEntity.updatedAt, newUpdatedAt);
      expect(copiedEntity.createdAt, entity.createdAt);
    });

    test('should convert to JSON', () {
      final json = entity.toJson();

      expect(json['id'], 'test-id');
      expect(json['name'], 'Test Entity');
      expect(json['value'], 42);
      expect(json['is_deleted'], false);
      expect(json['version'], 1);
      expect(json['created_at'], now.toIso8601String());
      expect(json['updated_at'], now.toIso8601String());
    });

    test('should create from JSON', () {
      final json = {
        'id': 'json-id',
        'name': 'JSON Entity',
        'value': 123,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'is_deleted': true,
        'version': 3,
      };

      final entityFromJson = TestEntity.fromJson(json);

      expect(entityFromJson.id, 'json-id');
      expect(entityFromJson.name, 'JSON Entity');
      expect(entityFromJson.value, 123);
      expect(entityFromJson.isDeleted, true);
      expect(entityFromJson.version, 3);
    });

    test('should return correct table name', () {
      expect(entity.tableName, 'test_entities');
    });

    test('should return correct primary key', () {
      expect(entity.primaryKey, 'id');
    });

    test('should return correct indexed fields', () {
      final indexedFields = entity.indexedFields;
      expect(indexedFields, contains('created_at'));
      expect(indexedFields, contains('updated_at'));
      expect(indexedFields, contains('synced_at'));
    });

    test('should return correct unique fields', () {
      final uniqueFields = entity.uniqueFields;
      expect(uniqueFields, contains('id'));
    });

    test('should return correct not null fields', () {
      final notNullFields = entity.notNullFields;
      expect(notNullFields, contains('id'));
      expect(notNullFields, contains('created_at'));
      expect(notNullFields, contains('updated_at'));
      expect(notNullFields, contains('version'));
    });

    test('should return correct column definitions', () {
      final columnDefinitions = entity.columnDefinitions;
      expect(columnDefinitions['id'], 'TEXT PRIMARY KEY');
      expect(columnDefinitions['created_at'], 'INTEGER NOT NULL');
      expect(columnDefinitions['updated_at'], 'INTEGER NOT NULL');
      expect(columnDefinitions['synced_at'], 'INTEGER');
      expect(columnDefinitions['is_deleted'], 'INTEGER NOT NULL DEFAULT 0');
      expect(columnDefinitions['version'], 'INTEGER NOT NULL DEFAULT 1');
      expect(columnDefinitions['metadata'], 'TEXT');
    });

    test('should implement equality correctly', () {
      final entity1 = TestEntity(
        id: 'same-id',
        createdAt: now,
        updatedAt: now,
        name: 'Same Entity',
        value: 42,
      );

      final entity2 = TestEntity(
        id: 'same-id',
        createdAt: now,
        updatedAt: now,
        name: 'Same Entity',
        value: 42,
      );

      final entity3 = TestEntity(
        id: 'different-id',
        createdAt: now,
        updatedAt: now,
        name: 'Same Entity',
        value: 42,
      );

      expect(entity1, equals(entity2));
      expect(entity1, isNot(equals(entity3)));
    });

    test('should include all fields in props', () {
      final props = entity.props;
      expect(props, contains('test-id'));
      expect(props, contains('Test Entity'));
      expect(props, contains(42));
      expect(props, contains(now));
      expect(props, contains(false));
      expect(props, contains(1));
    });

    test('should have meaningful toString', () {
      final string = entity.toString();
      expect(string, contains('test-id'));
      expect(string, contains('Test Entity'));
      expect(string, contains('42'));
    });
  });
}
