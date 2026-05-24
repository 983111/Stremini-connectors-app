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
  String? _userId;
  List<DocumentModel> _documents = [];
  bool _isLoading = false;

  List<DocumentModel> get documents => _documents;
  bool get isLoading => _isLoading;

  void updateAuth(AuthProvider auth) {
    final uid = auth.user?.uid;
    if (uid != _userId) {
      _userId = uid;
      if (uid == null) {
        _documents = [];
      }
      notifyListeners();
    }
  }

  Future<DocumentModel> createDocument() async {
    if (_userId == null) throw Exception('Not signed in.');
    final now = DateTime.now();
    final doc = DocumentModel(
      id: const Uuid().v4().replaceAll('-', '').substring(0, 20),
      title: 'Untitled Document',
      content: '# New Document\n\nStart writing here...',
      createdAt: now,
      updatedAt: now,
    );
    _documents = [doc, ..._documents];
    notifyListeners();
    return doc;
  }

  Future<void> updateDocument(String id, {String? title, String? content}) async {
    if (_userId == null) return;
    _documents = _documents
        .map((doc) => doc.id == id ? doc.copyWith(title: title, content: content) : doc)
        .toList();
    notifyListeners();
  }

  Future<void> deleteDocument(String id) async {
    if (_userId == null) return;
    _documents = _documents.where((doc) => doc.id != id).toList();
    notifyListeners();
  }
}
