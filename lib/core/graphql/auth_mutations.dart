/// GraphQL mutations for authentication
/// Bagisto headless-ecommerce v2.3.2 API:
/// customerSignUp, customerLogin, forgotPassword, customerLogout

const String loginMutation = r'''
  mutation customerLogin($input: LoginInput!) {
    customerLogin(input: $input) {
      success
      message
      accessToken
      tokenType
      customer {
        id
        firstName
        lastName
        email
        phone
        status
      }
    }
  }
''';

const String registerMutation = r'''
  mutation customerSignUp($input: SignUpInput!) {
    customerSignUp(input: $input) {
      success
      message
      accessToken
      tokenType
      customer {
        id
        firstName
        lastName
        email
        phone
        status
      }
    }
  }
''';

const String forgotPasswordMutation = r'''
  mutation forgotPassword($email: String!) {
    forgotPassword(email: $email) {
      success
      message
    }
  }
''';

const String logoutMutation = r'''
  mutation customerLogout {
    customerLogout {
      success
      message
    }
  }
''';

/// Fetches a Sanctum access token — separate from the JWT [loginMutation]
/// returns — required by REST endpoints, specifically the FCM device-token
/// registration endpoint (POST /api/v1/customer/fcm-token).
///
/// NOTE: this used to be `updateAccount(input: {})`, but the backend renamed
/// it to `issueDeviceApiToken` because `updateAccount` collided with
/// Bagisto's own built-in mutation of the same name. Call/field shape is
/// otherwise unchanged. `input: {}` is inlined (no `$input` variable) since
/// we don't know — and don't need — the exact input type name.
const String fetchSanctumTokenMutation = r'''
  mutation {
    issueDeviceApiToken(input: {}) {
      success
      message
      accessToken
      tokenType
    }
  }
''';
