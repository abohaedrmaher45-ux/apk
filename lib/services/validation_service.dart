import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'device_service.dart'; // استدعاء الكلاس السابق

class ValidationService {
  final DeviceService _deviceService = DeviceService();
  
  // هذا المفتاح سري جداً يجب ألا يظهر بوضوح في الكود (قم بتشفيه أو تقسيمه)
  final String _secretKey = "MySuperSecretKey2024"; 

  // التحقق من صحة الـ ID المدخل
  Future<bool> validateLicenseKey(String inputLicenseKey) async {
    String deviceId = await _deviceService.getUniqueDeviceId();
    
    // نقوم بتوليد الـ ID المتوقع بناءً على معرف الجهاز والمفتاح السري
    String expectedKey = _generateExpectedKey(deviceId);

    // المقارنة بين ما أدخله المستخدم وما يجب أن يكون عليه
    // نستخدم مقارنة آمنة لمنع توقيت الهجوم (Timing Attack) - اختياري في التطبيقات البسيطة
    return inputLicenseKey == expectedKey;
  }

  // دالة لتوليد المفتاح (استخدمها أنت كمطور لتوليد الأكواد للعملاء)
  String _generateExpectedKey(String deviceId) {
    var bytes = utf8.encode(deviceId + _secretKey);
    var digest = sha256.convert(bytes);
    
    // نأخذ أول 16 حرف لتكون قصيرة ومقروءة كمفتاح تفعيل
    return digest.toString().substring(0, 16).toUpperCase();
  }
}