import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/graphql/graphql_client.dart';
import '../../../../core/graphql/checkout_queries.dart';
import '../../../../core/graphql/account_queries.dart';
import '../models/checkout_model.dart';

List<Map<String, dynamic>> buildCustomerAddressBookInputsFromCheckout(
  Map<String, dynamic> checkoutInput, {
  bool defaultAddress = false,
}) {
  final usesBillingForShipping = checkoutInput['useForShipping'] == true;
  final inputs = <Map<String, dynamic>>[
    _buildCustomerAddressBookInput(
      checkoutInput,
      prefix: 'billing',
      defaultAddress: defaultAddress,
      useForShipping: usesBillingForShipping,
    ),
  ];

  if (!usesBillingForShipping) {
    inputs.add(
      _buildCustomerAddressBookInput(
        checkoutInput,
        prefix: 'shipping',
        defaultAddress: false,
        useForShipping: true,
      ),
    );
  }

  return inputs;
}

Map<String, dynamic> _buildCustomerAddressBookInput(
  Map<String, dynamic> checkoutInput, {
  required String prefix,
  required bool defaultAddress,
  required bool useForShipping,
}) {
  // Shape must match the real `AddressInput`:
  //   address is a LIST of strings (not address1), and there is NO
  //   `useForShipping` field on AddressInput — that one belongs to
  //   CheckoutAddressInput, a different type. Sending it here made the
  //   mutation fail.
  final input = <String, dynamic>{
    'firstName': _checkoutInputValue(checkoutInput, '${prefix}FirstName'),
    'lastName': _checkoutInputValue(checkoutInput, '${prefix}LastName'),
    // `email` is non-null on AddressInput — always send it.
    'email': _checkoutInputValue(checkoutInput, '${prefix}Email'),
    'address': [_checkoutInputValue(checkoutInput, '${prefix}Address')],
    'city': _checkoutInputValue(checkoutInput, '${prefix}City'),
    'state': _checkoutInputValue(checkoutInput, '${prefix}State'),
    'country': _checkoutInputValue(checkoutInput, '${prefix}Country'),
    'postcode': _checkoutInputValue(checkoutInput, '${prefix}Postcode'),
    'phone': _checkoutInputValue(checkoutInput, '${prefix}PhoneNumber'),
    'defaultAddress': defaultAddress,
  };

  final company = _checkoutInputValue(checkoutInput, '${prefix}CompanyName');
  if (company.isNotEmpty) {
    input['companyName'] = company;
  }

  return input;
}

String _checkoutInputValue(Map<String, dynamic> checkoutInput, String key) {
  return checkoutInput[key]?.toString() ?? '';
}

bool shouldLogCheckoutOperation(String operation) {
  // Previously this hid `getCountries` responses to reduce log noise. That
  // suppression is what made the broken countries query so hard to find: the
  // request failed on every checkout open and printed nothing at all. Log it.
  return true;
}

void _logCheckoutApiDetails(
  String operation, {
  Map<String, dynamic>? variables,
  Object? responseData,
}) {
  if (!kDebugMode || !shouldLogCheckoutOperation(operation)) return;

  final encoder = const JsonEncoder.withIndent('  ');
  debugPrint('━━━━━━━━━━━━━━━━ Checkout API ━━━━━━━━━━━━━━━━');
  debugPrint('[CheckoutRepo][$operation]');
  if (variables != null) {
    debugPrint('variables=');
    debugPrint(encoder.convert(variables));
  }
  if (responseData != null) {
    debugPrint('response=');
    debugPrint(encoder.convert(responseData));
  }
  debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
}

/// Repository for all checkout operations via Bagisto GraphQL API.
///
/// IMPORTANT — Bagisto uses TWO different tokens during checkout:
///
///  1. **Auth token** (`_authToken`) — The Bearer token from login
///     (e.g. `292|63wcgHLYi...`). Sent in the `Authorization` header.
///     For guest users this is the session UUID from `createCartToken`.
///
///  2. **Cart/query token** (`_cartQueryToken`) — Returned as `cartToken`
///     by `createCheckoutAddress`. For logged-in users this equals the
///     numeric **user ID** (e.g. `"19"`). This is passed as the `$token`
///     variable to `collectionShippingRates` and `collectionPaymentMethods`.
///
/// The code MUST keep these separate.
class CheckoutRepository {
  final GraphQLClient client;

