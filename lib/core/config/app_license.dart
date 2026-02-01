/// ملف تكوين الترخيص - قم بتغيير UNIQUE_LICENSE_ID لكل نسخة
/// 
/// ⚠️ هذا هو المعرف الفريد لكل عميل - قم بتغييره قبل كل build
/// 
/// مثال:
/// - العميل 1: 'MAHER_CLIENT_001_XK9P2LMN4R7'
/// - العميل 2: 'MAHER_CLIENT_002_WQ5T8HJV3M1'
/// - العميل 3: 'MAHER_CLIENT_003_ZC6Y1NDP9K4'

class AppLicense {
  /// 🔑 المعرف الفريد للترخيص - غيّر هذا القيمة لكل عميل
  /// 
  /// تنسيق مقترح: MAHER_CLIENT_XXX_[RANDOM_10_CHARS]
  /// حيث XXX هو رقم العميل و RANDOM_10_CHARS أحرف عشوائية
  static const String UNIQUE_LICENSE_ID = 'MAHER_CLIENT_001_XK9P2LMN4R7';
  
  /// تاريخ إصدار الترخيص (اختياري)
  static const String ISSUE_DATE = '2025-01-19';
  
  /// اسم العميل (اختياري - للتتبع الداخلي فقط)
  static const String CLIENT_NAME = 'Client_001';
  
  /// رقم إصدار التطبيق
  static const String APP_VERSION = '1.0.0';
  
  /// معرف التطبيق الفريد (لا تغيّره)
  static const String APP_ID = 'com.maher.maherkh';
  
  /// مفتاح التشفير الرئيسي (لا تغيّره - يستخدم للتحقق)
  static const String _MASTER_KEY = 'MAHERKH_2025_SECURE_APP_MASTER';
  
  /// الحصول على المفتاح المشفر الكامل
  static String get encryptedKey {
    return _generateEncryptedKey(UNIQUE_LICENSE_ID, _MASTER_KEY);
  }
  
  /// توليد مفتاح مشفر للتحقق
  static String _generateEncryptedKey(String licenseId, String masterKey) {
    final combined = '$licenseId:$masterKey:$APP_ID';
    int hash = 0;
    for (int i = 0; i < combined.length; i++) {
      hash = ((hash << 5) - hash) + combined.codeUnitAt(i);
      hash = hash & hash; // Convert to 32bit integer
    }
    return hash.abs().toRadixString(36).toUpperCase();
  }
  
  /// التحقق من صحة الترخيص
  static bool validateLicense() {
    // التحقق من أن المعرف ليس فارغاً
    if (UNIQUE_LICENSE_ID.isEmpty || UNIQUE_LICENSE_ID == 'CHANGE_ME') {
      return false;
    }
    
    // التحقق من تنسيق المعرف
    if (!UNIQUE_LICENSE_ID.startsWith('MAHER_CLIENT_')) {
      return false;
    }
    
    // التحقق من طول المعرف (يجب أن يكون طويل بما يكفي)
    if (UNIQUE_LICENSE_ID.length < 20) {
      return false;
    }
    
    return true;
  }
  
  /// الحصول على معلومات الترخيص
  static Map<String, String> getLicenseInfo() {
    return {
      'license_id': UNIQUE_LICENSE_ID,
      'issue_date': ISSUE_DATE,
      'client_name': CLIENT_NAME,
      'app_version': APP_VERSION,
      'app_id': APP_ID,
      'encrypted_key': encryptedKey,
    };
  }
}
