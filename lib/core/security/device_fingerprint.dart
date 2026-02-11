import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// نظام بصمة الجهاز - لربط التطبيق بجهاز محدد
class DeviceFingerprint {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  /// الحصول على بصمة فريدة للجهاز
  static Future<String> getDeviceFingerprint() async {
    try {
      String fingerprint = '';
      
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        
        // جمع معلومات فريدة عن الجهاز
        final deviceData = {
          'id': androidInfo.id,
          'device': androidInfo.device,
          'model': androidInfo.model,
          'product': androidInfo.product,
          'hardware': androidInfo.hardware,
          'manufacturer': androidInfo.manufacturer,
          'brand': androidInfo.brand,
          'androidId': androidInfo.id, // Android ID
        };
        
        fingerprint = _hashDeviceData(deviceData);
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        
        final deviceData = {
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'model': iosInfo.model,
          'identifierForVendor': iosInfo.identifierForVendor ?? '',
        };
        
        fingerprint = _hashDeviceData(deviceData);
      }
      
      return fingerprint;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting device fingerprint: $e');
      }
      return '';
    }
  }
  
  /// تشفير بيانات الجهاز لإنشاء بصمة فريدة
  static String _hashDeviceData(Map<String, dynamic> data) {
    final jsonString = json.encode(data);
    final bytes = utf8.encode(jsonString);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
  
  /// التحقق من بصمة الجهاز
  static Future<bool> verifyDeviceFingerprint(String storedFingerprint) async {
    if (storedFingerprint.isEmpty) {
      return true; // التشغيل الأول
    }
    
    final currentFingerprint = await getDeviceFingerprint();
    return currentFingerprint == storedFingerprint;
  }
  
  /// الحصول على معلومات الجهاز للعرض
  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'Device': androidInfo.device,
          'Model': androidInfo.model,
          'Manufacturer': androidInfo.manufacturer,
          'Android Version': androidInfo.version.release,
          'SDK': androidInfo.version.sdkInt.toString(),
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'Device': iosInfo.name,
          'Model': iosInfo.model,
          'System': iosInfo.systemName,
          'Version': iosInfo.systemVersion,
        };
      }
      return {};
    } catch (e) {
      return {'Error': 'Unable to get device info'};
    }
  }
}