  /// Bearer token for the Authorization header.
  String? _authToken;

  /// Token passed as `$token` variable to shipping-rates / payment-methods
  /// queries. Set from the `cartToken` returned by `createCheckoutAddress`.
  String? _cartQueryToken;

  /// Shipping / payment methods returned by `saveCheckoutAddresses`.
  ///
  /// The real schema returns both lists as part of the address response, so we
  /// keep them here and let the getters reuse them instead of firing separate
  /// (non-existent) `collectionShippingRates` / `collectionPaymentMethods`
  /// queries.
  /// The app's current locale code (e.g. "ar"), used to resolve localized
  /// country / state names from Bagisto's `translations` relations.
  ///
  /// Kept as a lookup rather than a constructor arg so existing call sites
  /// don't change. `LocaleCubit.localeKey` is 'app_locale_code'.
  static Future<String?> _currentLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('app_locale_code');
      if (code != null && code.isNotEmpty) return code;
    } catch (e) {
      debugPrint('[CheckoutRepo] could not read locale: $e');
    }
    return null;
  }

  List? _cachedShippingMethods;
  List? _cachedPaymentMethods;

  /// The shipping method code chosen via `saveShipping`. Required as an
  /// argument by the standalone `paymentMethods(input:{shippingMethod:})`
  /// fallback query.
  String? _selectedShippingMethod;

  CheckoutRepository({required this.client, String? initialToken}) {
    _authToken = initialToken;
  }

  // ── Token management ────────────────────────────────────────────────────

  /// Set the Bearer auth token (login token or guest session UUID).
  void updateAuthToken(String? token) {
    _authToken = token;
    if (token == null || token.isEmpty) {
      debugPrint('[CheckoutRepo] WARNING authToken set to null/empty');
    } else {
      debugPrint(
        '[CheckoutRepo] authToken updated: ${token.length > 8 ? token.substring(0, 8) : token}…',
      );
    }
  }

  /// Set the cart query token (returned by createCheckoutAddress as `cartToken`).
  void updateCartQueryToken(String? token) {
    _cartQueryToken = token;
    debugPrint('[CheckoutRepo] cartQueryToken updated: $token');
  }

  /// Legacy helper — sets the auth token only.
  void updateToken(String? token) => updateAuthToken(token);

  /// The best cart-query token we have.
  String? get cartQueryToken => _cartQueryToken;

  GraphQLClient get _authedClient =>
      GraphQLClientProvider.buildClient(token: _authToken);

  // ─── Queries ─────────────────────────────────────────────────────────────

  /// Fetch all available countries from the Bagisto API.
  /// API: https://api-docs.bagisto.com/api/graphql-api/shop/queries/get-countries.html
  Future<List<BagistoCountry>> getCountries() async {
    final result = await _authedClient.query(
      QueryOptions(
        document: gql(CheckoutQueries.getCountries),
        // networkOnly, NOT cacheFirst: `buildClient()` creates a client with a
        // HiveStore-backed cache, so a `countries` entry written by the old
        // (broken) query — or any earlier empty result — would be replayed
        // forever and the field would stay empty and un-tappable.
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      debugPrint('[CheckoutRepo] getCountries error: ${result.exception}');
      throw result.exception!;
    }

    _logCheckoutApiDetails('getCountries', responseData: result.data);

    // `countries` is a PLAIN LIST on this schema — NOT a Relay connection.
    //
    // The old code did `result.data['countries']['edges']`, which indexes a
    // List with the String 'edges' and throws:
    //   type 'String' is not a subtype of type 'int' of 'index'
    // That exception propagated up as a *fetch failure*, so the country list
    // stayed empty and the field stayed un-tappable even though the server had
    // already returned every country correctly.
    final raw = result.data?['countries'];

    if (raw is! List) {
      debugPrint(
        '[CheckoutRepo] getCountries: expected a List but got '
        '${raw.runtimeType} — returning empty',
      );
      return [];
    }

    // Resolve localized country names against the app's current locale.
    final locale = await _currentLocale();

    final countries = raw
        .whereType<Map<String, dynamic>>()
        .map((row) => BagistoCountry.fromJson(row, locale: locale))
        .toList();

    debugPrint('[CheckoutRepo] getCountries: parsed ${countries.length}');
    return countries;
  }

  /// Fetch states/provinces for a specific country by its numeric ID.
  /// API: https://api-docs.bagisto.com/api/graphql-api/shop/queries/get-country-state.html
  /// Tries with countryId first, then falls back to countryCode if available
  Future<List<BagistoCountryState>> getCountryStates(
    int countryId, {
    String? countryCode,
  }) async {
    debugPrint(
      '[CheckoutRepo] getCountryStates countryId=$countryId, countryCode=$countryCode',
    );

    // If no valid countryId, try fallback with countryCode
    if (countryId <= 0) {
      if (countryCode != null && countryCode.isNotEmpty) {
        debugPrint(
          '[CheckoutRepo] countryId invalid, falling back to countryCode=$countryCode',
        );
        return _getCountryStatesByCode(countryCode);
      }
      debugPrint(
        '[CheckoutRepo] getCountryStates: invalid countryId=$countryId and no countryCode, returning empty',
      );
      return [];
    }

    // Query with countryId (Int! required) — do NOT pass countryCode here
    // `countrieStates` takes only a FilterCountryStateInput — there is no
    // `first` argument on this schema.
    final Map<String, dynamic> variables = {'countryId': countryId};

    final result = await _authedClient.query(
      QueryOptions(
        document: gql(CheckoutQueries.getCountryStates),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    debugPrint('[CheckoutRepo] getCountryStates raw result: ${result.data}');

    if (result.hasException) {
      debugPrint('[CheckoutRepo] getCountryStates error: ${result.exception}');
      // Fallback to countryCode query if available
      if (countryCode != null && countryCode.isNotEmpty) {
        debugPrint('[CheckoutRepo] Retrying with countryCode: $countryCode');
        return _getCountryStatesByCode(countryCode);
      }
      return [];
    }

    _logCheckoutApiDetails(
      'getCountryStates',
      variables: variables,
      responseData: result.data,
    );

    final statesData = result.data?['countrieStates'];
    if (statesData == null) {
      debugPrint('[CheckoutRepo] getCountryStates: countryStates is null');
      // Try alternative query with countryCode if available
      if (countryCode != null && countryCode.isNotEmpty && countryId <= 0) {
        debugPrint(
          '[CheckoutRepo] Trying alternative query with countryCode: $countryCode',
        );
        return _getCountryStatesByCode(countryCode);
      }
      return [];
    }

    // Handle both direct array and edges/node structures
    List<dynamic> statesList;
    if (statesData is List) {
      // Direct array format: countryStates: [{id, _id, ...}, ...]
      statesList = statesData;
      debugPrint(
        '[CheckoutRepo] getCountryStates: direct array format, ${statesList.length} items',
      );
    } else if (statesData is Map) {
      // Edge/node format: countryStates: {edges: [{node: {...}}, ...]}
      final edges = statesData['edges'] as List?;
      if (edges != null) {
        statesList = edges
            .map((edge) => edge is Map ? edge['node'] : edge)
            .where((node) => node != null)
            .toList();
        debugPrint(
          '[CheckoutRepo] getCountryStates: edge/node format, ${statesList.length} items',
        );
      } else {
        statesList = [];
        debugPrint('[CheckoutRepo] getCountryStates: edges is null');
      }
    } else {
      debugPrint(
        '[CheckoutRepo] getCountryStates: unexpected format: $statesData',
      );
      return [];
    }

    // Resolve localized state names against the app's current locale.
    final locale = await _currentLocale();

    return statesList
        .map(
          (e) => BagistoCountryState.fromJson(
            (e ?? {}) as Map<String, dynamic>,
            locale: locale,
          ),
        )
        .toList();
  }

  /// Alternative: Fetch states using country code
  Future<List<BagistoCountryState>> _getCountryStatesByCode(
    String countryCode,
  ) async {
    debugPrint(
      '[CheckoutRepo] _getCountryStatesByCode countryCode=$countryCode',
    );

    final result = await _authedClient.query(
      QueryOptions(
        document: gql(CheckoutQueries.getCountryStatesByCode),
        variables: {'countryCode': countryCode},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    debugPrint(
      '[CheckoutRepo] _getCountryStatesByCode raw result: ${result.data}',
    );

    if (result.hasException) {
      debugPrint(
        '[CheckoutRepo] _getCountryStatesByCode error: ${result.exception}',
      );
      return [];
    }

    _logCheckoutApiDetails(
      'getCountryStatesByCode',
      variables: {'countryCode': countryCode},
      responseData: result.data,
    );

    final statesData = result.data?['countrieStates'];
    if (statesData == null) {
      debugPrint(
        '[CheckoutRepo] _getCountryStatesByCode: countryStates is null',
      );
      return [];
    }

    List<dynamic> statesList;
    if (statesData is List) {
      statesList = statesData;
    } else if (statesData is Map) {
      final edges = statesData['edges'] as List?;
      if (edges != null) {
        statesList = edges
            .map((edge) => edge is Map ? edge['node'] : edge)
            .where((node) => node != null)
            .toList();
      } else {
        statesList = [];
      }
    } else {
      return [];
    }

    // Resolve localized state names against the app's current locale.
    final locale = await _currentLocale();

    return statesList
        .map(
          (e) => BagistoCountryState.fromJson(
            (e ?? {}) as Map<String, dynamic>,
            locale: locale,
          ),
        )
        .toList();
  }

  /// Fetch saved checkout addresses (cursor connection format)
  Future<List<CheckoutAddress>> getCheckoutAddresses() async {
    debugPrint('[CheckoutRepo] getCheckoutAddresses...');
    final result = await _authedClient.query(
      QueryOptions(
        document: gql(CheckoutQueries.getCheckoutAddresses),
        variables: const {'first': 50, 'page': 1},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      debugPrint(
        '[CheckoutRepo] getCheckoutAddresses error: ${result.exception}',
      );
      throw result.exception!;
    }

    _logCheckoutApiDetails('getCheckoutAddresses', responseData: result.data);

    // PAGINATOR shape: { paginatorInfo, data: [...] } — not edges/node.
    final list = result.data?['addresses']?['data'] as List?;
    if (list == null) return [];

    return list
        .whereType<Map<String, dynamic>>()
        .map(CheckoutAddress.fromJson)
        .toList();
  }

  /// Fetch customer saved addresses from account API.
  /// Used as a fallback when checkout addresses are empty for logged-in users.
  Future<List<CheckoutAddress>> getCustomerAddresses() async {
    debugPrint('[CheckoutRepo] getCustomerAddresses (fallback)...');
    final result = await _authedClient.query(
      QueryOptions(
        document: gql(AccountQueries.getCustomerAddresses),
        variables: {'first': 100, 'page': 1},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      debugPrint(
        '[CheckoutRepo] getCustomerAddresses error: ${result.exception}',
      );
      throw result.exception!;
    }

    _logCheckoutApiDetails(
      'getCustomerAddresses',
      variables: {'first': 100, 'page': 1},
      responseData: result.data,
    );

    final rows = result.data?['addresses']?['data'] as List?;
    if (rows == null) return [];

    return rows.whereType<Map<String, dynamic>>().map((node) {
      // Map account address fields to CheckoutAddress format
      // Account query returns 'address' as an array, handle both formats
      String addressStr = '';
      final rawAddr = node['address'];
      if (rawAddr is List) {
        addressStr = rawAddr.join(', ');
      } else if (rawAddr is String) {
        addressStr = rawAddr;
      } else {
        addressStr = node['address1']?.toString() ?? '';
      }

      return CheckoutAddress(
        id: node['id']?.toString() ?? '',
        addressType: node['addressType']?.toString() ?? '',
        firstName: node['firstName']?.toString() ?? '',
        lastName: node['lastName']?.toString() ?? '',
        companyName: node['companyName']?.toString(),
        address: addressStr,
        city: node['city']?.toString() ?? '',
        state: node['state']?.toString(),
        country: node['country']?.toString(),
        postcode: node['postcode']?.toString(),
        email: node['email']?.toString(),
        phone: node['phone']?.toString(),
        defaultAddress: node['defaultAddress'] == true,
        useForShipping: node['useForShipping'] == true,
      );
    }).toList();
  }

  /// Fetch available shipping rates.
  ///
  /// The `$token` query variable is the **cart query token**:
  /// - Logged-in users: their user ID (e.g. `"19"`).
  /// - Guest users: empty string `""` — the API identifies the cart via
  ///   the Bearer session UUID in the Authorization header.
  Future<List<ShippingRate>> getShippingRates({String? queryToken}) async {
    // `collectionShippingRates` does not exist on this schema. The methods are
    // returned by `saveCheckoutAddresses`, which always runs first, so read
    // them from the cache filled by saveCheckoutAddress().
    final groups = _cachedShippingMethods;

    List? resolved = groups;

    if (resolved == null) {
      // Cache cold (e.g. the address was already saved in an earlier session).
      // Fall back to the standalone query rather than showing an empty list.
      debugPrint(
        '[CheckoutRepo] getShippingRates: cache cold — querying shippingMethods',
      );

      final result = await _authedClient.query(
        QueryOptions(
          document: gql(CheckoutQueries.getShippingRates),
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
        debugPrint(
          '[CheckoutRepo] getShippingRates error: ${result.exception}',
        );
        throw result.exception!;
      }

      _logCheckoutApiDetails('getShippingRates', responseData: result.data);

      resolved = result.data?['shippingMethods']?['shippingMethods'] as List?;
      _cachedShippingMethods = resolved;
    }

    if (resolved == null) return [];
    final groupList = resolved;

    // Shape: [{ title, methods: { code, label, price, formattedPrice, ... } }]
    final rates = <ShippingRate>[];
    for (final group in groupList.whereType<Map<String, dynamic>>()) {
      final carrierTitle = group['title']?.toString();
      final methods = group['methods'];

      // `methods` is an object on this schema, but tolerate a list too.
      final entries = methods is List
          ? methods.whereType<Map<String, dynamic>>()
          : (methods is Map<String, dynamic>
                ? [methods]
                : const <Map<String, dynamic>>[]);

      for (final m in entries) {
        rates.add(
          ShippingRate(
            id: m['code']?.toString() ?? '',
            code: m['code']?.toString() ?? '',
            label: m['label']?.toString() ?? '',
            method: m['code']?.toString() ?? '',
            methodTitle: m['label']?.toString(),
            price: _toDouble(m['price']),
            formattedPrice: CurrencyFormatter.normalizeDigits(
              m['formattedPrice']?.toString(),
            ),
            basePrice: _toDouble(m['basePrice']),
            baseFormattedPrice: CurrencyFormatter.normalizeDigits(
              m['formattedBasePrice']?.toString(),
            ),
            carrierTitle: carrierTitle,
          ),
        );
      }
    }

    debugPrint('[CheckoutRepo] getShippingRates: ${rates.length} rate(s)');
    return rates;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// Fetch available payment methods.
  ///
  /// Same as shipping rates — for guests the `$token` variable is `""`,
  /// the API uses the Bearer session token to identify the cart.
  Future<List<PaymentMethod>> getPaymentMethods({String? queryToken}) async {
    // Same as shipping: `collectionPaymentMethods` does not exist. The methods
    // come back from `saveCheckoutAddresses`.
    List? list = _cachedPaymentMethods;

    if (list == null) {
      // Cache cold — fall back to the standalone query. It REQUIRES the chosen
      // shipping method, so without one there is genuinely nothing to ask for.
      final method = _selectedShippingMethod;

      if (method == null || method.isEmpty) {
        debugPrint(
          '[CheckoutRepo] getPaymentMethods: cache cold and no shipping method '
          'selected yet — nothing to query',
        );
        return [];
      }

      debugPrint(
        '[CheckoutRepo] getPaymentMethods: cache cold — querying with '
        'shippingMethod=$method',
      );

      final result = await _authedClient.query(
        QueryOptions(
          document: gql(CheckoutQueries.getPaymentMethods),
          variables: {'shippingMethod': method},
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
        debugPrint(
          '[CheckoutRepo] getPaymentMethods error: ${result.exception}',
        );
        throw result.exception!;
      }

      _logCheckoutApiDetails(
        'getPaymentMethods',
        variables: {'shippingMethod': method},
        responseData: result.data,
      );

      list = result.data?['paymentMethods']?['paymentMethods'] as List?;
      _cachedPaymentMethods = list;
    }

    if (list == null) return [];

    // Shape: [{ method, methodTitle, description, sort, image }]
    final methods = list
        .whereType<Map<String, dynamic>>()
        .map(
          (m) => PaymentMethod(
            id: m['method']?.toString() ?? '',
            method: m['method']?.toString() ?? '',
            title: m['methodTitle']?.toString() ?? '',
            description: m['description']?.toString(),
            icon: m['image']?.toString(),
          ),
        )
        .toList();

    debugPrint('[CheckoutRepo] getPaymentMethods: ${methods.length} method(s)');
    return methods;
  }

  // ─── Mutations ───────────────────────────────────────────────────────────

  /// Convert ONE flat address group (billing… / shipping…) into the nested
  /// `CheckoutAddressInput` the real schema expects.
  ///
  /// The rest of the app builds a FLAT map (`billingFirstName`, `billingCity`,
  /// …). The real API wants `{ billing: { firstName, city, address: [...] } }`.
  /// Translating here keeps that single shape change contained to the API
  /// layer instead of rippling through the bloc and the form widgets.
  ///
  /// Returns null when the group has no data at all.
  static Map<String, dynamic>? _toAddressInput(
    Map<String, dynamic> flat,
    String prefix, {
    bool? useForShipping,
  }) {
    String pick(String field) {
      // e.g. prefix='billing', field='FirstName' -> 'billingFirstName'
      return flat['$prefix$field']?.toString().trim() ?? '';
    }

    final firstName = pick('FirstName');
    final lastName = pick('LastName');
    final street = pick('Address');

    // Nothing filled in for this group.
    if (firstName.isEmpty && lastName.isEmpty && street.isEmpty) return null;

    // `phone` is `billingPhoneNumber` in the flat map but `phone` in the schema.
    final phone = pick('PhoneNumber');

    final out = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'email': pick('Email'),
      'companyName': pick('CompanyName'),
      // `address` is a LIST of strings on this schema, not a single string.
      'address': [street],
      'city': pick('City'),
      'country': pick('Country'),
      'state': pick('State'),
      'postcode': pick('Postcode'),
      'phone': phone,
    };

    if (useForShipping != null) out['useForShipping'] = useForShipping;

    return out;
  }

  /// Save checkout addresses (billing + optional shipping).
  ///
  /// Accepts the app's FLAT input map and translates it to the schema's nested
  /// `SaveShippingAddressInput`. The response already carries the shipping and
  /// payment methods, so they are cached here for the follow-up getters.
  Future<CheckoutAddressResponse> saveCheckoutAddress(
    Map<String, dynamic> input,
  ) async {
    final useForShipping = input['useForShipping'] == true;

    final billing = _toAddressInput(
      input,
      'billing',
      useForShipping: useForShipping,
    );

    // Only send `shipping` when the user actually entered a separate address.
    final shipping = useForShipping ? null : _toAddressInput(input, 'shipping');

    if (billing == null) {
      throw Exception('Failed to save checkout address – no billing address');
    }

    debugPrint(
      '[CheckoutRepo] saveCheckoutAddress billing=$billing shipping=$shipping',
    );

    final result = await _authedClient.mutate(
      MutationOptions(
        document: gql(CheckoutMutations.createCheckoutAddress),
        variables: {'billing': billing, 'shipping': shipping},
      ),
    );

    if (result.hasException) {
      debugPrint(
        '[CheckoutRepo] saveCheckoutAddress error: ${result.exception}',
      );
      throw result.exception!;
    }

    _logCheckoutApiDetails(
      'saveCheckoutAddress',
      variables: {'input': input},
      responseData: result.data,
    );

    final data = result.data?['saveCheckoutAddresses'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Failed to save checkout address – null response');
    }

    // The response ALREADY contains both method lists — cache them so the
    // follow-up getters don't need a second round-trip.
    _cachedShippingMethods = data['shippingMethods'] as List?;
    _cachedPaymentMethods = data['paymentMethods'] as List?;
    debugPrint(
      '[CheckoutRepo] saveCheckoutAddress -> '
      '${_cachedShippingMethods?.length ?? 0} shipping group(s), '
      '${_cachedPaymentMethods?.length ?? 0} payment method(s)',
    );

    // This schema has no `success` flag or `cartToken` on the response: a
    // non-null payload without GraphQL errors IS success, and the cart is
    // identified by the Bearer token rather than a separate token.
    return CheckoutAddressResponse(
      success: true,
      message: data['message']?.toString(),
      id: (data['cart'] as Map<String, dynamic>?)?['id']?.toString(),
      cartToken: null,
    );
  }

  /// Save the checkout billing address into the customer's address book.
  ///
  /// This is used for the first logged-in checkout when the customer has no
  /// saved addresses yet and opts into saving the entered billing address.
  Future<void> saveCustomerAddressFromCheckout(
    Map<String, dynamic> checkoutInput, {
    bool defaultAddress = false,
  }) async {
    final inputs = buildCustomerAddressBookInputsFromCheckout(
      checkoutInput,
      defaultAddress: defaultAddress,
    );

    for (final input in inputs) {
      debugPrint('[CheckoutRepo] saveCustomerAddressFromCheckout input=$input');

      final result = await _authedClient.mutate(
        MutationOptions(
          // Real mutation: createAddress(input: AddressInput!)
          document: gql(AccountQueries.createAddUpdateCustomerAddress),
          variables: {'input': input},
        ),
      );

      if (result.hasException) {
        debugPrint(
          '[CheckoutRepo] saveCustomerAddressFromCheckout error: ${result.exception}',
        );
        throw result.exception!;
      }

      _logCheckoutApiDetails(
        'saveCustomerAddressFromCheckout',
        variables: {'input': input},
        responseData: result.data,
      );

      final payload = result.data?['createAddress'] as Map<String, dynamic>?;

      if (payload?['success'] == false) {
        throw Exception(
          payload?['message']?.toString() ??
              'Failed to save address to address book',
        );
      }

      if (payload?['address'] == null) {
        throw Exception('Failed to save address to address book');
      }
    }
  }

  /// Save selected shipping method
  Future<CheckoutShippingMethodResponse> saveShippingMethod(
    String shippingMethod,
  ) async {
    debugPrint(
      '[CheckoutRepo] saveShippingMethod: $shippingMethod (authToken present: ${_authToken != null})',
    );

    // Remember it: the standalone paymentMethods query needs it as an argument.
    _selectedShippingMethod = shippingMethod;

    // The available payment methods depend on the chosen shipping method, so
    // the previously cached list is now stale.
    _cachedPaymentMethods = null;
    final result = await _authedClient.mutate(
      MutationOptions(
        document: gql(CheckoutMutations.createCheckoutShippingMethod),
        // Schema: saveShipping(input: { method: String! })
        variables: {'method': shippingMethod},
      ),
    );

    if (result.hasException) {
      debugPrint(
        '[CheckoutRepo] saveShippingMethod error: ${result.exception}',
      );
      throw result.exception!;
    }

    _logCheckoutApiDetails(
      'saveShippingMethod',
      variables: {
        'input': {'shippingMethod': shippingMethod},
      },
      responseData: result.data,
    );

    final data = result.data?['saveShipping'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Failed to save shipping method – null response');
    }

    // No `success` field on ShippingResponse: no GraphQL error == success.
    return CheckoutShippingMethodResponse(
      success: true,
      message: data['message']?.toString(),
    );
  }

  /// Save selected payment method
  Future<CheckoutPaymentMethodResponse> savePaymentMethod(
    String paymentMethod,
  ) async {
    debugPrint('[CheckoutRepo] savePaymentMethod: $paymentMethod');
    final result = await _authedClient.mutate(
      MutationOptions(
        document: gql(CheckoutMutations.createCheckoutPaymentMethod),
        // Schema: savePayment(input: { method: String! })
        variables: {'method': paymentMethod},
      ),
    );

    if (result.hasException) {
      debugPrint('[CheckoutRepo] savePaymentMethod error: ${result.exception}');
      throw result.exception!;
    }

    _logCheckoutApiDetails(
      'savePaymentMethod',
      variables: {
        'input': {'paymentMethod': paymentMethod},
      },
      responseData: result.data,
    );

    final data = result.data?['savePayment'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Failed to save payment method – null response');
    }

    // PaymentResponse has no success/gateway fields; a redirect (if any) comes
    // back later from placeOrder().redirectUrl.
    return CheckoutPaymentMethodResponse(
      success: true,
      message: data['message']?.toString(),
    );
  }

  /// Place the final order
  Future<CheckoutOrderResponse> placeOrder() async {
    debugPrint('[CheckoutRepo] placeOrder...');
    final result = await _authedClient.mutate(
      MutationOptions(document: gql(CheckoutMutations.createCheckoutOrder)),
    );

    if (result.hasException) {
      debugPrint('[CheckoutRepo] placeOrder error: ${result.exception}');
      throw result.exception!;
    }

    _logCheckoutApiDetails('placeOrder', responseData: result.data);

    final data = result.data?['placeOrder'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Failed to place order – null response');
    }

    final order = data['order'] as Map<String, dynamic>?;

    // A successful order clears the checkout session — drop the cached methods
    // so a subsequent checkout re-fetches them via saveCheckoutAddresses.
    _cachedShippingMethods = null;
    _cachedPaymentMethods = null;

    return CheckoutOrderResponse(
      success: data['success'] == true,
      id: order?['id']?.toString(),
      orderId: order?['id']?.toString(),
      orderIncrementId: order?['incrementId']?.toString(),
    );
  }

  /// Build a CouponResponse from the real `{ success, message, cart }` shape.
  /// Totals live on `cart` (raw) and `cart.formattedPrice` (strings) — there
  /// are no flat `formattedGrandTotal`-style fields on this schema.
  static CouponResponse _couponFromPayload(Map<String, dynamic> data) {
    final cart = data['cart'] as Map<String, dynamic>? ?? const {};
    final fmt = cart['formattedPrice'] as Map<String, dynamic>? ?? const {};

    return CouponResponse(
      success: data['success'] == true,
      message: data['message']?.toString(),
      discountAmount: _toDouble(cart['discountAmount']),
      formattedDiscountAmount: fmt['discountAmount']?.toString(),
      grandTotal: _toDouble(cart['grandTotal']),
      formattedGrandTotal: fmt['grandTotal']?.toString(),
      subtotal: _toDouble(cart['subTotal']),
      formattedSubtotal: fmt['subTotal']?.toString(),
      taxAmount: _toDouble(cart['taxTotal']),
      formattedTaxAmount: fmt['taxTotal']?.toString(),
    );
  }

  /// Apply coupon code
  Future<CouponResponse> applyCoupon(String couponCode) async {
    debugPrint('[CheckoutRepo] applyCoupon: $couponCode');
    final result = await _authedClient.mutate(
      MutationOptions(
        document: gql(CheckoutMutations.createApplyCoupon),
        // Schema: applyCoupon(input: { code: String! })
        variables: {'code': couponCode},
      ),
    );

    if (result.hasException) {
      debugPrint('[CheckoutRepo] applyCoupon error: ${result.exception}');
      throw result.exception!;
    }

    _logCheckoutApiDetails(
      'applyCoupon',
      variables: {
        'input': {'couponCode': couponCode},
      },
      responseData: result.data,
    );

    final data = result.data?['applyCoupon'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Failed to apply coupon – null response');
    }

    return _couponFromPayload(data);
  }

  /// Remove coupon code
  Future<CouponResponse> removeCoupon() async {
    debugPrint('[CheckoutRepo] removeCoupon...');
    final result = await _authedClient.mutate(
      MutationOptions(
        document: gql(CheckoutMutations.createRemoveCoupon),
        // Schema: `removeCoupon` takes NO arguments.
      ),
    );

    if (result.hasException) {
      debugPrint('[CheckoutRepo] removeCoupon error: ${result.exception}');
      throw result.exception!;
    }

    _logCheckoutApiDetails(
      'removeCoupon',
      variables: {'input': {}},
      responseData: result.data,
    );

    final data = result.data?['removeCoupon'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Failed to remove coupon – null response');
    }

    return _couponFromPayload(data);
  }
}
