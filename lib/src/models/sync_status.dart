import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'sync_status.g.dart';

/// Special value to indicate that a field should be set to null
const Object _nullValue = Object();

/// Converts a timestamp (milliseconds since epoch) to DateTime
DateTime? _dateTimeFromTimestamp(dynamic timestamp) {
  if (timestamp == null) return null;
  if (timestamp is int) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
  if (timestamp is String) {
    return DateTime.parse(timestamp);
  }
  return null;
}

/// Converts a DateTime to timestamp (milliseconds since epoch)
int? _dateTimeToTimestamp(DateTime? dateTime) {
  return dateTime?.millisecondsSinceEpoch;
}

/// Represents the current synchronization status of the offline sync manager.
@JsonSerializable()
class SyncStatus extends Equatable {
  /// Whether the device is currently connected to the internet
  final bool isOnline;

  /// Whether a sync operation is currently in progress
  final bool isSyncing;

  /// The timestamp of the last successful sync
  @JsonKey(
    name: 'last_sync_at',
    fromJson: _dateTimeFromTimestamp,
    toJson: _dateTimeToTimestamp,
  )
  final DateTime? lastSyncAt;

  /// The number of pending items waiting to be synced
  @JsonKey(name: 'pending_count')
  final int pendingCount;

  /// The number of failed sync attempts
  @JsonKey(name: 'failed_count')
  final int failedCount;

  /// The last error that occurred during sync
  @JsonKey(name: 'last_error')
  final String? lastError;

  /// The current sync progress (0.0 to 1.0)
  @JsonKey(name: 'sync_progress')
  final double syncProgress;

  /// Whether the sync is in auto mode (automatic background sync)
  @JsonKey(name: 'auto_sync_enabled')
  final bool autoSyncEnabled;

  /// The sync mode (manual, automatic, or scheduled)
  @JsonKey(name: 'sync_mode')
  final SyncMode syncMode;

  /// The next scheduled sync time (if in scheduled mode)
  @JsonKey(
    name: 'next_sync_at',
    fromJson: _dateTimeFromTimestamp,
    toJson: _dateTimeToTimestamp,
  )
  final DateTime? nextSyncAt;

  const SyncStatus({
    required this.isOnline,
    required this.isSyncing,
    this.lastSyncAt,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastError,
    this.syncProgress = 0.0,
    this.autoSyncEnabled = true,
    this.syncMode = SyncMode.automatic,
    this.nextSyncAt,
  });

  /// Creates a copy of this status with the given fields replaced with new values.
  SyncStatus copyWith({
    bool? isOnline,
    bool? isSyncing,
    Object? lastSyncAt = _nullValue,
    int? pendingCount,
    int? failedCount,
    Object? lastError = _nullValue,
    double? syncProgress,
    bool? autoSyncEnabled,
    SyncMode? syncMode,
    Object? nextSyncAt = _nullValue,
  }) {
    return SyncStatus(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt == _nullValue
          ? this.lastSyncAt
          : lastSyncAt as DateTime?,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      lastError: lastError == _nullValue
          ? this.lastError
          : lastError as String?,
      syncProgress: syncProgress ?? this.syncProgress,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      syncMode: syncMode ?? this.syncMode,
      nextSyncAt: nextSyncAt == _nullValue
          ? this.nextSyncAt
          : nextSyncAt as DateTime?,
    );
  }

  /// Converts the status to a JSON map.
  Map<String, dynamic> toJson() => _$SyncStatusToJson(this);

  /// Creates a status from a JSON map.
  factory SyncStatus.fromJson(Map<String, dynamic> json) =>
      _$SyncStatusFromJson(json);

  /// Returns true if there are pending items to sync.
  bool get hasPendingItems => pendingCount > 0;

  /// Returns true if there are failed sync attempts.
  bool get hasFailedSyncs => failedCount > 0;

  /// Returns true if the sync is healthy (no errors, recent sync).
  bool get isHealthy => !hasFailedSyncs && lastError == null;

  /// Returns the time since the last successful sync.
  Duration? get timeSinceLastSync {
    if (lastSyncAt == null) return null;
    return DateTime.now().difference(lastSyncAt!);
  }

  /// Returns true if the last sync was recent (within the last hour).
  bool get isRecentlySynced {
    final timeSince = timeSinceLastSync;
    return timeSince != null && timeSince.inHours < 1;
  }

  @override
  List<Object?> get props => [
    isOnline,
    isSyncing,
    lastSyncAt,
    pendingCount,
    failedCount,
    lastError,
    syncProgress,
    autoSyncEnabled,
    syncMode,
    nextSyncAt,
  ];

  @override
  String toString() {
    return 'SyncStatus(isOnline: $isOnline, isSyncing: $isSyncing, '
        'lastSyncAt: $lastSyncAt, pendingCount: $pendingCount, '
        'failedCount: $failedCount, lastError: $lastError, '
        'syncProgress: $syncProgress, autoSyncEnabled: $autoSyncEnabled, '
        'syncMode: $syncMode, nextSyncAt: $nextSyncAt)';
  }
}

/// Enum representing different sync modes.
enum SyncMode {
  /// Manual sync only - user must trigger sync manually
  manual,

  /// Automatic sync - syncs automatically when online
  automatic,

  /// Scheduled sync - syncs at specific intervals
  scheduled,
}

/// Extension methods for SyncMode enum.
extension SyncModeExtension on SyncMode {
  /// Returns the string representation of the sync mode.
  String get value {
    switch (this) {
      case SyncMode.manual:
        return 'manual';
      case SyncMode.automatic:
        return 'automatic';
      case SyncMode.scheduled:
        return 'scheduled';
    }
  }

  /// Creates a SyncMode from its string representation.
  static SyncMode fromString(String value) {
    switch (value.toLowerCase()) {
      case 'manual':
        return SyncMode.manual;
      case 'automatic':
        return SyncMode.automatic;
      case 'scheduled':
        return SyncMode.scheduled;
      default:
        throw ArgumentError('Invalid sync mode: $value');
    }
  }
}
