import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ntp/ntp.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
// بقية الاستيرادات...

class LicenseService {
  final _storage = FlutterSecureStorage();
  
  // ... (المتغيرات السابقة: keys, secretKey) ...
  
  // اسم الملف المخفي (اجعل الاسم غامضاً ولا يدل على التطبيق)
  final String _hiddenFileName = ".sys_config_cache"; 

  // --- دالة جديدة: التحقق من وجود ملف التثبيت القديم ---
  Future<bool> _checkPreviousInstall() async {
    try {
      // 1. طلب إذن التخزين
      // في الأندرويد 11+ نحتاج صلاحيات خاصة
      if (await Permission.manageExternalStorage.request().isGranted || 
          await Permission.storage.request().isGranted) {
        
        // 2. الوصول لمجلد التخزين الخارجي (الجذر)
        Directory? externalDir = Directory('/storage/emulated/0');
        
        if (await externalDir.exists()) {
          File hiddenFile = File('${externalDir.path}/${_hiddenFileName}');
          
          // 3. التحقق إذا كان الملف موجوداً
          if (await hiddenFile.exists()) {
            return true; // تم العثور على تثبيت سابق
          } else {
            // 4. إنشاء الملف لأول مرة (تسجيل التثبيت)
            DateTime now = await _getSecureTime();
            await hiddenFile.writeAsString(now.toIso8601String());
            return false; // تثبيت جديد
          }
        }
      }
    } catch (e) {
      print("Error checking hidden file: $e");
      // في حالة حدوث خطأ (مثل رفض الإذن)، من الأفضل عدم حجب التطبيق
      // ويمكنك هنا تفعيل منطق بديل (مثل الاعتماد على SecureStorage فقط)
    }
    return false;
  }

  // --- تحديث دالة التحقق الرئيسية ---
  Future<String> checkAppStatus() async {
    // 1. التحقق من التفعيل الكامل
    String? isActivated = await _storage.read(key: _keyIsActivated);
    if (isActivated == 'true') return 'activated';

    // 2. التحقق من إعادة التثبيت (الجديد)
    bool hadPreviousInstall = await _checkPreviousInstall();
    
    // إذا وجدنا ملفاً قديماً، ولكن SecureStorage فارغة
    // فهذا يعني أن المستخدم حذف التطبيق وأعاد تثبيته لالتفاف التجربة
    if (hadPreviousInstall) {
      // نتحقق مما إذا كان هناك تاريخ في SecureStorage
      String? firstLaunchStr = await _storage.read(key: _keyFirstLaunch);
      if (firstLaunchStr == null) {
        // هذه محاولة غش! نمنع التجربة فوراً.
        return 'expired'; 
      }
    }

    // 3. منطق الوقت والـ NTP (الذي كتبناه سابقاً)
    DateTime now = await _getSecureTime();
    String? firstLaunchStr = await _storage.read(key: _keyFirstLaunch);

    if (firstLaunchStr == null) {
      // تسجيل أول مرة في SecureStorage
      await _storage.write(key: _keyFirstLaunch, value: now.toIso8601String());
      return 'trial';
    }

    DateTime firstLaunch = DateTime.parse(firstLaunchStr);
    if (now.isBefore(firstLaunch)) return 'expired'; // محاولة تغيير الوقت
// لحساب الفرق بالساعات
int hoursPassed = now.difference(firstLaunch).inHours;

// الشرط الجديد: إذا مرت ساعة واحدة أو أكثر -> انتهت التجربة
if (hoursPassed < 1) { 
  return 'trial'; 
} else {
  return 'expired';
}
  }
  
  // ... (بقية الدوال: getSecureTime, validateId, activateApp) ...
}