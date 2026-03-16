// Placeholder Firebase options. Replace with FlutterFire CLI output.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'YOUR_ANDROID_API_KEY',
          appId: 'YOUR_ANDROID_APP_ID',
          messagingSenderId: 'YOUR_ANDROID_SENDER_ID',
          projectId: 'YOUR_FIREBASE_PROJECT_ID',
          storageBucket: 'YOUR_FIREBASE_STORAGE_BUCKET',
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const FirebaseOptions(
          apiKey: 'YOUR_IOS_API_KEY',
          appId: 'YOUR_IOS_APP_ID',
          messagingSenderId: 'YOUR_IOS_SENDER_ID',
          projectId: 'YOUR_FIREBASE_PROJECT_ID',
          iosBundleId: 'com.example.careconnect_app',
          storageBucket: 'YOUR_FIREBASE_STORAGE_BUCKET',
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return const FirebaseOptions(
          apiKey: 'YOUR_WEB_OR_DESKTOP_API_KEY',
          appId: 'YOUR_WEB_OR_DESKTOP_APP_ID',
          messagingSenderId: 'YOUR_WEB_OR_DESKTOP_SENDER_ID',
          projectId: 'YOUR_FIREBASE_PROJECT_ID',
        );
    }
  }
}
