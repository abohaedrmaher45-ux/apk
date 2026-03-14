import 'package:ntp/ntp.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TimeSecurityService {
  final _storage = FlutterSecureStorage();
  final _keyLastKnownTime = 'last_known_secure_time';

  Future<DateTime?> getSecureTime() async {
    try {
      DateTime ntpTime = await NTP.now();
      await _storage.write(key: _keyLastKnownTime, value: ntpTime.toIso8601String());
      return ntpTime;
    } catch (e) {
      return await _getFallbackTime();
    }
  }

  Future<DateTime?> _getFallbackTime() async {
    DateTime localTime = DateTime.now();
    String? lastKnownStr = await _storage.read(key: _keyLastKnownTime);

    if (lastKnownStr != null) {
      DateTime lastKnownTime = DateTime.parse(lastKnownStr);
      if (localTime.isBefore(lastKnownTime)) {
        return lastKnownTime;
      }
    }
    
    return localTime;
  }
}