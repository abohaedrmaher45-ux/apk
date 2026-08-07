// Sample Firebase options for open-source distribution.
// Replace these placeholder values with your own Firebase project details.
// Placeholder config files are provided at:
//   - android/app/google-services.json
//   - ios/Runner/GoogleService-Info.plist

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';

class FirebasePlaceholderConfig {
  static const apiKey = 'AIzaSyAXn6H3psDm6rmToxQ884F-STUK6kN5ps0';
  static const senderId = '508776518027';
  static const projectId = 'sentrytech-20cf3';
  static const storageBucket = 'sentrytech-20cf3.firebasestorage.app';
  static const androidAppId = '1:508776518027:android:153f448992d0d538835f8e';
  static const iosAppId = '1:508776518027:ios:1234567890abcdef12345678';
  static const iosBundleId = 'com.webkul.bagistoApp.iOS';
}

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isAndroid) {
      return android;
    }
    if (Platform.isIOS) {
      return ios;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: FirebasePlaceholderConfig.apiKey,
    appId: FirebasePlaceholderConfig.androidAppId,
    messagingSenderId: FirebasePlaceholderConfig.senderId,
    projectId: FirebasePlaceholderConfig.projectId,
    storageBucket: FirebasePlaceholderConfig.storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: FirebasePlaceholderConfig.apiKey,
    appId: FirebasePlaceholderConfig.iosAppId,
    messagingSenderId: FirebasePlaceholderConfig.senderId,
    projectId: FirebasePlaceholderConfig.projectId,
    storageBucket: FirebasePlaceholderConfig.storageBucket,
    iosBundleId: FirebasePlaceholderConfig.iosBundleId,
  );
}
