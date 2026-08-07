import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_config.dart';
import 'device_token_service.dart';
import 'sanctum_token_service.dart';

/// Registers the FCM device token with the backend via the dedicated REST
/// endpoint from the push-notifications integration doc — this is a plain
/// REST call (NOT GraphQL), authenticated with the Sanctum token (obtained
/// separately from the JWT via `updateAccount`, see `AuthRepository.fetchSanctumToken`).
///
/// `POST {origin}/api/v1/customer/fcm-token`
/// `Authorization: Bearer <Sanctum token>`
/// `{ "fcm_token": "...", "device_type": "android" | "ios" }`
///
/// Deliberately sends ONLY the headers the doc specifies — no X-CHANNEL/
/// X-LOCALE/X-CURRENCY — since unrelated extra headers have previously
/// caused this backend to 500 on other endpoints (see graphql_client.dart).
class FcmRegistrationService {
  FcmRegistrationService._();

  static const Duration _timeout = Duration(seconds: 20);

  /// Sends [fcmToken] to the backend using [sanctumToken] for auth.
  /// Returns true only on an explicit `{"success": true}` response.
  static Future<bool> register({
    required String sanctumToken,
    required String fcmToken,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.origin}/api/v1/customer/fcm-token');
      debugPrint('📮 Registering FCM token with backend: $uri');

      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $sanctumToken',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'fcm_token': fcmToken,
              'device_type': Platform.isIOS ? 'ios' : 'android',
            }),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '⚠️ FCM token registration failed: HTTP ${response.statusCode} — ${response.body}',
        );
        return false;
      }

      final decoded = jsonDecode(response.body);
      final success = decoded is Map && decoded['success'] == true;
      debugPrint(
        success
            ? '✅ FCM token registered with backend'
            : '⚠️ FCM token registration responded without success: ${response.body}',
      );
      return success;
    } catch (e) {
      debugPrint('❌ FCM token registration error: $e');
      return false;
    }
  }

  /// Registers the currently-stored FCM device token, but only when BOTH a
  /// Sanctum token (user is logged in) and an FCM token (Firebase issued
  /// one) are already available — silently does nothing otherwise.
  ///
  /// Meant to be called opportunistically and non-fatally from multiple
  /// places (right after login, right after `updateAccount`, and on every
  /// `onTokenRefresh`) without each caller having to check preconditions.
  static Future<void> syncIfPossible() async {
    final sanctumToken = await SanctumTokenService.getToken();
    if (sanctumToken == null || sanctumToken.isEmpty) {
      debugPrint(
        'ℹ️ FCM sync skipped — no Sanctum token yet (user not logged in?)',
      );
      return;
    }

    final fcmToken = await DeviceTokenService.getDeviceToken();
    if (fcmToken == null || fcmToken.isEmpty) {
      debugPrint('ℹ️ FCM sync skipped — no FCM device token yet');
      return;
    }

    await register(sanctumToken: sanctumToken, fcmToken: fcmToken);
  }
}
