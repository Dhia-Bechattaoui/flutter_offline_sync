import 'dart:async';
import '../utils/logger.dart';

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

/// In-memory database implementation for all platforms.
class InMemoryDatabase implements PlatformDatabase {
  final Logger _logger = Logger('InMemoryDatabase');
  final Map<String, List<Map<String, dynamic>>> _tables = {};
  int _nextId = 1;

  @override
  Future<void> initialize() async {
    _logger.info('Initializing in-memory database');
  }

  @override
  Future<void> close() async {
    _logger.info('Closing in-memory database');
    _tables.clear();
  }

  @override
  Future<void> createTable(String tableName, String sql) async {
    _logger.info('Creating table: $tableName');
    _tables[tableName] = [];
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> values) async {
    _logger.info('Inserting into table: $table');
    final tableData = _tables[table] ?? [];
    final id = _nextId++;
    final row = Map<String, dynamic>.from(values);
    row['id'] = id;
    tableData.add(row);
    _tables[table] = tableData;
    return id;
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    _logger.info('Updating table: $table');
    final tableData = _tables[table] ?? [];
    int updated = 0;

    for (int i = 0; i < tableData.length; i++) {
      final row = tableData[i];
      if (_matchesWhere(row, where, whereArgs)) {
        tableData[i] = {...row, ...values};
        updated++;
      }
    }

    return updated;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    _logger.info('Deleting from table: $table');
    final tableData = _tables[table] ?? [];
    int deleted = 0;

    tableData.removeWhere((row) {
      if (_matchesWhere(row, where, whereArgs)) {
        deleted++;
        return true;
      }
      return false;
    });

    return deleted;
  }

  @override
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
  }) async {
    _logger.info('Querying table: $table');
    var results = _tables[table] ?? [];

    // Apply where clause
    if (where != null) {
      results = results
          .where((row) => _matchesWhere(row, where, whereArgs))
          .toList();
    }

    // Apply column selection
    if (columns != null) {
      results = results.map((row) {
        final filteredRow = <String, dynamic>{};
        for (final column in columns) {
          if (row.containsKey(column)) {
            filteredRow[column] = row[column];
          }
        }
        return filteredRow;
      }).toList();
    }

    // Apply ordering
    if (orderBy != null) {
      results = _applyOrdering(results, orderBy);
    }

    // Apply limit and offset
    if (offset != null && offset > 0) {
      results = results.skip(offset).toList();
    }
    if (limit != null && limit > 0) {
      results = results.take(limit).toList();
    }

    return results;
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    _logger.info('Raw query: $sql');
    // For simplicity, return empty results for raw queries
    return [];
  }

  @override
  Future<int> rawExecute(String sql, [List<dynamic>? arguments]) async {
    _logger.info('Raw execute: $sql');
    return 1; // Assume 1 row affected
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(dynamic txn) action, {
    bool? exclusive,
  }) async {
    _logger.info('Transaction');
    return await action(this);
  }

  bool _matchesWhere(
    Map<String, dynamic> row,
    String? where,
    List<dynamic>? whereArgs,
  ) {
    if (where == null) return true;

    // Simple where clause matching
    if (where.contains('=')) {
      final parts = where.split('=');
      if (parts.length == 2) {
        final column = parts[0].trim();
        final value = parts[1].trim();
        return row[column]?.toString() == value;
      }
    }

    return true;
  }

  List<Map<String, dynamic>> _applyOrdering(
    List<Map<String, dynamic>> results,
    String orderBy,
  ) {
    // Simple ordering implementation
    if (orderBy.contains('ASC')) {
      final column = orderBy.replaceAll('ASC', '').trim();
      results.sort(
        (a, b) => (a[column] ?? '').toString().compareTo(
          (b[column] ?? '').toString(),
        ),
      );
    } else if (orderBy.contains('DESC')) {
      final column = orderBy.replaceAll('DESC', '').trim();
      results.sort(
        (a, b) => (b[column] ?? '').toString().compareTo(
          (a[column] ?? '').toString(),
        ),
      );
    }

    return results;
  }
}
