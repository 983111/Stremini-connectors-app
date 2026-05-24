import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBIHYAQGd-vziLH9XxHS2jU3ky3Eoq__Ys',
    appId: '1:473101509261:android:2ad8b5703eea190520f8c4',
    messagingSenderId: '473101509261',
    projectId: 'gen-lang-client-0240001721',
    storageBucket: 'gen-lang-client-0240001721.firebasestorage.app',
  );
}