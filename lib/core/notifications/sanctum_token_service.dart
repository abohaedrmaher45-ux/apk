import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage for the Sanctum access token used by REST endpoints — distinct
/// from the JWT `AuthStorage` keeps for GraphQL requests.
///
/// Per the push-notifications integration doc: after `customerLogin` (JWT),
/// the app must call `updateAccount(input: {})` to obtain a separate Sanctum
/// token, which is the one required by `POST /api/v1/customer/fcm-token`.
class SanctumTokenService {
  static const String _tokenKey = 'sanctum_token';

  /// Save the Sanctum token after it's fetched via `updateAccount`.
  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      debugPrint('💾 Sanctum token saved');
    } catch (e) {
      debugPrint('❌ Failed to save Sanctum token: $e');
    }
  }

  /// Retrieve the stored Sanctum token, or null if never fetched (e.g. user
  /// hasn't logged in since this feature was added, or is a guest).
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      debugPrint('❌ Failed to retrieve Sanctum token: $e');
      return null;
    }
  }

  /// Clear the Sanctum token (call on logout, alongside `DeviceTokenService`).
  static Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      debugPrint('🗑️ Sanctum token cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear Sanctum token: $e');
    }
  }
}
