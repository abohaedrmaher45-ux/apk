import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_license.dart';
import 'device_fingerprint.dart';

/// نظام التحقق من الترخيص ومنع النسخ
class LicenseValidator {
  static const String _KEY_DEVICE_FINGERPRINT = 'device_fingerprint';
  static const String _KEY_LICENSE_ACTIVATED = 'license_activated';
  static const String _KEY_ACTIVATION_DATE = 'activation_date';
  static const String _KEY_APP_LAUNCHES = 'app_launches';
  
  /// التحقق الكامل من الترخيص والجهاز
  static Future<LicenseValidationResult> validateLicense() async {
    try {
      // 1. التحقق من صحة معرف الترخيص
      if (!AppLicense.validateLicense()) {
        return LicenseValidationResult(
          isValid: false,
          errorMessage: 'Invalid license configuration',
          errorCode: LicenseErrorCode.invalidLicense,
        );
      }
      
      // 2. الحصول على بصمة الجهاز الحالية
      final currentFingerprint = await DeviceFingerprint.getDeviceFingerprint();
      if (currentFingerprint.isEmpty) {
        return LicenseValidationResult(
          isValid: false,
          errorMessage: 'Unable to verify device',
          errorCode: LicenseErrorCode.deviceError,
        );
      }
      
      // 3. التحقق من التفعيل السابق
      final prefs = await SharedPreferences.getInstance();
      final storedFingerprint = prefs.getString(_KEY_DEVICE_FINGERPRINT);
      final isActivated = prefs.getBool(_KEY_LICENSE_ACTIVATED) ?? false;
      
      if (!isActivated) {
        // التشغيل الأول - تفعيل الترخيص
        await _activateLicense(prefs, currentFingerprint);
        return LicenseValidationResult(
          isValid: true,
          isFirstActivation: true,
          deviceFingerprint: currentFingerprint,
        );
      }
      
      // 4. التحقق من مطابقة بصمة الجهاز
      if (storedFingerprint != currentFingerprint) {
        return LicenseValidationResult(
          isValid: false,
          errorMessage: 'This app is licensed for a different device',
          errorCode: LicenseErrorCode.deviceMismatch,
        );
      }
      
      // 5. تسجيل التشغيل الجديد
      await _recordAppLaunch(prefs);
      
      return LicenseValidationResult(
        isValid: true,
        deviceFingerprint: currentFingerprint,
        activationDate: prefs.getString(_KEY_ACTIVATION_DATE) ?? '',
        totalLaunches: prefs.getInt(_KEY_APP_LAUNCHES) ?? 1,
      );
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('License validation error: $e');
      }
      return LicenseValidationResult(
        isValid: false,
        errorMessage: 'Validation error occurred',
        errorCode: LicenseErrorCode.unknownError,
      );
    }
  }
  
  /// تفعيل الترخيص للمرة الأولى
  static Future<void> _activateLicense(
    SharedPreferences prefs,
    String deviceFingerprint,
  ) async {
    await prefs.setString(_KEY_DEVICE_FINGERPRINT, deviceFingerprint);
    await prefs.setBool(_KEY_LICENSE_ACTIVATED, true);
    await prefs.setString(_KEY_ACTIVATION_DATE, DateTime.now().toIso8601String());
    await prefs.setInt(_KEY_APP_LAUNCHES, 1);
  }
  
  /// تسجيل تشغيل التطبيق
  static Future<void> _recordAppLaunch(SharedPreferences prefs) async {
    final launches = prefs.getInt(_KEY_APP_LAUNCHES) ?? 0;
    await prefs.setInt(_KEY_APP_LAUNCHES, launches + 1);
  }
  
  /// إعادة تعيين الترخيص (للاختبار فقط - احذف في الإنتاج)
  static Future<void> resetLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_KEY_DEVICE_FINGERPRINT);
    await prefs.remove(_KEY_LICENSE_ACTIVATED);
    await prefs.remove(_KEY_ACTIVATION_DATE);
    await prefs.remove(_KEY_APP_LAUNCHES);
  }
  
  /// الحصول على معلومات الترخيص الحالية
  static Future<Map<String, dynamic>> getLicenseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceInfo = await DeviceFingerprint.getDeviceInfo();
    
    return {
      'license_id': AppLicense.UNIQUE_LICENSE_ID,
      'is_activated': prefs.getBool(_KEY_LICENSE_ACTIVATED) ?? false,
      'activation_date': prefs.getString(_KEY_ACTIVATION_DATE) ?? 'Not activated',
      'total_launches': prefs.getInt(_KEY_APP_LAUNCHES) ?? 0,
      'device_fingerprint': prefs.getString(_KEY_DEVICE_FINGERPRINT) ?? 'None',
      'device_info': deviceInfo,
      'app_version': AppLicense.APP_VERSION,
    };
  }
}

/// نتيجة التحقق من الترخيص
class LicenseValidationResult {
  final bool isValid;
  final String? errorMessage;
  final LicenseErrorCode? errorCode;
  final String? deviceFingerprint;
  final bool isFirstActivation;
  final String? activationDate;
  final int? totalLaunches;
  
  LicenseValidationResult({
    required this.isValid,
    this.errorMessage,
    this.errorCode,
    this.deviceFingerprint,
    this.isFirstActivation = false,
    this.activationDate,
    this.totalLaunches,
  });
  
  @override
  String toString() {
    if (isValid) {
      return 'License Valid - Device: ${deviceFingerprint?.substring(0, 8)}...';
    } else {
      return 'License Invalid - ${errorMessage ?? "Unknown error"}';
    }
  }
}

/// أكواد أخطاء الترخيص
enum LicenseErrorCode {
  invalidLicense,
  deviceMismatch,
  deviceError,
  unknownError,
}
