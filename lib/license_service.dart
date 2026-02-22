import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ntp/ntp.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/time_security_service.dart';
import 'services/validation_service.dart';

class LicenseService {
  final _storage = FlutterSecureStorage();
  final TimeSecurityService _timeService = TimeSecurityService();
  final ValidationService _validationService = ValidationService();
  
  final String _keyIsActivated = 'is_activated_final';
  final String _keyFirstLaunch = 'first_launch_date_secure';
  final String _hiddenFileName = ".sys_config_cache";
  final String _secretKey = "MySuperSecretKey2024";

  Future<DateTime> _getSecureTime() async {
    final time = await _timeService.getSecureTime();
    return time ?? DateTime.now();
  }

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
      print("Error checking hidden file: $e");
    }
    return false;
  }

  // ✅ دالة التفعيل المعدلة - تستقبل معاملين كما يطلب main.dart
  Future<bool> activateApp(String licenseKey, String username) async {
    print('محاولة تفعيل للمستخدم: $username بالمفتاح: $licenseKey');
    
    bool isValid = await _validationService.validateLicenseKey(licenseKey);
    
    if (isValid) {
      await _storage.write(key: _keyIsActivated, value: 'true');
      await _storage.write(key: 'username', value: username);
      print('✅ تم التفعيل بنجاح للمستخدم: $username');
    } else {
      print('❌ فشل التفعيل - مفتاح غير صالح');
    }
    
    return isValid;
  }

  // ✅ دالة validateId - تستخدمها main.dart أيضاً
  Future<bool> validateId(String username, String licenseKey) async {
    return await activateApp(licenseKey, username);  // إعادة استخدام نفس المنطق
  }

  Future<String> checkAppStatus() async {
    String? isActivated = await _storage.read(key: _keyIsActivated);
    if (isActivated == 'true') return 'activated';

    bool hadPreviousInstall = await _checkPreviousInstall();
    
    if (hadPreviousInstall) {
      String? firstLaunchStr = await _storage.read(key: _keyFirstLaunch);
      if (firstLaunchStr == null) {
        return 'expired';
      }
    }

    DateTime now = await _getSecureTime();
    String? firstLaunchStr = await _storage.read(key: _keyFirstLaunch);

    if (firstLaunchStr == null) {
      await _storage.write(key: _keyFirstLaunch, value: now.toIso8601String());
      return 'trial';
    }

    DateTime firstLaunch = DateTime.parse(firstLaunchStr);
    if (now.isBefore(firstLaunch)) return 'expired';
    
    int hoursPassed = now.difference(firstLaunch).inHours;
    
    if (hoursPassed < 1) { 
      return 'trial'; 
    } else {
      return 'expired';
    }
  }
}