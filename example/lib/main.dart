import 'package:flutter/material.dart';
import 'package:flutter_offline_sync/flutter_offline_sync.dart';
import 'models/todo_item.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the offline sync manager
  await OfflineSyncManager.instance.initialize(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    autoSyncEnabled: true,
    autoSyncInterval: const Duration(minutes: 2),
  );

  // Register the TodoItem entity
  OfflineSyncManager.instance.registerEntity(
    'todos',
    '/todos',
    (json) => TodoItem.fromJson(json),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Offline Sync Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
