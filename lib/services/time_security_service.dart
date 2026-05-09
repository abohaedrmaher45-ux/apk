// lib/services/time_security_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class TimeSecurityService {
  // ✅ استخدام SharedPreferences
  
  static const String _keyLastVerifiedTime = 'last_verified_time';
  static const String _keyTimeOffset = 'time_offset';
  static const String _keyFirstLaunch = 'first_launch_time';
  static const String _keyLastServerTime = 'last_server_time';
  static const String _keyTrialStartTime = 'trial_start_time';
  
  static const int _allowedDeviation = 60;
  static const int _trialMinutes = 15; // 7 ساعات

  Future<DateTime?> getSecureTime() async {
    DateTime? serverTime = await _getServerTime();
    if (serverTime != null) {
      await _saveSecureTime(serverTime);
      return serverTime;
    }
    return await _getVerifiedLocalTime();
  }

  Future<DateTime?> _getServerTime() async {
    try {
      final response = await http.get(
        Uri.parse('https://worldtimeapi.org/api/timezone/Asia/Riyadh'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final datetimeStr = data['datetime'];
        return DateTime.parse(datetimeStr).toLocal();
      }
    } catch (e) {
      print('❌ فشل الاتصال بالسيرفر: $e');
    }
    return null;
  }

  Future<DateTime?> _getVerifiedLocalTime() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    
    final lastTimeStr = prefs.getString(_keyLastVerifiedTime);
    final lastOffsetStr = prefs.getString(_keyTimeOffset);
    
    if (lastTimeStr == null || lastOffsetStr == null) {
      await _saveSecureTime(now);
      return now;
    }
    
    final lastTime = DateTime.parse(lastTimeStr);
    final difference = now.difference(lastTime).inSeconds;
    
    if (difference < -_allowedDeviation) {
      print('⚠️ تحذير: تم اكتشاف تلاعب بالوقت!');
      return null;
    }
    
    await _saveSecureTime(now);
    return now;
  }

  Future<void> _saveSecureTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastVerifiedTime, time.toIso8601String());
    await prefs.setString(_keyTimeOffset, time.timeZoneOffset.inSeconds.toString());
  }

  Future<bool> isTrialValid() async {
    bool isManipulated = await isTimeManipulated();
    if (isManipulated) {
      await terminateTrialDueToTampering();
      return false;
    }
    
    final prefs = await SharedPreferences.getInstance();
    String? trialStartStr = prefs.getString(_keyTrialStartTime);
    
    if (trialStartStr == null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await prefs.setString(_keyTrialStartTime, now.toString());
      return true;
    }
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final startTime = int.parse(trialStartStr);
    final elapsed = now - startTime;
    
    print('⏱️ الوقت المنقضي: $elapsed ثانية (${elapsed / 60} دقيقة)');
    
    return elapsed < (_trialMinutes * 60);
  }

  Future<Duration> getRemainingTrialTime() async {
    bool isManipulated = await isTimeManipulated();
    if (isManipulated) {
      await terminateTrialDueToTampering();
      return Duration.zero;
    }
    
    final prefs = await SharedPreferences.getInstance();
    String? trialStartStr = prefs.getString(_keyTrialStartTime);
    
    if (trialStartStr == null) {
      return Duration(minutes: _trialMinutes);
    }
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final startTime = int.parse(trialStartStr);
    final elapsed = now - startTime;
    final remainingSeconds = (_trialMinutes * 60) - elapsed;
    
    return remainingSeconds > 0 ? Duration(seconds: remainingSeconds) : Duration.zero;
  }

  Future<bool> isTimeManipulated() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVerifiedStr = prefs.getString(_keyLastVerifiedTime);
    final lastOffsetStr = prefs.getString(_keyTimeOffset);
    
    if (lastVerifiedStr == null || lastOffsetStr == null) {
      return false;
    }
    
    final lastVerified = DateTime.parse(lastVerifiedStr);
    final now = DateTime.now();
    
    if (now.isBefore(lastVerified)) {
      print('⚠️ تم اكتشاف تلاعب بالوقت!');
      return true;
    }
    
    final difference = now.difference(lastVerified).inMinutes;
    if (difference > 10) {
      print('⚠️ فارق زمني كبير جداً: $difference دقيقة');
      return true;
    }
    
    return false;
  }

  Future<void> terminateTrialDueToTampering() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTrialStartTime);
    await prefs.remove(_keyFirstLaunch);
    await prefs.remove(_keyLastVerifiedTime);
    await prefs.remove(_keyTimeOffset);
    await prefs.setBool('trial_expired', true);
    await prefs.setBool('time_tampered', true);
    
    print('✅ تم إنهاء الفترة التجريبية بسبب التلاعب بالوقت');
  }

  Future<bool> wasTimeTampered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('time_tampered') ?? false;
  }

  Future<void> resetTrial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTrialStartTime);
    await prefs.remove(_keyFirstLaunch);
    await prefs.remove(_keyLastVerifiedTime);
    await prefs.remove(_keyTimeOffset);
    await prefs.remove('trial_expired');
    await prefs.remove('time_tampered');
    
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await prefs.setString(_keyTrialStartTime, now.toString());
    await _saveSecureTime(DateTime.now());
    
    print('✅ تم إعادة تعيين الفترة التجريبية');
  }

  Future<void> recordAccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_access_time', DateTime.now().toIso8601String());
  }

  Future<void> clearAllTimeData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastVerifiedTime);
    await prefs.remove(_keyTimeOffset);
    await prefs.remove(_keyFirstLaunch);
    await prefs.remove(_keyLastServerTime);
    await prefs.remove(_keyTrialStartTime);
    await prefs.remove('last_access_time');
    await prefs.remove('trial_expired');
    await prefs.remove('time_tampered');
    
    print('✅ تم مسح جميع بيانات الوقت');
  }
}