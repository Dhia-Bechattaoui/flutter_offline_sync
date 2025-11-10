# Flutter Offline Sync

[![pub package](https://img.shields.io/pub/v/flutter_offline_sync.svg)](https://pub.dev/packages/flutter_offline_sync)
[![pub points](https://img.shields.io/pub/points/flutter_offline_sync?logo=dart)](https://pub.dev/packages/flutter_offline_sync/score)
[![popularity](https://img.shields.io/pub/popularity/flutter_offline_sync?logo=dart)](https://pub.dev/packages/flutter_offline_sync/score)
[![likes](https://img.shields.io/pub/likes/flutter_offline_sync?logo=dart)](https://pub.dev/packages/flutter_offline_sync/score)

A comprehensive Flutter package for offline functionality with automatic sync capabilities across all platforms.

<img src="assets/example.gif" width="300" alt="Example demonstration">

## Features

- 🚀 **Cross-Platform Support**: iOS, Android, Web, Windows, macOS, Linux, and WASM
- 💾 **Offline Storage**: SQLite-based local database with automatic schema management
- 🔄 **Automatic Sync**: Background synchronization with configurable intervals
- 🌐 **Network Detection**: Real-time connectivity monitoring and status updates
- ⚡ **Conflict Resolution**: Multiple strategies for handling data conflicts
- 📱 **Background Sync**: Sync data even when the app is in the background
- 🎯 **High Performance**: Optimized for large datasets with batch processing
- 🛡️ **Type Safety**: Full type safety with Dart's type system
- 📊 **Comprehensive Logging**: Detailed logging for debugging and monitoring
- 🧪 **Well Tested**: >90% test coverage with comprehensive test suite

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_offline_sync: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Initialize the Offline Sync Manager

```dart
import 'package:flutter_offline_sync/flutter_offline_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the offline sync manager
  await OfflineSyncManager.instance.initialize(
    baseUrl: 'https://your-api.com',
    autoSyncEnabled: true,
    autoSyncInterval: const Duration(minutes: 5),
  );
  
  runApp(MyApp());
}
```

### 2. Create Your Data Model

```dart
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

  @override
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
}
```

### 3. Register Your Entity

```dart
// Register the entity for synchronization
OfflineSyncManager.instance.registerEntity(
  'todos',
  '/todos',
  (json) => TodoItem.fromJson(json),
);
```

### 4. Use the Offline Sync Manager

```dart
class TodoService {
  // Save a new todo
  Future<TodoItem> createTodo(String title, String description) async {
    final todo = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      isCompleted: false,
      userId: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return await OfflineSyncManager.instance.save(todo);
  }

  // Get all todos
  Future<List<TodoItem>> getAllTodos() async {
    return await OfflineSyncManager.instance.findAll<TodoItem>(
      'todos',
      orderBy: 'updated_at',
      ascending: false,
    );
  }

  // Update a todo
  Future<TodoItem> updateTodo(TodoItem todo) async {
    return await OfflineSyncManager.instance.update(todo);
  }

  // Delete a todo
  Future<void> deleteTodo(String id) async {
    await OfflineSyncManager.instance.delete(id, 'todos');
  }

  // Manual sync
  Future<void> syncTodos() async {
    await OfflineSyncManager.instance.sync();
  }
}
```

### 5. Monitor Sync Status

```dart
class SyncStatusWidget extends StatefulWidget {
  @override
  _SyncStatusWidgetState createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  SyncStatus _status = const SyncStatus(isOnline: false, isSyncing: false);

  @override
  void initState() {
    super.initState();
    
    // Listen to sync status changes
    OfflineSyncManager.instance.statusStream.listen((status) {
      setState(() {
        _status = status;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sync Status'),
            Row(
              children: [
                Icon(
                  _status.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: _status.isOnline ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(_status.isOnline ? 'Online' : 'Offline'),
                Spacer(),
                if (_status.isSyncing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (_status.pendingCount > 0)
              Text('Pending: ${_status.pendingCount}'),
            if (_status.lastSyncAt != null)
              Text('Last sync: ${_formatDateTime(_status.lastSyncAt!)}'),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
```

## Advanced Usage

### Custom Conflict Resolution

```dart
class CustomConflictResolver implements ConflictResolver {
  @override
  Future<SyncEntity?> resolve(SyncConflict conflict) async {
    // Implement your custom conflict resolution logic
    if (conflict.conflictType == ConflictType.bothModified) {
      // Use the version with the latest timestamp
      if (conflict.localEntity.updatedAt.isAfter(conflict.remoteEntity.updatedAt)) {
        return conflict.localEntity;
      } else {
        return conflict.remoteEntity;
      }
    }
    return null;
  }

  @override
  bool canResolve(ConflictType conflictType) {
    return conflictType == ConflictType.bothModified;
  }

  @override
  int get priority => 10; // Higher priority than default resolver
}

// Register the custom resolver
OfflineSyncManager.instance.registerConflictResolver(
  'custom',
  CustomConflictResolver(),
);
```

### Configuration Options

```dart
await OfflineSyncManager.instance.initialize(
  baseUrl: 'https://your-api.com',
  defaultHeaders: {
    'Authorization': 'Bearer your-token',
    'Content-Type': 'application/json',
  },
  timeout: const Duration(seconds: 30),
  autoSyncEnabled: true,
  autoSyncInterval: const Duration(minutes: 5),
  maxRetries: 3,
  batchSize: 50,
);
```

### Raw Database Queries

```dart
// Execute custom SQL queries
final results = await OfflineSyncManager.instance.rawQuery(
  'SELECT * FROM todos WHERE is_completed = ?',
  [1],
);

// Execute custom SQL commands
await OfflineSyncManager.instance.rawExecute(
  'UPDATE todos SET is_completed = ? WHERE id = ?',
  [1, 'todo-id'],
);
```

### Database Transactions

```dart
await OfflineSyncManager.instance.transaction((txn) async {
  // Perform multiple operations atomically
  await txn.insert('todos', todo1.toJson());
  await txn.insert('todos', todo2.toJson());
  await txn.update('todos', todo3.toJson(), where: 'id = ?', whereArgs: [todo3.id]);
});
```

## Platform Support

This package supports all Flutter platforms:

- ✅ **iOS** - Full support with SQLite
- ✅ **Android** - Full support with SQLite
- ✅ **Web** - Full support with IndexedDB (via sqflite_common_ffi)
- ✅ **Windows** - Full support with SQLite
- ✅ **macOS** - Full support with SQLite
- ✅ **Linux** - Full support with SQLite
- ✅ **WASM** - Full support with WebAssembly

## API Reference

### OfflineSyncManager

The main class for managing offline synchronization.

#### Methods

- `initialize()` - Initialize the offline sync manager
- `registerEntity()` - Register an entity type for synchronization
- `registerConflictResolver()` - Register a custom conflict resolver
- `save()` - Save an entity to the local database
- `update()` - Update an entity in the local database
- `delete()` - Delete an entity from the local database
- `findById()` - Find an entity by ID
- `findAll()` - Find all entities of a type
- `count()` - Count entities in a table
- `sync()` - Trigger manual synchronization
- `rawQuery()` - Execute raw SQL queries
- `rawExecute()` - Execute raw SQL commands
- `transaction()` - Execute database transactions

#### Properties

- `status` - Current sync status
- `statusStream` - Stream of sync status changes
- `isOnline` - Whether the device is online
- `connectivityStream` - Stream of connectivity changes

### SyncEntity

Abstract base class for all entities that can be synced.

#### Required Methods

- `copyWith()` - Create a copy with modified fields
- `toJson()` - Convert to JSON map
- `fromJson()` - Create from JSON map
- `tableName` - Database table name

#### Properties

- `id` - Unique identifier
- `createdAt` - Creation timestamp
- `updatedAt` - Last update timestamp
- `syncedAt` - Last sync timestamp
- `isDeleted` - Soft delete flag
- `version` - Version number for conflict resolution
- `metadata` - Custom metadata

### SyncStatus

Represents the current synchronization status.

#### Properties

- `isOnline` - Whether the device is online
- `isSyncing` - Whether a sync is in progress
- `lastSyncAt` - Timestamp of last successful sync
- `pendingCount` - Number of pending items
- `failedCount` - Number of failed sync attempts
- `lastError` - Last error message
- `syncProgress` - Current sync progress (0.0 to 1.0)
- `autoSyncEnabled` - Whether auto-sync is enabled
- `syncMode` - Current sync mode
- `nextSyncAt` - Next scheduled sync time

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions, please file an issue on the [GitHub repository](https://github.com/Dhia-Bechattaoui/flutter_offline_sync/issues).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes and version history.
