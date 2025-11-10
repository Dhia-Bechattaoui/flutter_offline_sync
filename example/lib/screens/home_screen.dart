import 'package:flutter/material.dart';
import 'package:flutter_offline_sync/flutter_offline_sync.dart';
import '../models/todo_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<TodoItem> _todos = [];
  bool _isLoading = false;
  SyncStatus _syncStatus = const SyncStatus(isOnline: false, isSyncing: false);
  bool _forceOffline = false;
  Map<String, String?> _syncStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadTodos();
    _listenToSyncStatus();
    _listenToConnectivity();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _listenToSyncStatus() {
    OfflineSyncManager.instance.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
        });
      }
    });
  }

  void _listenToConnectivity() {
    // Listen to connectivity changes - auto-sync is handled by the package
    OfflineSyncManager.instance.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          // Status will be updated via sync status stream
        });
        
        // Show notification when coming back online only if auto-sync is enabled
        // (package handles auto-sync, we just show notification)
        if (isOnline && _syncStatus.autoSyncEnabled && _syncStatus.pendingCount > 0) {
          _showSuccessSnackBar(
            'Back online! Auto-syncing ${_syncStatus.pendingCount} items...',
          );
        } else if (isOnline && !_syncStatus.autoSyncEnabled && _syncStatus.pendingCount > 0) {
          _showSuccessSnackBar(
            'Back online! ${_syncStatus.pendingCount} items pending. Use sync button to sync manually.',
          );
        }
      }
    });
  }

  void _toggleAutoSync() {
    final newValue = !_syncStatus.autoSyncEnabled;
    // Only update the setting, don't trigger any connectivity checks or syncs
    OfflineSyncManager.instance.setAutoSyncEnabled(newValue);
    _showSuccessSnackBar(
      'Auto-sync ${newValue ? 'enabled' : 'disabled'}',
    );
  }

  Future<String?> _getSyncStatus(String todoId) async {
    try {
      final row = await OfflineSyncManager.instance.database.findById('todos', todoId);
      return row?['sync_status'] as String?;
    } catch (e) {
      return null;
    }
  }

  Widget _buildSyncStatusIcon(String? syncStatus) {
    if (syncStatus == null) return const SizedBox.shrink();
    
    switch (syncStatus) {
      case 'synced':
        return const Icon(
          Icons.cloud_done,
          color: Colors.green,
          size: 16,
        );
      case 'pending':
        return const Icon(
          Icons.cloud_upload,
          color: Colors.orange,
          size: 16,
        );
      case 'queued':
        return const Icon(
          Icons.cloud_queue,
          color: Colors.blue,
          size: 16,
        );
      case 'error':
        return const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 16,
        );
      case 'conflict':
        return const Icon(
          Icons.warning_amber,
          color: Colors.amber,
          size: 16,
        );
      default:
        return const Icon(
          Icons.cloud_off,
          color: Colors.grey,
          size: 16,
        );
    }
  }

  String _getSyncStatusLabel(String? syncStatus) {
    if (syncStatus == null) return 'Unknown';
    
    switch (syncStatus) {
      case 'synced':
        return 'Synced';
      case 'pending':
        return 'Pending';
      case 'queued':
        return 'Queued';
      case 'error':
        return 'Error';
      case 'conflict':
        return 'Conflict';
      default:
        return 'Unknown';
    }
  }

  Future<void> _loadTodos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final todos = await OfflineSyncManager.instance.findAll<TodoItem>(
        'todos',
        orderBy: 'updated_at',
        ascending: false,
      );

      // Load sync statuses for all todos
      final Map<String, String?> statuses = {};
      for (final todo in todos) {
        statuses[todo.id] = await _getSyncStatus(todo.id);
      }

      if (mounted) {
        setState(() {
          _todos = todos;
          _syncStatuses = statuses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load todos: $e');
      }
    }
  }

  Future<void> _addTodo() async {
    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a title');
      return;
    }

    try {
      final todo = TodoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        isCompleted: false,
        userId: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await OfflineSyncManager.instance.save(todo);

      _titleController.clear();
      _descriptionController.clear();
      _loadTodos();

      _showSuccessSnackBar('Todo added successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to add todo: $e');
    }
  }

  Future<void> _toggleTodo(TodoItem todo) async {
    try {
      final updatedTodo = todo.copyWith(
        isCompleted: !todo.isCompleted,
        updatedAt: DateTime.now(),
      );

      await OfflineSyncManager.instance.update(updatedTodo);
      _loadTodos();
    } catch (e) {
      _showErrorSnackBar('Failed to update todo: $e');
    }
  }

  Future<void> _deleteTodo(TodoItem todo) async {
    try {
      await OfflineSyncManager.instance.delete(todo.id, 'todos');
      _loadTodos();
      _showSuccessSnackBar('Todo deleted successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to delete todo: $e');
    }
  }

  Future<void> _syncTodos() async {
    // Check if we're forcing offline mode
    if (_forceOffline) {
      _showErrorSnackBar('Cannot sync while in offline mode');
      return;
    }

    if (!_syncStatus.isOnline) {
      _showErrorSnackBar('Cannot sync while offline');
      return;
    }

    try {
      await OfflineSyncManager.instance.sync();
      await _loadTodos(); // Refresh the list after sync
      _showSuccessSnackBar('Sync completed');
    } catch (e) {
      _showErrorSnackBar('Sync failed: $e');
    }
  }

  Future<void> _toggleOnlineOffline() async {
    setState(() {
      _forceOffline = !_forceOffline;
    });
    
    if (_forceOffline) {
      _showSuccessSnackBar('Forced offline mode enabled');
    } else {
      // Going from forced offline to online
      _showSuccessSnackBar('Online mode enabled');
      
      // Wait a moment for state to update
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Check if we're actually online
      final isOnline = await OfflineSyncManager.instance.testConnection();
      if (!isOnline) {
        _showErrorSnackBar('No internet connection available');
        return;
      }
      
      // Check auto-sync setting and pending count
      final currentStatus = OfflineSyncManager.instance.status;
      if (currentStatus.autoSyncEnabled) {
        // Calculate pending count
        final pendingCount = await _calculatePendingCount();
        if (pendingCount > 0) {
          _showSuccessSnackBar('Going online and auto-syncing $pendingCount items...');
          await _syncTodos();
        } else {
          _showSuccessSnackBar('Online! No pending items to sync.');
        }
      } else {
        final pendingCount = await _calculatePendingCount();
        if (pendingCount > 0) {
          _showSuccessSnackBar('Online! $pendingCount items pending. Use sync button to sync manually.');
        } else {
          _showSuccessSnackBar('Online!');
        }
      }
    }
  }

  Future<int> _calculatePendingCount() async {
    try {
      return await OfflineSyncManager.instance.database.count(
        'todos',
        where: 'sync_status != ?',
        whereArgs: ['synced'],
      );
    } catch (e) {
      return 0;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Offline Sync Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Online/Offline Status Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    (_syncStatus.isOnline && !_forceOffline) ? Icons.wifi : Icons.wifi_off,
                    color: (_syncStatus.isOnline && !_forceOffline) ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (_syncStatus.isOnline && !_forceOffline) ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: (_syncStatus.isOnline && !_forceOffline) ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Sync Button (only shown when online and not forcing offline)
          if (_syncStatus.isOnline && !_forceOffline)
            IconButton(
              icon: _syncStatus.isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              onPressed: _syncStatus.isSyncing ? null : _syncTodos,
              tooltip: 'Sync Now',
            ),
        ],
      ),
      body: Column(
        children: [
          // Sync Status Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sync Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_syncStatus.isSyncing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            (_syncStatus.isOnline && !_forceOffline) ? Icons.wifi : Icons.wifi_off,
                            color: (_syncStatus.isOnline && !_forceOffline) ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (_syncStatus.isOnline && !_forceOffline) ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (_syncStatus.isOnline && !_forceOffline) ? Colors.green : Colors.red,
                            ),
                          ),
                          if (_forceOffline && _syncStatus.isOnline)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                '(Forced)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Switch(
                        value: !_forceOffline,
                        onChanged: (_) => _toggleOnlineOffline(),
                      ),
                    ],
                  ),
                  if (_syncStatus.pendingCount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.pending_actions, size: 16),
                        const SizedBox(width: 8),
                        Text('Pending items: ${_syncStatus.pendingCount}'),
                      ],
                    ),
                  ],
                  if (_syncStatus.lastSyncAt != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Last sync: ${_formatDateTime(_syncStatus.lastSyncAt!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sync, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Auto-sync',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Switch(
                        value: _syncStatus.autoSyncEnabled,
                        onChanged: (_) => _toggleAutoSync(),
                      ),
                    ],
                  ),
                  if (_syncStatus.isOnline && !_forceOffline) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _syncStatus.isSyncing ? null : _syncTodos,
                        icon: _syncStatus.isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sync),
                        label: Text(
                          _syncStatus.isSyncing
                              ? 'Syncing...'
                              : _syncStatus.pendingCount > 0
                                  ? 'Sync Now (${_syncStatus.pendingCount} pending)'
                                  : 'Sync Now',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Add Todo Form
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Todo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addTodo,
                      child: const Text('Add Todo'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Todos List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _todos.isEmpty
                ? const Center(child: Text('No todos yet. Add one above!'))
                : ListView.builder(
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final todo = _todos[index];
                      final syncStatus = _syncStatuses[todo.id];
                      final isSynced = syncStatus == 'synced';
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: todo.isCompleted,
                            onChanged: (_) => _toggleTodo(todo),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  todo.title,
                                  style: TextStyle(
                                    decoration: todo.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildSyncStatusIcon(syncStatus),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (todo.description.isNotEmpty)
                                Text(todo.description),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Status: ',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(
                                    _getSyncStatusLabel(syncStatus),
                                    style: TextStyle(
                                      color: isSynced ? Colors.green : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Updated: ${_formatDateTime(todo.updatedAt)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (todo.syncedAt != null)
                                Text(
                                  'Synced: ${_formatDateTime(todo.syncedAt!)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteTodo(todo),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
