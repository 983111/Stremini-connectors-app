import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin wrapper around Google REST APIs using the OAuth access token
/// obtained from GoogleSignIn.
class GoogleApiClient {
  final String accessToken;
  GoogleApiClient(this.accessToken);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  // ── GMAIL ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchRecentEmails({
    String query = '',
    int maxResults = 50,
  }) async {
    final q = query.isNotEmpty ? '&q=${Uri.encodeComponent(query)}' : '';
    final listUri = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages'
      '?maxResults=$maxResults$q',
    );
    final listRes = await http.get(listUri, headers: _headers);
    _checkStatus(listRes, 'Gmail list');

    final listData = jsonDecode(listRes.body) as Map<String, dynamic>;
    final messages = listData['messages'] as List<dynamic>? ?? [];
    if (messages.isEmpty) return [];

    // Fetch metadata in batches of 10
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < messages.length; i += 10) {
      final batch = messages.skip(i).take(10).toList();
      final futures = batch.map((m) async {
        try {
          final id = m['id'] as String;
          final mUri = Uri.parse(
            'https://gmail.googleapis.com/gmail/v1/users/me/messages/$id'
            '?format=metadata',
          );
          final mRes = await http.get(mUri, headers: _headers);
          if (mRes.statusCode != 200) return null;
          return jsonDecode(mRes.body) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      });
      final fetched = await Future.wait(futures);
      result.addAll(
        fetched.whereType<Map<String, dynamic>>().map(_parseEmailMeta),
      );
    }
    return result;
  }

  Map<String, dynamic> _parseEmailMeta(Map<String, dynamic> m) {
    final headers = (m['payload']?['headers'] as List<dynamic>?) ?? [];
    String header(String name) => headers
        .firstWhere(
          (h) => (h['name'] as String).toLowerCase() == name.toLowerCase(),
          orElse: () => {'value': ''},
        )['value'] as String;

    return {
      'id': m['id'],
      'threadId': m['threadId'],
      'snippet': m['snippet'] ?? '',
      'subject': header('Subject').isEmpty ? '(no subject)' : header('Subject'),
      'from': header('From'),
      'date': header('Date'),
    };
  }

  Future<String> fetchEmailBody(String messageId) async {
    final uri = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId?format=full',
    );
    final res = await http.get(uri, headers: _headers);
    _checkStatus(res, 'Gmail message body');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return _extractBody(data['payload']);
  }

  String _extractBody(dynamic payload) {
    if (payload == null) return '';
    final body = payload['body'] as Map<String, dynamic>?;
    if (body != null && body['data'] != null) {
      return _decodeBase64(body['data'] as String);
    }
    final parts = payload['parts'] as List<dynamic>?;
    if (parts != null) {
      for (final part in parts) {
        final mime = part['mimeType'] as String? ?? '';
        if (mime == 'text/plain' || mime == 'text/html') {
          final b = part['body'] as Map<String, dynamic>?;
          if (b?['data'] != null) return _decodeBase64(b!['data'] as String);
        }
        final nested = _extractBody(part);
        if (nested.isNotEmpty) return nested;
      }
    }
    return '';
  }

  String _decodeBase64(String data) {
    try {
      final normalized = data.replaceAll('-', '+').replaceAll('_', '/');
      return utf8.decode(base64.decode(normalized));
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>> fetchThread(String threadId) async {
    final uri = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/threads/$threadId',
    );
    final res = await http.get(uri, headers: _headers);
    _checkStatus(res, 'Gmail thread');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    final raw = 'To: $to\r\nSubject: $subject\r\nContent-Type: text/plain; '
        'charset="UTF-8"\r\n\r\n$body';
    final encoded = base64Url
        .encode(utf8.encode(raw))
        .replaceAll('=', '');

    final uri = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
    );
    final res = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'raw': encoded}),
    );
    _checkStatus(res, 'Send email');
  }

  // ── DRIVE ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchDriveFiles({
    String query = '',
    String orderBy = 'modifiedTime desc',
    int pageSize = 50,
  }) async {
    final qStr = query.isNotEmpty
        ? '&q=${Uri.encodeComponent(query)}'
        : '';
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files'
      '?pageSize=$pageSize'
      '&orderBy=${Uri.encodeComponent(orderBy)}'
      '&fields=files(id,name,mimeType,modifiedTime,createdTime,webViewLink)'
      '$qStr',
    );
    final res = await http.get(uri, headers: _headers);
    _checkStatus(res, 'Drive files');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['files'] as List? ?? []);
  }

  Future<String> fetchDriveFileContent(String fileId, String mimeType) async {
    final Uri uri;
    if (mimeType == 'application/vnd.google-apps.document') {
      uri = Uri.parse(
        'https://www.googleapis.com/drive/v3/files/$fileId/export?mimeType=text/plain',
      );
    } else {
      uri = Uri.parse(
        'https://www.googleapis.com/drive/v3/files/$fileId?alt=media',
      );
    }
    final res = await http.get(uri, headers: _headers);
    _checkStatus(res, 'Drive file content');
    return res.body;
  }

  // ── FORMS ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createForm(String title) async {
    final uri = Uri.parse('https://forms.googleapis.com/v1/forms');
    final res = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'info': {'title': title},
      }),
    );
    _checkStatus(res, 'Create form');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> updateFormBatch(
    String formId,
    List<Map<String, dynamic>> requests,
  ) async {
    final uri = Uri.parse(
      'https://forms.googleapis.com/v1/forms/$formId:batchUpdate',
    );
    final res = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'requests': requests}),
    );
    _checkStatus(res, 'Form batch update');
  }

  // ── SLIDES ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createPresentation(String title) async {
    final uri = Uri.parse('https://slides.googleapis.com/v1/presentations');
    final res = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'title': title}),
    );
    _checkStatus(res, 'Create presentation');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> updatePresentationBatch(
    String presentationId,
    List<Map<String, dynamic>> requests,
  ) async {
    final uri = Uri.parse(
      'https://slides.googleapis.com/v1/presentations/$presentationId:batchUpdate',
    );
    final res = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'requests': requests}),
    );
    _checkStatus(res, 'Presentation batch update');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _checkStatus(http.Response res, String op) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        '$op failed (${res.statusCode}): ${res.body.substring(0, res.body.length.clamp(0, 200))}',
      );
    }
  }
}