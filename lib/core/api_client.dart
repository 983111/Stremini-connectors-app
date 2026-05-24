import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

/// Wraps all calls to the Stremini worker.
/// Automatically fetches a fresh Firebase ID token and injects it
/// as `Authorization: Bearer <token>` on every request.
class ApiClient {
  ApiClient._();

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated.');

    // Force-refresh = false: uses cached token unless expired
    final idToken = await user.getIdToken(false);
    if (idToken == null) throw Exception('Could not obtain ID token.');

    final uri = Uri.parse('${AppConstants.workerUrl}$path');

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception(
            'Request timed out. Please check your connection.',
          ),
        );

    final text = response.body;

    if (response.statusCode == 401) {
      throw Exception('Session expired. Please sign in again.');
    }
    if (response.statusCode == 403) {
      throw Exception('Access denied. Please sign in again.');
    }

    if (text.isEmpty) return {};

    final decoded = jsonDecode(text) as Map<String, dynamic>;

    if (decoded.containsKey('error')) {
      throw Exception(decoded['error'] as String? ?? 'Worker error.');
    }

    return decoded;
  }

  /// Convenience: POST and return a top-level string field from the response.
  static Future<String> postString(
    String path,
    Map<String, dynamic> payload,
    String field,
  ) async {
    final data = await post(path, payload);
    final value = data[field];
    if (value == null) throw Exception('No $field in response.');
    return value as String;
  }
}