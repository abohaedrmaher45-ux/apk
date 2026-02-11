/// 🔑 ملف تكوين الترخيص - غيّره لكل عميل
class AppLicense {
  // ⚠️ هذا المعرف الفريد - غيّره لكل نسخة!
  static const String UNIQUE_LICENSE_ID = 'MAHER_CLIENT_001_XK9P2LMN4R7';
  
  // 📅 تاريخ الإصدار
  static const String ISSUE_DATE = '2025-01-19';
  
  // 👤 اسم العميل (اختياري)
  static const String CLIENT_NAME = 'متجر أحمد';
  
  // 📱 إصدار التطبيق
  static const String APP_VERSION = '1.0.0';
  
  // 🆔 معرف التطبيق
  static const String APP_ID = 'com.maher.maherkh';
  
  // 🔐 مفتاح التشفير الرئيسي - لا تغيره!
  static const String _MASTER_KEY = 'MAHERKH_2025_SECURE_APP_MASTER';
  
  /// ✅ التحقق من صحة الترخيص
  static bool validateLicense() {
    // 1. التأكد من أنه ليس فارغاً
    if (UNIQUE_LICENSE_ID.isEmpty || UNIQUE_LICENSE_ID == 'CHANGE_ME') {
      return false;
    }
    
    // 2. التأكد من التنسيق الصحيح
    if (!UNIQUE_LICENSE_ID.startsWith('MAHER_CLIENT_')) {
      return false;
    }
    
    // 3. التأكد من الطول (يجب أن يكون 30 حرف على الأقل)
    if (UNIQUE_LICENSE_ID.length < 30) {
      return false;
    }
    
    return true;
  }
  
  /// ℹ️ معلومات الترخيص
  static Map<String, String> getLicenseInfo() {
    return {
      'license_id': UNIQUE_LICENSE_ID,
      'client_name': CLIENT_NAME,
      'app_version': APP_VERSION,
      'issue_date': ISSUE_DATE,
    };
  }
}