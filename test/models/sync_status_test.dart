import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_offline_sync/flutter_offline_sync.dart';

void main() {
  group('SyncStatus', () {
    late DateTime now;
    late SyncStatus status;

    setUp(() {
      now = DateTime.now();
      status = SyncStatus(
        isOnline: true,
        isSyncing: false,
        lastSyncAt: now,
        pendingCount: 5,
        failedCount: 2,
        lastError: 'Test error',
        syncProgress: 0.5,
        autoSyncEnabled: true,
        syncMode: SyncMode.automatic,
        nextSyncAt: now.add(const Duration(minutes: 5)),
      );
    });

    test('should create status with all fields', () {
      expect(status.isOnline, true);
      expect(status.isSyncing, false);
      expect(status.lastSyncAt, now);
      expect(status.pendingCount, 5);
      expect(status.failedCount, 2);
      expect(status.lastError, 'Test error');
      expect(status.syncProgress, 0.5);
      expect(status.autoSyncEnabled, true);
      expect(status.syncMode, SyncMode.automatic);
      expect(status.nextSyncAt, now.add(const Duration(minutes: 5)));
    });

    test('should create status with default values', () {
      const defaultStatus = SyncStatus(isOnline: false, isSyncing: true);

      expect(defaultStatus.pendingCount, 0);
      expect(defaultStatus.failedCount, 0);
      expect(defaultStatus.syncProgress, 0.0);
      expect(defaultStatus.autoSyncEnabled, true);
      expect(defaultStatus.syncMode, SyncMode.automatic);
    });

    test('should copy with new values', () {
      final newStatus = status.copyWith(
        isOnline: false,
        isSyncing: true,
        pendingCount: 10,
        syncProgress: 0.8,
      );

      expect(newStatus.isOnline, false);
      expect(newStatus.isSyncing, true);
      expect(newStatus.pendingCount, 10);
      expect(newStatus.syncProgress, 0.8);
      expect(newStatus.lastSyncAt, status.lastSyncAt);
      expect(newStatus.failedCount, status.failedCount);
    });

    test('should convert to JSON', () {
      final json = status.toJson();

      expect(json['isOnline'], true);
      expect(json['isSyncing'], false);
      expect(json['last_sync_at'], now.millisecondsSinceEpoch);
      expect(json['pending_count'], 5);
      expect(json['failed_count'], 2);
      expect(json['last_error'], 'Test error');
      expect(json['sync_progress'], 0.5);
      expect(json['auto_sync_enabled'], true);
      expect(json['sync_mode'], 'automatic');
      expect(
        json['next_sync_at'],
        now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      );
    });

    test('should create from JSON', () {
      final json = {
        'isOnline': false,
        'isSyncing': true,
        'last_sync_at': now.millisecondsSinceEpoch,
        'pending_count': 3,
        'failed_count': 1,
        'last_error': 'JSON error',
        'sync_progress': 0.3,
        'auto_sync_enabled': false,
        'sync_mode': 'manual',
        'next_sync_at': now
            .add(const Duration(minutes: 10))
            .millisecondsSinceEpoch,
      };

      final statusFromJson = SyncStatus.fromJson(json);

      expect(statusFromJson.isOnline, false);
      expect(statusFromJson.isSyncing, true);
      expect(
        statusFromJson.lastSyncAt?.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
      expect(statusFromJson.pendingCount, 3);
      expect(statusFromJson.failedCount, 1);
      expect(statusFromJson.lastError, 'JSON error');
      expect(statusFromJson.syncProgress, 0.3);
      expect(statusFromJson.autoSyncEnabled, false);
      expect(statusFromJson.syncMode, SyncMode.manual);
      expect(
        statusFromJson.nextSyncAt?.millisecondsSinceEpoch,
        now.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      );
    });

    test('should detect pending items', () {
      expect(status.hasPendingItems, true);

      final noPendingStatus = status.copyWith(pendingCount: 0);
      expect(noPendingStatus.hasPendingItems, false);
    });

    test('should detect failed syncs', () {
      expect(status.hasFailedSyncs, true);

      final noFailedStatus = status.copyWith(failedCount: 0);
      expect(noFailedStatus.hasFailedSyncs, false);
    });

    test('should determine if healthy', () {
      expect(status.isHealthy, false); // Has failed syncs and error

      final healthyStatus = status.copyWith(failedCount: 0, lastError: null);
      expect(healthyStatus.isHealthy, true);
    });

    test('should calculate time since last sync', () {
      final timeSince = status.timeSinceLastSync;
      expect(timeSince, isNotNull);
      expect(timeSince!.inSeconds, greaterThanOrEqualTo(0));

      final noSyncStatus = status.copyWith(lastSyncAt: null);
      expect(noSyncStatus.timeSinceLastSync, isNull);
    });

    test('should detect recent sync', () {
      final recentStatus = status.copyWith(
        lastSyncAt: DateTime.now().subtract(const Duration(minutes: 30)),
      );
      expect(recentStatus.isRecentlySynced, true);

      final oldStatus = status.copyWith(
        lastSyncAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(oldStatus.isRecentlySynced, false);
    });

    test('should implement equality correctly', () {
      final status1 = SyncStatus(
        isOnline: true,
        isSyncing: false,
        lastSyncAt: now,
        pendingCount: 5,
      );

      final status2 = SyncStatus(
        isOnline: true,
        isSyncing: false,
        lastSyncAt: now,
        pendingCount: 5,
      );

      final status3 = SyncStatus(
        isOnline: false,
        isSyncing: false,
        lastSyncAt: now,
        pendingCount: 5,
      );

      expect(status1, equals(status2));
      expect(status1, isNot(equals(status3)));
    });

    test('should include all fields in props', () {
      final props = status.props;
      expect(props, contains(true));
      expect(props, contains(false));
      expect(props, contains(now));
      expect(props, contains(5));
      expect(props, contains(2));
      expect(props, contains('Test error'));
      expect(props, contains(0.5));
      expect(props, contains(true));
      expect(props, contains(SyncMode.automatic));
    });

    test('should have meaningful toString', () {
      final string = status.toString();
      expect(string, contains('true'));
      expect(string, contains('false'));
      expect(string, contains('5'));
      expect(string, contains('2'));
    });
  });

  group('SyncMode', () {
    test('should have correct string values', () {
      expect(SyncMode.manual.value, 'manual');
      expect(SyncMode.automatic.value, 'automatic');
      expect(SyncMode.scheduled.value, 'scheduled');
    });

    test('should create from string', () {
      expect(SyncModeExtension.fromString('manual'), SyncMode.manual);
      expect(SyncModeExtension.fromString('automatic'), SyncMode.automatic);
      expect(SyncModeExtension.fromString('scheduled'), SyncMode.scheduled);
    });

    test('should throw for invalid string', () {
      expect(
        () => SyncModeExtension.fromString('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle case insensitive strings', () {
      expect(SyncModeExtension.fromString('MANUAL'), SyncMode.manual);
      expect(SyncModeExtension.fromString('Automatic'), SyncMode.automatic);
      expect(SyncModeExtension.fromString('SCHEDULED'), SyncMode.scheduled);
    });
  });
}
