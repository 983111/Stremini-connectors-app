import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'auth_provider.dart';

class DbColumn {
  final String key;
  final String name;
  final String type; // text | number | date | select | checkbox
  final List<String> options;

  const DbColumn({
    required this.key,
    required this.name,
    required this.type,
    this.options = const [],
  });

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

  const AppDatabase({
    required this.id,
    required this.name,
    required this.columns,
    required this.createdAt,
  });

  factory AppDatabase.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final schemaRaw = d['schema'] as String? ?? '[]';
    final cols = (jsonDecode(schemaRaw) as List<dynamic>)
        .map((e) => DbColumn.fromJson(e as Map<String, dynamic>))
        .toList();
    return AppDatabase(
      id: doc.id,
      name: d['name'] as String? ?? 'Untitled',
      columns: cols,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class DbRecord {
  final String id;
  final String title;
  final Map<String, dynamic> properties;
  final int order;

  const DbRecord({
    required this.id,
    required this.title,
    required this.properties,
    required this.order,
  });

  factory DbRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final propsRaw = d['properties'] as String? ?? '{}';
    return DbRecord(
      id: doc.id,
      title: d['title'] as String? ?? '',
      properties: jsonDecode(propsRaw) as Map<String, dynamic>,
      order: d['order'] as int? ?? 0,
    );
  }
}

class DatabasesProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;

  List<AppDatabase> _databases = [];
  bool _isLoading = false;

  List<AppDatabase> get databases => _databases;
  bool get isLoading => _isLoading;

  void updateAuth(AuthProvider auth) {
    final uid = auth.user?.uid;
    if (uid != _userId) {
      _userId = uid;
      if (uid != null) _listenDatabases();
    }
  }

  void _listenDatabases() {
    if (_userId == null) return;
    _db
        .collection('users/$_userId/databases')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _databases = snap.docs.map(AppDatabase.fromFirestore).toList();
      notifyListeners();
    });
  }

  Stream<List<DbRecord>> recordsStream(String dbId) {
    if (_userId == null) return const Stream.empty();
    return _db
        .collection('users/$_userId/databases/$dbId/records')
        .orderBy('order')
        .snapshots()
        .map((s) => s.docs.map(DbRecord.fromFirestore).toList());
  }

  Future<AppDatabase> createDatabase(Map<String, dynamic> result) async {
    if (_userId == null) throw Exception('Not signed in.');
    final id = const Uuid().v4().replaceAll('-', '').substring(0, 20);
    final columns = result['columns'] as List<dynamic>? ?? [];
    final rows = result['rows'] as List<dynamic>? ?? [];

    final batch = _db.batch();
    final dbRef = _db.collection('users/$_userId/databases').doc(id);
    batch.set(dbRef, {
      'name': result['databaseTitle'] ?? 'New Database',
      'schema': jsonEncode(columns),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'userId': _userId,
    });

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i] as Map<String, dynamic>;
      final firstKey = columns.isNotEmpty
          ? (columns[0] as Map<String, dynamic>)['key'] as String? ?? 'title'
          : 'title';
      final recRef = dbRef.collection('records').doc();
      batch.set(recRef, {
        'title': row[firstKey]?.toString() ?? 'Row ${i + 1}',
        'properties': jsonEncode(row),
        'order': i,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    return AppDatabase(
      id: id,
      name: result['databaseTitle'] as String? ?? 'New Database',
      columns: columns
          .map((e) => DbColumn.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.now(),
    );
  }

  Future<void> deleteDatabase(String id) async {
    if (_userId == null) return;
    await _db.doc('users/$_userId/databases/$id').delete();
  }

  Future<void> addRecord(String dbId, List<DbColumn> columns) async {
    if (_userId == null) return;
    final initialProps = {for (final c in columns) c.key: c.type == 'checkbox' ? false : c.type == 'number' ? 0 : ''};
    final existing = await _db
        .collection('users/$_userId/databases/$dbId/records')
        .count()
        .get();
    final count = existing.count ?? 0;
    await _db.collection('users/$_userId/databases/$dbId/records').add({
      'title': 'New Row',
      'properties': jsonEncode(initialProps),
      'order': count,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCell(
    String dbId,
    String recordId,
    Map<String, dynamic> currentProps,
    String key,
    dynamic value,
    String firstColKey,
  ) async {
    if (_userId == null) return;
    final updated = Map<String, dynamic>.from(currentProps)..[key] = value;
    final updates = <String, dynamic>{
      'properties': jsonEncode(updated),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (key == firstColKey) updates['title'] = value.toString();
    await _db
        .doc('users/$_userId/databases/$dbId/records/$recordId')
        .update(updates);
  }
}