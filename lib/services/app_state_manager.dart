// lib/services/app_state_manager.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'time_security_service.dart';
import 'validation_service.dart';

class AppStateManager {
  final TimeSecurityService _timeService = TimeSecurityService();
  final ValidationService _validationService = ValidationService();
  final _storage = FlutterSecureStorage();

  // مفاتيح التخزين
  final _keyFirstLaunch = 'first_launch_date_secure';
  final _keyIsActivated = 'is_activated_final';

  /// يعيد الحالة الحالية للتطبيق: trial, expired, activated, error
  Future<String> getAppStatus() async {
    // 1. التحقق إذا كان مفعل مسبقاً
    String? isActivated = await _storage.read(key: _keyIsActivated);
    if (isActivated == 'true') return 'activated';

    // 2. جلب الوقت الآمن (مضاد للتلاعب)
    DateTime? secureTime = await _timeService.getSecureTime();
    
    // في حال لم نستطع تحديد الوقت (لا إنترنت ولا بيانات محفوظة سابقة)
    // نطلب من المستخدم فحص الاتصال (أو نسمح له بالدخول مؤقتاً حسب سياستك)
    if (secureTime == null) return 'error_network'; 

    // 3. التحقق من تاريخ أول تشغيل
    String? firstLaunchStr = await _storage.read(key: _keyFirstLaunch);
    
    if (firstLaunchStr == null) {
      // أول تشغيل: تسجيل الوقت الآمن
      await _storage.write(key: _keyFirstLaunch, value: secureTime.toIso8601String());
      return 'trial';
    }

    DateTime firstLaunch = DateTime.parse(firstLaunchStr);
    
    // نحسب الفرق بالأيام
    // ملاحظة: لحساب 7 أيام بدقة، نستخدم الفرق بالثواني ونقسمه
    int daysPassed = secureTime.difference(firstLaunch).inDays;

    if (daysPassed < 7) {
      return 'trial';
    } else {
      return 'expired';
    }
  }

  /// تفعيل التطبيق باستخدام الكود
  Future<bool> activateApp(String inputId, String username) async {
    bool isValid = await _validationService.validateLicenseKey(inputId);
    
    if (isValid) {
      await _storage.write(key: _keyIsActivated, value: 'true');
      // يمكنك حفظ اسم المستخدم هنا إذا أردت
      return true;
    }
    return false;
  }
}