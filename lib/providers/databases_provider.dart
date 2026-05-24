import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'auth_provider.dart';

class DbColumn {
  final String key;
  final String name;
  final String type;
  final List<String> options;

  const DbColumn({required this.key, required this.name, required this.type, this.options = const []});

  factory DbColumn.fromJson(Map<String, dynamic> j) => DbColumn(
        key: j['key'] as String? ?? '',
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? 'text',
        options: List<String>.from(j['options'] as List? ?? []),
      );
}

class AppDatabase {
  final String id;
  final String name;
  final List<DbColumn> columns;
  final DateTime createdAt;

  const AppDatabase({required this.id, required this.name, required this.columns, required this.createdAt});
}

class DbRecord {
  final String id;
  final String title;
  final Map<String, dynamic> properties;
  final int order;

  const DbRecord({required this.id, required this.title, required this.properties, required this.order});
}

class DatabasesProvider extends ChangeNotifier {
  String? _userId;

  List<AppDatabase> _databases = [];
  final Map<String, List<DbRecord>> _recordsByDbId = {};

  List<AppDatabase> get databases => _databases;

  void updateAuth(AuthProvider auth) {
    final uid = auth.user?.uid;
    if (uid != _userId) {
      _userId = uid;
      if (uid == null) {
        _databases = [];
        _recordsByDbId.clear();
      }
      notifyListeners();
    }
  }

  Stream<List<DbRecord>> recordsStream(String dbId) {
    return Stream.value(List<DbRecord>.from(_recordsByDbId[dbId] ?? const []));
  }

  Future<AppDatabase> createDatabase(Map<String, dynamic> result) async {
    if (_userId == null) throw Exception('Not signed in.');

    final id = const Uuid().v4().replaceAll('-', '').substring(0, 20);
    final columns = (result['columns'] as List<dynamic>? ?? [])
        .map((e) => DbColumn.fromJson(e as Map<String, dynamic>))
        .toList();

    final db = AppDatabase(
      id: id,
      name: result['databaseTitle'] as String? ?? 'New Database',
      columns: columns,
      createdAt: DateTime.now(),
    );
    _databases = [db, ..._databases];

    final rows = result['rows'] as List<dynamic>? ?? [];
    final firstKey = columns.isNotEmpty ? columns.first.key : 'title';
    _recordsByDbId[id] = List.generate(rows.length, (i) {
      final row = rows[i] as Map<String, dynamic>;
      return DbRecord(
        id: const Uuid().v4().replaceAll('-', '').substring(0, 20),
        title: row[firstKey]?.toString() ?? 'Row ${i + 1}',
        properties: jsonDecode(jsonEncode(row)) as Map<String, dynamic>,
        order: i,
      );
    });

    notifyListeners();
    return db;
  }

  Future<void> deleteDatabase(String id) async {
    if (_userId == null) return;
    _databases = _databases.where((db) => db.id != id).toList();
    _recordsByDbId.remove(id);
    notifyListeners();
  }

  Future<void> addRecord(String dbId, List<DbColumn> columns) async {
    if (_userId == null) return;
    final records = _recordsByDbId[dbId] ?? <DbRecord>[];
    final initialProps = {for (final c in columns) c.key: c.type == 'checkbox' ? false : c.type == 'number' ? 0 : ''};
    records.add(DbRecord(
      id: const Uuid().v4().replaceAll('-', '').substring(0, 20),
      title: 'New Row',
      properties: initialProps,
      order: records.length,
    ));
    _recordsByDbId[dbId] = records;
    notifyListeners();
  }

  Future<void> updateCell(String dbId, String recordId, Map<String, dynamic> currentProps, String key, dynamic value, String firstColKey) async {
    if (_userId == null) return;
    final records = _recordsByDbId[dbId] ?? <DbRecord>[];
    final updatedProps = Map<String, dynamic>.from(currentProps)..[key] = value;
    _recordsByDbId[dbId] = records
        .map((r) => r.id == recordId
            ? DbRecord(
                id: r.id,
                title: key == firstColKey ? value.toString() : r.title,
                properties: updatedProps,
                order: r.order,
              )
            : r)
        .toList();
    notifyListeners();
  }
}
