import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../config/app_license.dart';
import 'device_fingerprint.dart';

/// ✅ نظام التحقق من الترخيص - أوفلاين بالكامل وحماية فائقة
class LicenseValidator {
  
  // 🛡️ تخزين آمن
  static final _secureStorage = FlutterSecureStorage();
  
  // 🔑 مفاتيح التخزين - بأسماء مضللة!
  static const String _KEY_1 = 'a7x9k2m4n6p8q1r3'; // device_fingerprint
  static const String _KEY_2 = 'z9y1x3w5v7u9t1r5'; // license_activated
  static const String _KEY_3 = 'b8n2m4q6w8e1r3t5'; // activation_date
  static const String _KEY_4 = 'c7v5b3n1m9k7j5h3'; // app_launches
  static const String _KEY_5 = 'd4f6g8h0j2k4l6m8'; // encrypted_license
  
  /// 🔐 التحقق الرئيسي - أوفلاين 100%
  static Future<LicenseValidationResult> validateLicense() async {
    try {
      // 1️⃣ التحقق من صحة معرف الترخيص
      if (!AppLicense.validateLicense()) {
        return _errorResult('❌ تكوين الترخيص غير صالح', LicenseErrorCode.invalidLicense);
      }
      
      // 2️⃣ الحصول على بصمة الجهاز الحالية
      final currentFingerprint = await DeviceFingerprint.getDeviceFingerprint();
      if (currentFingerprint.isEmpty) {
        return _errorResult('❌ لا يمكن التعرف على الجهاز', LicenseErrorCode.deviceError);
      }
      
      // 3️⃣ التحقق من الترخيص المخزن
      final isActivated = await _secureStorage.read(key: _KEY_2);
      final storedFingerprint = await _secureStorage.read(key: _KEY_1);
      final encryptedLicense = await _secureStorage.read(key: _KEY_5);
      
      // 4️⃣ حالة: أول تشغيل للجهاز
      if (isActivated == null || storedFingerprint == null) {
        return await _firstTimeActivation(currentFingerprint);
      }
      
      // 5️⃣ التحقق من صحة الترخيص المخزن
      if (!await _verifyStoredLicense(storedFingerprint, encryptedLicense ?? '')) {
        return _errorResult('❌ ملف الترخيص تالف', LicenseErrorCode.corruptedLicense);
      }
      
      // 6️⃣ التحقق من مطابقة الجهاز
      if (storedFingerprint != currentFingerprint) {
        // 🚨 محاولة نسخ! سجل المخالفة
        await _recordViolation(currentFingerprint);
        return _errorResult('❌ هذا التطبيق مرخص لجهاز آخر', LicenseErrorCode.deviceMismatch);
      }
      
      // 7️⃣ كل شيء سليم - سجل التشغيل
      await _recordAppLaunch();
      
      // 8️⃣ تحقق إضافي: فحص هل التطبيق معدل؟
      if (await _isAppTampered()) {
        return _errorResult('❌ تم العبث بالتطبيق', LicenseErrorCode.appTampered);
      }
      
      return LicenseValidationResult(
        isValid: true,
        deviceFingerprint: currentFingerprint,
        activationDate: await _secureStorage.read(key: _KEY_3) ?? '',
        totalLaunches: await _getAppLaunches(),
        isOfflineMode: true,
      );
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('خطأ في التحقق: $e');
      }
      return _errorResult('حدث خطأ غير متوقع', LicenseErrorCode.unknownError);
    }
  }
  
  /// 🎉 التفعيل لأول مرة
  static Future<LicenseValidationResult> _firstTimeActivation(String fingerprint) async {
    try {
      // 1️⃣ إنشاء ترخيص مشفر
      final licenseData = {
        'license_id': AppLicense.UNIQUE_LICENSE_ID,
        'device': fingerprint,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'salt': _generateRandomString(32),
      };
      
      // 2️⃣ تشفير الترخيص
      final encryptedLicense = await _encryptLicense(licenseData);
      
      // 3️⃣ حفظ كل شيء في التخزين الآمن
      await _secureStorage.write(key: _KEY_1, value: fingerprint);
      await _secureStorage.write(key: _KEY_2, value: 'true');
      await _secureStorage.write(key: _KEY_3, value: DateTime.now().toIso8601String());
      await _secureStorage.write(key: _KEY_4, value: '1');
      await _secureStorage.write(key: _KEY_5, value: encryptedLicense);
      
      // 4️⃣ حفظ نسخة احتياطية في ملف مخفي
      await _saveBackupLicense(fingerprint, encryptedLicense);
      
      return LicenseValidationResult(
        isValid: true,
        isFirstActivation: true,
        deviceFingerprint: fingerprint,
        activationDate: DateTime.now().toIso8601String(),
        totalLaunches: 1,
        isOfflineMode: true,
      );
      
    } catch (e) {
      return _errorResult('فشل تفعيل الترخيص', LicenseErrorCode.activationFailed);
    }
  }
  
  /// 🔒 تشفير الترخيص
  static Future<String> _encryptLicense(Map<String, dynamic> data) async {
    final jsonString = json.encode(data);
    final key = utf8.encode(AppLicense._MASTER_KEY + AppLicense.APP_ID);
    final bytes = utf8.encode(jsonString);
    
    // تشفير بسيط - XOR مع المفتاح
    final List<int> encrypted = [];
    for (int i = 0; i < bytes.length; i++) {
      encrypted.add(bytes[i] ^ key[i % key.length]);
    }
    
    // تحويل لـ base64
    return base64.encode(encrypted);
  }
  
  /// 🔓 فك تشفير الترخيص
  static Future<Map<String, dynamic>?> _decryptLicense(String encryptedData) async {
    try {
      final encryptedBytes = base64.decode(encryptedData);
      final key = utf8.encode(AppLicense._MASTER_KEY + AppLicense.APP_ID);
      
      final List<int> decrypted = [];
      for (int i = 0; i < encryptedBytes.length; i++) {
        decrypted.add(encryptedBytes[i] ^ key[i % key.length]);
      }
      
      final jsonString = utf8.decode(decrypted);
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
  
  /// ✅ التحقق من صحة الترخيص المخزن
  static Future<bool> _verifyStoredLicense(String fingerprint, String encryptedLicense) async {
    final decrypted = await _decryptLicense(encryptedLicense);
    if (decrypted == null) return false;
    
    // التحقق من تطابق بصمة الجهاز
    if (decrypted['device'] != fingerprint) return false;
    
    // التحقق من صحة معرف الترخيص
    if (decrypted['license_id'] != AppLicense.UNIQUE_LICENSE_ID) return false;
    
    return true;
  }
  
  /// 💾 حفظ نسخة احتياطية في ملف مخفي
  static Future<void> _saveBackupLicense(String fingerprint, String encryptedLicense) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final hiddenFile = File('${directory.path}/.system_cache');
      
      // تشفير إضافي للملف
      final backupData = {
        'fp': fingerprint.substring(0, 20),
        'lic': encryptedLicense.substring(0, 50),
        'v': '2.0',
      };
      
      await hiddenFile.writeAsString(json.encode(backupData));
    } catch (_) {
      // فشل الحفظ الاحتياطي - لا مشكلة
    }
  }
  
  /// 📝 تسجيل محاولة نسخ
  static Future<void> _recordViolation(String fingerprint) async {
    try {
      final violations = await _secureStorage.read(key: 'violation_count') ?? '0';
      final count = int.tryParse(violations) ?? 0;
      await _secureStorage.write(key: 'violation_count', value: (count + 1).toString());
      await _secureStorage.write(key: 'last_violation', value: DateTime.now().toIso8601String());
      await _secureStorage.write(key: 'violation_device', value: fingerprint);
    } catch (_) {}
  }
  
  /// 🚫 فحص هل التطبيق معدل؟
  static Future<bool> _isAppTampered() async {
    // 1️⃣ فحص وجود ملفات غير مصرح بها
    try {
      final directory = await getApplicationDocumentsDirectory();
      final suspicious = await directory.list().any((file) => 
        file.path.contains('frida') || 
        file.path.contains('xposed') ||
        file.path.contains('substrate')
      );
      if (suspicious) return true;
    } catch (_) {}
    
    // 2️⃣ فحص وضع التصحيح
    if (kDebugMode) {
      // في وضع الإنتاج، هذا لا يحدث
      return false;
    }
    
    return false;
  }
  
  /// 🔢 عدد مرات التشغيل
  static Future<int> _getAppLaunches() async {
    final launches = await _secureStorage.read(key: _KEY_4) ?? '0';
    return int.tryParse(launches) ?? 0;
  }
  
  /// 📊 تسجيل تشغيل جديد
  static Future<void> _recordAppLaunch() async {
    final launches = await _getAppLaunches();
    await _secureStorage.write(key: _KEY_4, value: (launches + 1).toString());
  }
  
  /// ❌ إنشاء نتيجة خطأ
  static LicenseValidationResult _errorResult(String message, LicenseErrorCode code) {
    return LicenseValidationResult(
      isValid: false,
      errorMessage: message,
      errorCode: code,
      isOfflineMode: true,
    );
  }
  
  /// 🎲 توليد نص عشوائي
  static String _generateRandomString(int length) {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final bytes = utf8.encode(random);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, length);
  }
  
  /// 🔍 الحصول على حالة الترخيص
  static Future<Map<String, dynamic>> getLicenseStatus() async {
    final deviceFingerprint = await DeviceFingerprint.getDeviceFingerprint();
    final deviceInfo = await DeviceFingerprint.getDeviceInfo();
    final encryptedLicense = await _secureStorage.read(key: _KEY_5);
    final decrypted = encryptedLicense != null 
        ? await _decryptLicense(encryptedLicense) 
        : null;
    
    return {
      'license_id': AppLicense.UNIQUE_LICENSE_ID,
      'is_activated': await _secureStorage.read(key: _KEY_2) == 'true',
      'activation_date': await _secureStorage.read(key: _KEY_3) ?? 'غير مفعل',
      'total_launches': await _getAppLaunches(),
      'device_fingerprint': await _secureStorage.read(key: _KEY_1) ?? 'لا يوجد',
      'device_info': deviceInfo,
      'license_valid': decrypted != null,
      'violation_count': await _secureStorage.read(key: 'violation_count') ?? '0',
      'app_version': AppLicense.APP_VERSION,
    };
  }
  
  /// 🧹 إعادة تعيين (للتطوير فقط)
  static Future<void> resetLicense() async {
    await _secureStorage.deleteAll();
  }
}

/// 📊 نتيجة التحقق
class LicenseValidationResult {
  final bool isValid;
  final String? errorMessage;
  final LicenseErrorCode? errorCode;
  final String? deviceFingerprint;
  final bool isFirstActivation;
  final String? activationDate;
  final int? totalLaunches;
  final bool isOfflineMode;
  
  LicenseValidationResult({
    required this.isValid,
    this.errorMessage,
    this.errorCode,
    this.deviceFingerprint,
    this.isFirstActivation = false,
    this.activationDate,
    this.totalLaunches,
    this.isOfflineMode = false,
  });
}

/// ⚠️ أكواد الأخطاء
enum LicenseErrorCode {
  invalidLicense,      // ترخيص غير صالح
  deviceMismatch,      // جهاز مختلف
  deviceError,         // خطأ في الجهاز
  corruptedLicense,    // ملف الترخيص تالف
  activationFailed,    // فشل التفعيل
  appTampered,        // تم العبث بالتطبيق
  unknownError,        // خطأ غير معروف
}