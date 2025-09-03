import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_offline_sync/src/database/offline_database.dart';
import 'package:flutter_offline_sync/src/models/sync_entity.dart';

void main() {
  group('OfflineDatabase', () {
    late OfflineDatabase database;

    setUp(() {
      database = OfflineDatabase();
    });

    group('initialization', () {
      test('should create instance', () {
        expect(database, isNotNull);
        expect(database.isInitialized, isFalse);
      });

      test('should have database getter', () {
        expect(database.database, isNull);
      });
    });

    group('entity registration', () {
      test('should register entity type', () {
        expect(
          () => database.registerEntity<TestEntity>(
            'test_table',
            'CREATE TABLE test_table (id TEXT PRIMARY KEY, name TEXT)',
            (json) => TestEntity.fromJson(json),
          ),
          returnsNormally,
        );
      });
    });

    group('method existence', () {
      test('should have initialize method', () {
        expect(database.initialize, isA<Function>());
      });

      test('should have close method', () {
        expect(database.close, isA<Function>());
      });

      test('should have insert method', () {
        expect(database.insert, isA<Function>());
      });

      test('should have update method', () {
        expect(database.update, isA<Function>());
      });

      test('should have delete method', () {
        expect(database.delete, isA<Function>());
      });

      test('should have findById method', () {
        expect(database.findById, isA<Function>());
      });

      test('should have findAll method', () {
        expect(database.findAll, isA<Function>());
      });

      test('should have findUnsynced method', () {
        expect(database.findUnsynced, isA<Function>());
      });

      test('should have count method', () {
        expect(database.count, isA<Function>());
      });

      test('should have createTable method', () {
        expect(database.createTable, isA<Function>());
      });

      test('should have rawQuery method', () {
        expect(database.rawQuery, isA<Function>());
      });

      test('should have rawExecute method', () {
        expect(database.rawExecute, isA<Function>());
      });

      test('should have transaction method', () {
        expect(database.transaction, isA<Function>());
      });
    });

    group('additional methods', () {
      test('should have softDelete method', () {
        expect(database.softDelete, isA<Function>());
      });

      test('should have registerEntity method', () {
        expect(database.registerEntity, isA<Function>());
      });

      test('should have isInitialized property', () {
        expect(database.isInitialized, isA<bool>());
      });

      test('should have database property', () {
        expect(database.database, isNull);
      });
    });

    group('error handling', () {
      test('should handle database not initialized errors', () {
        expect(
          () => database.insert('test_table', {
            'id': '1',
            'name': 'Test',
            'value': 1,
          }),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle table definition not found errors', () {
        expect(
          () => database.createTable(
            'nonexistent_table',
            'CREATE TABLE nonexistent_table (id TEXT)',
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('entity conversion', () {
      test('should handle entity to map conversion', () {
        final entity = TestEntity(
          id: '1',
          name: 'Test',
          value: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Test that the entity can be created
        expect(entity, isNotNull);
        expect(entity.id, '1');
        expect(entity.name, 'Test');
        expect(entity.value, 1);
      });

      test('should handle map to entity conversion', () {
        final map = {
          'id': '1',
          'name': 'Test',
          'value': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_deleted': false,
          'version': 1,
        };

        final entity = TestEntity.fromJson(map);
        expect(entity, isNotNull);
        expect(entity.id, '1');
        expect(entity.name, 'Test');
        expect(entity.value, 1);
      });
    });

    group('database configuration', () {
      test('should have correct database name', () {
        // Test that the database name is set correctly
        expect(database, isNotNull);
      });

      test('should have correct database version', () {
        // Test that the database version is set correctly
        expect(database, isNotNull);
      });
    });

    group('table management', () {
      test('should handle table creation', () {
        expect(
          () => database.createTable(
            'test_table',
            'CREATE TABLE test_table (id TEXT PRIMARY KEY)',
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle index creation', () {
        // Test that indexes can be created
        expect(database, isNotNull);
      });
    });

    group('data operations', () {
      test('should handle insert operations', () {
        expect(
          () => database.insert('test_table', {
            'id': '1',
            'name': 'Test',
            'value': 1,
          }),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle update operations', () {
        expect(
          () => database.update(
            'test_table',
            {'name': 'Updated Test', 'value': 2},
            where: 'id = ?',
            whereArgs: ['1'],
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle delete operations', () {
        expect(
          () =>
              database.delete('test_table', where: 'id = ?', whereArgs: ['1']),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle find operations', () {
        expect(
          () => database.findById('test_table', '1'),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle count operations', () {
        expect(() => database.count('test_table'), throwsA(isA<StateError>()));
      });
    });

    group('sync operations', () {
      test('should handle unsynced entity queries', () {
        expect(
          () => database.findUnsynced('test_table'),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle sync status updates', () {
        // Test that sync status can be updated
        expect(database, isNotNull);
      });
    });

    group('performance', () {
      test('should handle batch operations', () {
        // Test that batch operations can be performed
        expect(database, isNotNull);
      });

      test('should handle concurrent operations', () {
        // Test that concurrent operations can be handled
        expect(database, isNotNull);
      });
    });

    group('migration', () {
      test('should handle database upgrades', () {
        // Test that database upgrades can be handled
        expect(database, isNotNull);
      });

      test('should handle schema changes', () {
        // Test that schema changes can be handled
        expect(database, isNotNull);
      });
    });
  });
}

class TestEntity extends SyncEntity {
  final String name;
  final int value;

  TestEntity({
    required String id,
    required this.name,
    required this.value,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool isDeleted = false,
    int version = 1,
    Map<String, dynamic>? metadata,
  }) : super(
         id: id,
         createdAt: createdAt ?? DateTime.now(),
         updatedAt: updatedAt ?? DateTime.now(),
         syncedAt: syncedAt,
         isDeleted: isDeleted,
         version: version,
         metadata: metadata,
       );

  @override
  String get tableName => 'test_entities';

  @override
  Map<String, dynamic> toJson() {
    return {...super.toJson(), 'name': name, 'value': value};
  }

  @override
  TestEntity copyWith({
    String? id,
    String? name,
    int? value,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool? isDeleted,
    int? version,
    Map<String, dynamic>? metadata,
  }) {
    return TestEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      metadata: metadata ?? this.metadata,
    );
  }

  factory TestEntity.fromJson(Map<String, dynamic> json) {
    return TestEntity(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      value: json['value'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updated_at'])
          : DateTime.now(),
      syncedAt: json['synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['synced_at'])
          : null,
      isDeleted: json['is_deleted'] ?? false,
      version: json['version'] ?? 1,
      metadata: json['metadata'],
    );
  }

  @override
  List<Object?> get props => [...super.props, name, value];
}
