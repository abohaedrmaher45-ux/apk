import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ntp/ntp.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/time_security_service.dart';
import 'services/validation_service.dart';

class LicenseService {
  final _storage = const FlutterSecureStorage();
  final TimeSecurityService _timeService = TimeSecurityService();
  final ValidationService _validationService = ValidationService();
  
  final String _keyIsActivated = 'is_activated_final';
  final String _keyFirstLaunch = 'first_launch_date_secure';
  final String _keyUsername = 'username_secure';
  final String _hiddenFileName = ".sys_config_cache";

  /// الحصول على وقت آمن مضاد للتلاعب
  Future<DateTime> _getSecureTime() async {
    final time = await _timeService.getSecureTime();
    return time ?? DateTime.now();
  }

  /// التحقق من التثبيت السابق للتطبيق
  Future<bool> _checkPreviousInstall() async {
    try {
      if (await Permission.manageExternalStorage.request().isGranted || 
          await Permission.storage.request().isGranted) {
        
        Directory? externalDir = Directory('/storage/emulated/0');
        
        if (await externalDir.exists()) {
          File hiddenFile = File('${externalDir.path}/$_hiddenFileName');
          
          if (await hiddenFile.exists()) {
            return true;
          } else {
            DateTime now = await _getSecureTime();
            await hiddenFile.writeAsString(now.toIso8601String());
            return false;
          }
        }
      }
    } catch (e) {
      // في حالة فشل الوصول للتخزين الخارجي
    }
    return false;
  }

  /// تفعيل التطبيق باستخدام ID واسم المستخدم
  Future<bool> activateApp(String licenseKey, String username) async {
    
    bool isValid = await _validationService.validateLicenseKey(licenseKey);
    
    if (isValid && username.trim().isNotEmpty) {
      await _storage.write(key: _keyIsActivated, value: 'true');
      await _storage.write(key: _keyUsername, value: username);
      return true;
    }
    
    return false;
  }

  /// التحقق من صلاحية ID واسم المستخدم
  Future<bool> validateId(String username, String licenseKey) async {
    return await activateApp(licenseKey, username);
  }

  /// فحص حالة التطبيق: activated, trial, expired
  Future<String> checkAppStatus() async {
    // 1. التحقق من التفعيل المسبق
    String? isActivated = await _storage.read(key: _keyIsActivated);
    if (isActivated == 'true') {
      return 'activated';
    }

    // 2. التحقق من تثبيت سابق (لمنع إعادة الفترة التجريبية)
    bool hadPreviousInstall = await _checkPreviousInstall();
    
    if (hadPreviousInstall) {
      String? firstLaunchStr = await _storage.read(key: _keyFirstLaunch);
      if (firstLaunchStr == null) {
        return 'expired';
      }
    }

    // 3. الحصول على الوقت الآمن
    DateTime now = await _getSecureTime();
    String? firstLaunchStr = await _storage.read(key: _keyFirstLaunch);

    // 4. إذا كان أول تشغيل، احفظ الوقت
    if (firstLaunchStr == null) {
      await _storage.write(key: _keyFirstLaunch, value: now.toIso8601String());
      return 'trial';
    }

    // 5. حساب الوقت المنقضي منذ أول تشغيل
    DateTime firstLaunch = DateTime.parse(firstLaunchStr);
    
    // منع التلاعب بالوقت للخلف
    if (now.isBefore(firstLaunch)) {
      return 'expired';
    }
    
    // حساب عدد الساعات المنقضية
    int hoursPassed = now.difference(firstLaunch).inHours;
    
    // الفترة التجريبية: 24 ساعة كاملة
    if (hoursPassed < 24) { 
      return 'trial'; 
    } else {
      return 'expired';
    }
  }

  /// الحصول على اسم المستخدم المحفوظ
  Future<String?> getUsername() async {
    return await _storage.read(key: _keyUsername);
  }

  /// الحصول على الوقت المتبقي في الفترة التجريبية (بالساعات)
  Future<int> getRemainingTrialHours() async {
    String? firstLaunchStr = await _storage.read(key: _keyFirstLaunch);
    if (firstLaunchStr == null) return 24;

    DateTime firstLaunch = DateTime.parse(firstLaunchStr);
    DateTime now = await _getSecureTime();
    
    int hoursPassed = now.difference(firstLaunch).inHours;
    int remaining = 24 - hoursPassed;
    
    return remaining > 0 ? remaining : 0;
  }

  /// إعادة تعيين الفترة التجريبية (للاختبار فقط - احذفها في الإصدار النهائي)
  Future<void> resetTrial() async {
    await _storage.delete(key: _keyFirstLaunch);
    await _storage.delete(key: _keyIsActivated);
    await _storage.delete(key: _keyUsername);
  }
}
