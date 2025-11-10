import 'dart:async';

/// Platform-agnostic database interface.
abstract class PlatformDatabase {
  Future<void> initialize();
  Future<void> close();
  Future<void> createTable(String tableName, String sql);
  Future<int> insert(String table, Map<String, dynamic> values);
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  });
  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs});
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  });
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]);
  Future<int> rawExecute(String sql, [List<dynamic>? arguments]);
  Future<T> transaction<T>(
    Future<T> Function(dynamic txn) action, {
    bool? exclusive,
  });
}
