import 'package:ntp/ntp.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class TimeSecurityService {
  final _storage = FlutterSecureStorage();
  final _keyLastKnownTime = 'last_known_secure_time';

  /// يجلب الوقت الحالي بشكل آمن
  Future<DateTime?> getSecureTime() async {
    try {
      // 1. محاولة جلب الوقت من خادم NTP (يتطلب إنترنت)
      DateTime ntpTime = await NTP.now();
      
      // حفظ هذا الوقت كمرجع للاستخدام المستقبلي (في حالة انقطاع النت)
      await _storage.write(key: _keyLastKnownTime, value: ntpTime.toIso8601String());
      
      return ntpTime;
    } catch (e) {
      // 2. في حالة عدم وجود إنترنت، نستخدم الاستراتيجية البديلة
      return await _getFallbackTime();
    }
  }

  /// استراتيجية بديلة عند فقدان الإنترنت
  Future<DateTime?> _getFallbackTime() async {
    DateTime localTime = DateTime.now();
    String? lastKnownStr = await _storage.read(key: _keyLastKnownTime);

    if (lastKnownStr != null) {
      DateTime lastKnownTime = DateTime.parse(lastKnownStr);

      // التحقق: هل قام المستخدم بتغيير تاريخ الجهاز للخلف؟
      if (localTime.isBefore(lastKnownTime)) {
        // المستخدم غشاش! قام بارجاع التاريخ للخلف
        // نقوم بإرجاع آخر وقت آمن تم تسجيله لمنع التلاعب
        return lastKnownTime; 
      }
    }
    
    // إذا كان التاريخ المحلي منطقياً (أحدث من آخر تاريخ مسجل)
    return localTime;
  }
}