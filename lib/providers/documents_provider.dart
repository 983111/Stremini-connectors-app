import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'auth_provider.dart';

class DocumentModel {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DocumentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DocumentModel(
      id: doc.id,
      title: d['title'] as String? ?? 'Untitled',
      content: d['content'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  DocumentModel copyWith({String? title, String? content}) {
    return DocumentModel(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class DocumentsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;

  List<DocumentModel> _documents = [];
  bool _isLoading = false;

  List<DocumentModel> get documents => _documents;
  bool get isLoading => _isLoading;

  void updateAuth(AuthProvider auth) {
    final uid = auth.user?.uid;
    if (uid != _userId) {
      _userId = uid;
      if (uid != null) _listenDocuments();
    }
  }

  void _listenDocuments() {
    if (_userId == null) return;
    _db
        .collection('users/$_userId/documents')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snap) {
      _documents = snap.docs.map(DocumentModel.fromFirestore).toList();
      notifyListeners();
    });
  }

  Future<DocumentModel> createDocument() async {
    if (_userId == null) throw Exception('Not signed in.');
    final id = const Uuid().v4().replaceAll('-', '').substring(0, 20);
    final now = FieldValue.serverTimestamp();
    final data = {
      'title': 'Untitled Document',
      'content': '# New Document\n\nStart writing here...',
      'createdAt': now,
      'updatedAt': now,
      'userId': _userId,
    };
    await _db.collection('users/$_userId/documents').doc(id).set(data);
    return DocumentModel(
      id: id,
      title: 'Untitled Document',
      content: '# New Document\n\nStart writing here...',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> updateDocument(String id, {String? title, String? content}) async {
    if (_userId == null) return;
    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    await _db.doc('users/$_userId/documents/$id').update(updates);
  }

  Future<void> deleteDocument(String id) async {
    if (_userId == null) return;
    await _db.doc('users/$_userId/documents/$id').delete();
  }
}