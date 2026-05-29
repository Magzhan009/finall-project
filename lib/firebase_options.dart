import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase web options are not configured. Add a web app in Firebase '
        'Console and regenerate firebase_options.dart.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'Firebase options are not configured for iOS/macOS. Add '
          'GoogleService-Info.plist and regenerate firebase_options.dart.',
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase options are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBo1nyyYCIEwkxhP4FC5JBLxCvprnpRDIU',
    appId: '1:52976884725:android:a2131577e185f066781ebc',
    messagingSenderId: '52976884725',
    projectId: 'finall-project-e5ed2',
    storageBucket: 'finall-project-e5ed2.firebasestorage.app',
  );
}
