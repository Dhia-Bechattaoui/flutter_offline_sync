/// A comprehensive Flutter package for offline functionality with automatic sync capabilities.
///
/// This package provides:
/// - Offline data storage with SQLite
/// - Automatic network detection and sync
/// - Conflict resolution strategies
/// - Cross-platform support (iOS, Android, Web, Windows, macOS, Linux)
/// - WASM compatibility
/// - Background sync capabilities
/// - Comprehensive error handling
library flutter_offline_sync;

export 'src/offline_sync_manager.dart';
export 'src/models/sync_entity.dart';
export 'src/models/sync_status.dart';
export 'src/models/conflict_resolution.dart';
export 'src/database/offline_database.dart';
export 'src/network/network_manager.dart';
export 'src/sync/sync_engine.dart';
export 'src/exceptions/sync_exceptions.dart';
export 'src/utils/logger.dart';
