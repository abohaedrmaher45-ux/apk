import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/graphql/graphql_client.dart';
import '../../../../core/graphql/auth_mutations.dart';
import '../../../../core/notifications/device_token_service.dart';
import '../../../../core/notifications/sanctum_token_service.dart';
import '../models/auth_models.dart';

/// Repository for authentication API calls via GraphQL.
/// Matches Bagisto API: createCustomerLogin, createCustomer,
/// createForgotPassword, createLogout.
/// Also handles FCM device token management.
class AuthRepository {
  final GraphQLClient client;

  AuthRepository({required this.client});

  /// Login with email + password
  /// Returns [CustomerLogin] with token on success.
  /// Automatically includes FCM device token in the request if available.
  Future<CustomerLogin> login({
    required String email,
    required String password,
    String? deviceToken,
  }) async {
    debugPrint('🔐 AuthRepo.login — email: $email');

    // The Bagisto backend (per its own API collection) expects `deviceToken`
    // and `deviceName` and persists them on the `customers` table. If login
    // fails with: SQLSTATE[42S22] Unknown column 'device_token', the
    // `device_token` / `device_name` columns are MISSING from your database —
    // this is a BACKEND migration issue, not a frontend one. Run the Mobikul /
    // push-notification migration on the server to add those columns.
    final token = deviceToken ?? await DeviceTokenService.getDeviceToken();

    final result = await client.mutate(
      MutationOptions(
        document: gql(loginMutation),
        variables: {
          'input': {
            'email': email,
            'password': password,
            'remember': true,
            if (token != null && token.isNotEmpty) 'deviceToken': token,
            if (token != null && token.isNotEmpty) 'deviceName': 'flutter-app',
          },
        },
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🔐 AuthRepo.login — exception: $message');
      throw AuthException(message);
    }

    debugPrint('🔐 AuthRepo.login — raw data: ${result.data}');

    final data = result.data?['customerLogin'];
    if (data == null) {
      debugPrint('🔐 AuthRepo.login — customerLogin is null');
      throw AuthException('Invalid response from server');
    }

    final loginResult = CustomerLogin.fromJson(data);
    if (!loginResult.success) {
      throw AuthException(loginResult.message ?? 'Login failed');
    }

    debugPrint(
      '🔐 AuthRepo.login — success, token: ${loginResult.token?.substring(0, 10)}...',
    );
    return loginResult;
  }

  /// Register a new customer.
  /// Matches Bagisto API: firstName, lastName, email, password, confirmPassword
  /// Automatically includes FCM device token in the request if available.
  Future<Customer> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmPassword,
    String? deviceToken,
  }) async {
    debugPrint('📝 AuthRepo.register — $firstName $lastName <$email>');

    // See note in login(): the backend expects deviceToken/deviceName. A
    // missing `device_token` column error is a backend migration issue.
    final token = deviceToken ?? await DeviceTokenService.getDeviceToken();

    final result = await client.mutate(
      MutationOptions(
        document: gql(registerMutation),
        variables: {
          'input': {
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
            'password': password,
            'passwordConfirmation': confirmPassword,
            'agreement': true,
            'subscribedToNewsLetter': true,
            if (token != null && token.isNotEmpty) 'deviceToken': token,
            if (token != null && token.isNotEmpty) 'deviceName': 'flutter-app',
          },
        },
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('📝 AuthRepo.register — exception: $message');
      throw AuthException(message);
    }

    debugPrint('📝 AuthRepo.register — raw data: ${result.data}');

    final signUp = result.data?['customerSignUp'];
    if (signUp == null) {
      debugPrint('📝 AuthRepo.register — customerSignUp is null in response');
      throw AuthException('Invalid response from server');
    }

    // إذا كان تفعيل البريد مفعّلاً في Bagisto، يرجع success=false مع رسالة
    final success = signUp['success'] as bool? ?? false;
    if (!success) {
      throw AuthException(
        (signUp['message'] as String?) ?? 'Registration failed',
      );
    }

    final data = signUp['customer'] as Map<String, dynamic>?;
    if (data == null) {
      throw AuthException('Invalid response from server');
    }

    // التوكن يأتي على المستوى الأعلى (accessToken)، وليس داخل customer
    final customer = Customer.fromJson({
      ...data,
      'token': signUp['accessToken'],
      'apiToken': signUp['accessToken'],
    });
    debugPrint(
      '📝 AuthRepo.register — success: ${customer.displayName}, token: ${customer.token}',
    );
    return customer;
  }

  /// Fetches the Sanctum token used by REST endpoints (distinct from the
  /// JWT `login()` returns) — see the push-notifications integration doc.
  /// Relies on `client` being authenticated: the shared client re-reads the
  /// just-persisted JWT from storage on every request (see
  /// GraphQLClientProvider.client), so this works right after `login()`
  /// saves its token, with no need to pass it explicitly.
  /// Returns null on any failure — this is a best-effort side flow and must
  /// never block the login/registration flow that calls it.
  Future<String?> fetchSanctumToken() async {
    try {
      final result = await client.mutate(
        MutationOptions(
          document: gql(fetchSanctumTokenMutation),
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
        debugPrint(
          '🔐 AuthRepo.fetchSanctumToken — exception: ${result.exception}',
        );
        return null;
      }

      final data = result.data?['issueDeviceApiToken'];
      if (data == null || data['success'] != true) {
        debugPrint(
          '🔐 AuthRepo.fetchSanctumToken — unsuccessful: ${data?['message']}',
        );
        return null;
      }

      debugPrint('🔐 AuthRepo.fetchSanctumToken — obtained Sanctum token');
      return data['accessToken'] as String?;
    } catch (e) {
      debugPrint('🔐 AuthRepo.fetchSanctumToken — error: $e');
      return null;
    }
  }

  /// Send forgot-password email
  Future<String> forgotPassword({required String email}) async {
    final result = await client.mutate(
      MutationOptions(
        document: gql(forgotPasswordMutation),
        variables: {'email': email},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      throw AuthException(message);
    }

    final data = result.data?['forgotPassword'];
    if (data == null) {
      throw AuthException('Invalid response from server');
    }
    final success = data['success'] as bool? ?? false;
    final message = data['message'] as String? ?? '';

    if (!success) {
      throw AuthException(message.isNotEmpty ? message : 'Request failed');
    }

    return message;
  }

  /// Logout (requires authenticated client)
  /// Sends device token to API for cleanup.
  /// Clears device token from local storage after logout.
  Future<bool> logout() async {
    try {
      final result = await client.mutate(
        MutationOptions(
          document: gql(logoutMutation),
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
        final message = _extractErrorMessage(result.exception!);
        throw AuthException(message);
      }

      final data = result.data?['customerLogout'];

      // Clear device token and Sanctum token on logout
      await DeviceTokenService.clearDeviceToken();
      await SanctumTokenService.clearToken();
      debugPrint('🔐 AuthRepo.logout — success, device/Sanctum tokens cleared locally');

      return data?['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('❌ AuthRepo.logout — error: $e');
      // Still clear tokens even if logout API fails
      await DeviceTokenService.clearDeviceToken();
      await SanctumTokenService.clearToken();
      rethrow;
    }
  }

  /// Validate the token by fetching the customer profile.
  /// Returns true if token is valid, false otherwise.
  Future<bool> validateToken(String token) async {
    debugPrint('🔐 AuthRepo.validateToken — checking token validity');
    final authClient = GraphQLClientProvider.authenticatedClient(token);
    try {
      final result = await authClient.value.query(
        QueryOptions(
          document: gql(r'''
            query validateToken {
              accountInfo {
                id
              }
            }
          '''),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        debugPrint('🔐 AuthRepo.validateToken — exception: ${result.exception}');
        if (ErrorMapper.isNetworkError(result.exception!)) {
          throw result.exception!;
        }
        return false;
      }

      final data = result.data?['accountInfo'];
      final isValid = data != null;
      debugPrint('🔐 AuthRepo.validateToken — is valid: $isValid');
      return isValid;
    } catch (e) {
      debugPrint('🔐 AuthRepo.validateToken — error: $e');
      if (e is OperationException || e is Exception) {
        // If it's a known network/connection issue, propagate it
        if (ErrorMapper.isNetworkError(e)) {
          rethrow;
        }
      }
      return false;
    }
  }

  /// Extract a readable error message from GraphQL exceptions
  String _extractErrorMessage(OperationException exception) {
    return ErrorMapper.getUserMessage(exception);
  }
}

/// Custom exception for auth errors
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
