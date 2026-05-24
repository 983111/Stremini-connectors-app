import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants.dart';
import '../core/google_api_client.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: AppConstants.googleScopes,
    // Web client ID for server-side auth — matches firebase_applet_config
    serverClientId:
        '473101509261-7sj8mijv3ribg3j3ohrr2afmc1jmtcdv.apps.googleusercontent.com',
  );

  User? _user;
  String? _accessToken;
  bool _isLoading = true;
  String? _error;

  User? get user => _user;
  String? get accessToken => _accessToken;
  bool get isSignedIn => _user != null && _accessToken != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  GoogleApiClient? get googleApiClient =>
      _accessToken != null ? GoogleApiClient(_accessToken!) : null;

  AuthProvider() {
    _auth.authStateChanges().listen((user) {
      _user = user;
      if (user == null) {
        _accessToken = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> signIn() async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _error = 'Sign-in cancelled.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _accessToken = googleAuth.accessToken;
      _user = _auth.currentUser;
    } catch (e) {
      _error = 'Sign-in failed: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    _user = null;
    _accessToken = null;
    notifyListeners();
  }

  /// Refresh the Google OAuth access token silently.
  Future<void> refreshAccessToken() async {
    try {
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        final auth = await googleUser.authentication;
        _accessToken = auth.accessToken;
        notifyListeners();
      }
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}