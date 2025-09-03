import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_offline_sync/src/sync/sync_engine.dart';
import 'package:flutter_offline_sync/src/database/offline_database.dart';
import 'package:flutter_offline_sync/src/network/network_manager.dart';

void main() {
  group('SyncEngine', () {
    late SyncEngine syncEngine;
    late OfflineDatabase database;
    late NetworkManager networkManager;
    setUp(() {
      database = OfflineDatabase();
      networkManager = NetworkManager();
      syncEngine = SyncEngine(database, networkManager);
    });

    group('initialization', () {
      test('should initialize with dependencies', () {
        // Act & Assert
        expect(syncEngine, isNotNull);
      });
    });

    group('sync operations', () {
      test('should handle sync operations', () {
        // Act & Assert
        expect(() => syncEngine.syncAll(), returnsNormally);
      });
    });

    group('status operations', () {
      test('should get sync status', () {
        // Act & Assert
        expect(syncEngine.status, isNotNull);
      });

      test('should have status stream', () {
        // Act & Assert
        expect(syncEngine.statusStream, isNotNull);
      });
    });

    group('configuration', () {
      test('should set auto sync interval', () {
        // Act & Assert
        expect(
          () => syncEngine.setAutoSyncInterval(Duration(minutes: 10)),
          returnsNormally,
        );
      });

      test('should set max retries', () {
        // Act & Assert
        expect(() => syncEngine.setMaxRetries(5), returnsNormally);
      });

      test('should enable auto sync', () {
        // Act & Assert
        expect(() => syncEngine.setAutoSyncEnabled(true), returnsNormally);
      });
    });

    group('disposal', () {
      test('should dispose properly', () {
        // Act & Assert
        expect(() => syncEngine.dispose(), returnsNormally);
      });
    });
  });
}
