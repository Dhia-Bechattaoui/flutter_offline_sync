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

  @override
  void initState() {
    super.initState();
    _loadTodos();
    _listenToSyncStatus();
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

      if (mounted) {
        setState(() {
          _todos = todos;
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
    try {
      await OfflineSyncManager.instance.sync();
      _showSuccessSnackBar('Sync completed');
    } catch (e) {
      _showErrorSnackBar('Sync failed: $e');
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
          IconButton(
            icon: Icon(_syncStatus.isOnline ? Icons.wifi : Icons.wifi_off),
            onPressed: null,
            tooltip: _syncStatus.isOnline ? 'Online' : 'Offline',
          ),
          IconButton(
            icon: _syncStatus.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _syncStatus.isSyncing ? null : _syncTodos,
            tooltip: 'Sync',
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
                  Text(
                    'Sync Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _syncStatus.isOnline ? Icons.wifi : Icons.wifi_off,
                        color: _syncStatus.isOnline ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(_syncStatus.isOnline ? 'Online' : 'Offline'),
                      const Spacer(),
                      if (_syncStatus.isSyncing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  if (_syncStatus.pendingCount > 0)
                    Text('Pending: ${_syncStatus.pendingCount}'),
                  if (_syncStatus.lastSyncAt != null)
                    Text(
                      'Last sync: ${_formatDateTime(_syncStatus.lastSyncAt!)}',
                    ),
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
                          title: Text(
                            todo.title,
                            style: TextStyle(
                              decoration: todo.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (todo.description.isNotEmpty)
                                Text(todo.description),
                              const SizedBox(height: 4),
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
