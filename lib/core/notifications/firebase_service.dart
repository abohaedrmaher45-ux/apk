import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

/// Firebase initialization service
/// Handles Firebase setup for both Android and iOS platforms
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  static bool _isEnabled = false;

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  static bool get isEnabled => _isEnabled;

  // القيم الأصلية التي يوزَّع بها المشروع مفتوح المصدر (قبل أن يضع أي مطوّر
  // مشروع Firebase الحقيقي الخاص به). لا تُقارَن مع FirebasePlaceholderConfig
  // نفسه لأن قيمه هي بالضبط ما يُستبدَل بالقيم الحقيقية — مقارنتها بنفسها
  // كانت ستُعيد true دائماً وتُعطّل Firebase حتى بعد وضع إعدادات حقيقية.
  static const _placeholderProjectId = 'placeholder-firebase-project';
  static const _placeholderSenderId = '000000000000';
  static const _placeholderStorageBucket =
      'placeholder-firebase-project.appspot.com';

  static bool _hasPlaceholderConfig(FirebaseOptions options) {
    return options.projectId == _placeholderProjectId ||
        options.messagingSenderId == _placeholderSenderId ||
        options.storageBucket == _placeholderStorageBucket;
  }

  /// Initialize Firebase with platform-specific options
  /// Must be called before running the app
  static Future<bool> initialize() async {
    final options = DefaultFirebaseOptions.currentPlatform;

    if (_hasPlaceholderConfig(options)) {
      _isEnabled = false;
      debugPrint(
        '⚠️ Firebase config contains placeholder values. '
        'Skipping Firebase initialization.',
      );
      return false;
    }

    try {
      debugPrint('🔥 Initializing Firebase...');

      await Firebase.initializeApp(
        options: options,
      );

      _isEnabled = true;
      debugPrint('✅ Firebase initialized successfully');
      return true;
    } catch (e) {
      _isEnabled = false;
      debugPrint('❌ Firebase initialization error: $e');
      return false;
    }
  }
}
