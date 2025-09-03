import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_offline_sync/flutter_offline_sync.dart';
import 'models/test_entity.dart';

void main() {
  group('OfflineSyncManager', () {
    late OfflineSyncManager manager;

    setUp(() {
      manager = OfflineSyncManager.instance;
    });

    group('initialization', () {
      test('should have instance', () {
        expect(manager, isNotNull);
      });

      test('should have initialize method', () {
        expect(manager.initialize, isA<Function>());
      });
    });

    group('entity management', () {
      test('should have save method', () {
        expect(manager.save, isA<Function>());
      });

      test('should have update method', () {
        expect(manager.update, isA<Function>());
      });

      test('should have delete method', () {
        expect(manager.delete, isA<Function>());
      });

      test('should have findById method', () {
        expect(manager.findById, isA<Function>());
      });

      test('should have findAll method', () {
        expect(manager.findAll, isA<Function>());
      });
    });

    group('sync operations', () {
      test('should have sync method', () {
        expect(manager.sync, isA<Function>());
      });

      test('should have statusStream getter', () {
        expect(manager.statusStream, isA<Stream<SyncStatus>>());
      });

      test('should have isOnline getter', () {
        expect(manager.isOnline, isA<bool>());
      });
    });

    group('error handling', () {
      test('should handle operations when not initialized', () {
        expect(
          () => manager.save(
            TestEntity(
              id: '1',
              name: 'Test',
              value: 1,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
          returnsNormally,
        );
      });
    });
  });
}
