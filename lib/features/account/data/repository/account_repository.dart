import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/graphql/account_queries.dart';
import '../../../checkout/data/models/checkout_model.dart' show BagistoCountry;
import '../models/account_models.dart';

/// The app's current locale code (e.g. "ar"), used to resolve localized
/// country / state names from Bagisto's `translations` relations.
/// `LocaleCubit.localeKey` is 'app_locale_code'.
Future<String?> _currentLocaleCode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_locale_code');
    if (code != null && code.isNotEmpty) return code;
  } catch (e) {
    debugPrint('[AccountRepo] could not read locale: $e');
  }
  return null;
}

/// Overwrite [key] with the translation matching [locale], when one exists.
/// Reuses BagistoCountry.localizedFrom so the matching rules stay in one place.
Map<String, dynamic> _applyTranslation(
  Map<String, dynamic> row,
  String? locale,
  String key,
) {
  final translated = BagistoCountry.localizedFrom(
    row['translations'],
    locale,
    key,
  );
  if (translated == null) return row;
  return {...row, key: translated};
}

void _logAccountApiMessage(String message) {
  debugPrint(message);
  // ignore: avoid_print
  print(message);
}

/// The real Bagisto storefront schema returns a numeric `id` (e.g. "11") and
/// has no `_id` field, whereas some models were written to read `_id` for the
/// numeric key. This back-fills `_id` from `id` on a row and its common nested
/// objects (product, customer) so those models keep working unchanged.
Map<String, dynamic> normalizeBagistoIds(Map<String, dynamic> row) {
  final out = Map<String, dynamic>.from(row);
  if (out['_id'] == null && out['id'] != null) {
    final parsed = int.tryParse(out['id'].toString().split('/').last);
    if (parsed != null) out['_id'] = parsed;
  }
  for (final key in const ['product', 'customer', 'order', 'channel']) {
    if (out[key] is Map<String, dynamic>) {
      out[key] = normalizeBagistoIds(out[key] as Map<String, dynamic>);
    }
  }
  return out;
}

/// Bagisto's storefront GraphQL uses Laravel-style pagination:
///   { paginatorInfo { count currentPage lastPage total }, data [ ... ] }
///
/// The app's blocs were written against a cursor-connection shape
/// (edges/node + pageInfo/totalCount). This helper bridges the two: it reads
/// a `paginatorInfo/data` payload and exposes the flat rows plus cursor-like
/// fields. The "endCursor" is simply the next page number as a string, which
/// [BagistoPage.pageFromCursor] can decode for the next request.
class BagistoPage<T> {
  final List<T> items;
  final int totalCount;
  final bool hasNextPage;
  final String? endCursor;

  const BagistoPage({
    required this.items,
    required this.totalCount,
    required this.hasNextPage,
    required this.endCursor,
  });

  /// Decode a page number previously produced as an `endCursor`.
  static int pageFromCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) return 1;
    return int.tryParse(cursor) ?? 1;
  }

  static BagistoPage<R> fromPaginator<R>(
    Map<String, dynamic>? connection,
    R Function(Map<String, dynamic> row) mapper,
  ) {
    if (connection == null) {
      return BagistoPage<R>(
        items: const [],
        totalCount: 0,
        hasNextPage: false,
        endCursor: null,
      );
    }
    final rows = (connection['data'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(normalizeBagistoIds)
        .map(mapper)
        .toList();
    final info = connection['paginatorInfo'] as Map<String, dynamic>?;
    final currentPage = info?['currentPage'] as int? ?? 1;
    final lastPage = info?['lastPage'] as int? ?? currentPage;
    final total = info?['total'] as int? ?? rows.length;
    final hasNext = currentPage < lastPage;
    return BagistoPage<R>(
      items: rows,
      totalCount: total,
      hasNextPage: hasNext,
      endCursor: hasNext ? (currentPage + 1).toString() : null,
    );
  }
}

/// Build the real `AddressInput` payload.
///
/// VERIFIED against `shop/customer/addresses.graphql`:
///   input AddressInput {
///     companyName, firstName!, lastName!, email!, vatId,
///     address: [String]!, country!, state!, city!, postcode!, phone!,
///     defaultAddress
///   }
///
/// Two shape changes from the old (invented) input:
///  1. `address` is a LIST of strings — not `address1` / `address2`.
///  2. There is NO `addressId` field. Updates pass the id as a separate
///     mutation argument (`updateAddress(id:, input:)`).
Map<String, dynamic> buildCustomerAddressMutationInput({
  required String firstName,
  required String lastName,
  required String address,
  required String city,
  required String state,
  required String country,
  required String postcode,
  required String phone,
  String? email,
  String? companyName,
  String? vatId,
  bool defaultAddress = false,
}) {
  final input = <String, dynamic>{
    'firstName': firstName,
    'lastName': lastName,
    // `email` is non-null in AddressInput — send '' rather than omitting it.
    'email': email ?? '',
    'address': [address],
    'city': city,
    'state': state,
    'country': country,
    'postcode': postcode,
    'phone': phone,
    'defaultAddress': defaultAddress,
  };

  // Optional on the schema — only send when actually provided.
  if (companyName != null && companyName.isNotEmpty) {
    input['companyName'] = companyName;
  }

  if (vatId != null && vatId.isNotEmpty) {
    input['vatId'] = vatId;
  }

  return input;
}

// NOTE: `buildSetDefaultCustomerAddressMutationInput` was removed.
// The real API is `setDefaultAddress(id: ID!)` — it takes ONLY the id, so
// re-sending the whole address is unnecessary (and impossible: the input type
// it was building does not exist on this schema).

/// Repository for Account Dashboard API calls via GraphQL.
/// Uses authenticated GraphQL client to fetch:
///   - Customer Profile  (readCustomerProfile)
///   - Customer Addresses (getCustomerAddresses)
///   - Product Reviews    (productReviews)
///
/// Note: Orders and Wishlist queries are NOT available in
/// the Bagisto demo storefront GraphQL schema. Those sections
/// return empty lists gracefully.
class AccountRepository {
  final GraphQLClient client;

  AccountRepository({required this.client});

  Future<List<ShopLocale>> getLocales() async {
    _logAccountApiMessage('🌐 AccountRepo.getLocales called');
    _logAccountApiMessage('📝 Query Name: getLocales');

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getLocales),
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      _logAccountApiMessage('❌ AccountRepo.getLocales error: $message');
      throw AccountException(message);
    }

    final edges = result.data?['locales']?['edges'] as List<dynamic>? ?? [];
    final locales = edges
        .map(
          (edge) => ShopLocale.fromJson(edge['node'] as Map<String, dynamic>),
        )
        .toList();

    _logAccountApiMessage(
      '✅ AccountRepo.getLocales success: ${locales.length} locales',
    );
    return locales;
  }

  Future<List<ShopCurrency>> getCurrencies() async {
    _logAccountApiMessage('🌐 AccountRepo.getCurrencies called');
    _logAccountApiMessage('📝 Query Name: allCurrency');

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCurrencies),
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      _logAccountApiMessage('❌ AccountRepo.getCurrencies error: $message');
      throw AccountException(message);
    }

    final edges = result.data?['currencies']?['edges'] as List<dynamic>? ?? [];
    final currencies = edges
        .map(
          (edge) => ShopCurrency.fromJson(edge['node'] as Map<String, dynamic>),
        )
        .toList();

    _logAccountApiMessage(
      '✅ AccountRepo.getCurrencies success: ${currencies.length} currencies',
    );
    return currencies;
  }

  /// Fetch customer profile via readCustomerProfile query.
  /// The API uses the auth token to identify the user (id is empty string).
  Future<CustomerProfile> getCustomerProfile() async {
    debugPrint('👤 AccountRepo.getCustomerProfile');

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCustomerProfile),
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('👤 AccountRepo.getCustomerProfile — error: $message');
      throw AccountException(message);
    }

    final data = result.data?['accountInfo'];
    if (data == null) {
      throw AccountException('No profile data returned');
    }

    debugPrint('👤 AccountRepo.getCustomerProfile — success');
    return CustomerProfile.fromJson(data);
  }

  /// Fetch customer addresses via getCustomerAddresses query
  Future<List<CustomerAddress>> getCustomerAddresses({int first = 10}) async {
    debugPrint('📍 AccountRepo.getCustomerAddresses');

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCustomerAddresses),
        variables: {'first': first, 'page': 1},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('📍 AccountRepo.getCustomerAddresses — error: $message');
      throw AccountException(message);
    }

    final rows = result.data?['addresses']?['data'] as List<dynamic>? ?? [];
    final addresses = rows
        .whereType<Map<String, dynamic>>()
        .map(normalizeBagistoIds)
        .map<CustomerAddress>(CustomerAddress.fromJson)
        .toList();

    debugPrint(
      '📍 AccountRepo.getCustomerAddresses — got ${addresses.length} addresses',
    );
    return addresses;
  }

  Future<List<RecentOrder>> getRecentOrders({int first = 5}) async {
    debugPrint('📦 AccountRepo.getRecentOrders');

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCustomerOrders),
        variables: {'first': first, 'page': 1},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('📦 AccountRepo.getRecentOrders — error: $message');
      throw AccountException(message);
    }

    final rows = result.data?['ordersList']?['data'] as List<dynamic>? ?? [];
    final orders = rows
        .whereType<Map<String, dynamic>>()
        .map(normalizeBagistoIds)
        .map<RecentOrder>(RecentOrder.fromJson)
        .toList();

    debugPrint('📦 AccountRepo.getRecentOrders — got ${orders.length} orders');
    return orders;
  }

  /// Fetch wishlists (cursor-paginated).
  /// Uses the authenticated wishlists query.
  Future<
    ({
      List<WishlistItem> items,
      int totalCount,
      bool hasNextPage,
      String? endCursor,
    })
  >
  getWishlist({int first = 20, String? after}) async {
    debugPrint('❤️ AccountRepo.getWishlist');

    final variables = <String, dynamic>{
      'first': first,
      'page': BagistoPage.pageFromCursor(after),
    };

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getWishlists),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('❤️ AccountRepo.getWishlist — error: $message');
      throw AccountException(message);
    }

    final page = BagistoPage.fromPaginator<WishlistItem>(
      result.data?['wishlists'] as Map<String, dynamic>?,
      WishlistItem.fromJson,
    );

    debugPrint(
      '❤️ AccountRepo.getWishlist — ${page.items.length} items (total: ${page.totalCount}, hasNext: ${page.hasNextPage})',
    );
    return (
      items: page.items,
      totalCount: page.totalCount,
      hasNextPage: page.hasNextPage,
      endCursor: page.endCursor,
    );
  }

  /// Remove a product from the wishlist.
  ///
  /// IMPORTANT: Bagisto's real API is `removeFromWishlist(productId:)`, which
  /// is keyed by the PRODUCT id — not by the wishlist row id. The old
  /// `deleteWishlist(input: {id})` mutation did not exist in the schema.
  Future<void> removeFromWishlist({required int productId}) async {
    debugPrint('🗑️ AccountRepo.removeFromWishlist (productId=$productId)');

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.deleteWishlist),
        variables: {'productId': productId},
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🗑️ AccountRepo.removeFromWishlist — error: $message');
      throw AccountException(message);
    }

    final payload = result.data?['removeFromWishlist'];
    if (payload?['success'] == false) {
      final msg =
          payload?['message']?.toString() ?? 'Failed to remove from wishlist';
      debugPrint('🗑️ AccountRepo.removeFromWishlist — server refused: $msg');
      throw AccountException(msg);
    }

    debugPrint('🗑️ AccountRepo.removeFromWishlist — success');
  }

  /// Move a wishlist item to cart.
  /// [wishlistItemId] is the numeric _id (not IRI).
  Future<String> moveWishlistToCart({
    required int wishlistItemId,
    int quantity = 1,
  }) async {
    debugPrint(
      '🛒 AccountRepo.moveWishlistToCart (itemId=$wishlistItemId, qty=$quantity)',
    );

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.moveWishlistToCart),
        variables: {'id': wishlistItemId, 'quantity': quantity},
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🛒 AccountRepo.moveWishlistToCart — error: $message');
      throw AccountException(message);
    }

    final payload = result.data?['moveToCart'];
    if (payload?['success'] == false) {
      final failMsg =
          payload?['message']?.toString() ?? 'Failed to move item to cart';
      throw AccountException(failMsg);
    }

    final msg = payload?['message']?.toString() ?? 'Item moved to cart';
    debugPrint('🛒 AccountRepo.moveWishlistToCart — success: $msg');
    return msg;
  }

  /// Fetch product reviews via productReviews query
  /// [productId] — optional product ID to filter reviews for a specific product
  Future<({List<ProductReview> reviews, int totalCount})> getProductReviews({
    int first = 10,
    int? status,
    int? productId,
  }) async {
    debugPrint('⭐ AccountRepo.getProductReviews (productId=$productId)');

    final variables = <String, dynamic>{'first': first};
    if (status != null) variables['status'] = status;
    if (productId != null) variables['productId'] = productId;

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getProductReviews),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('⭐ AccountRepo.getProductReviews — error: $message');
      throw AccountException(message);
    }

    final reviewsData = result.data?['productReviews'];
    if (reviewsData == null) {
      return (reviews: const <ProductReview>[], totalCount: 0);
    }

    final edges = reviewsData['edges'] as List? ?? [];
    final totalCount = reviewsData['totalCount'] as int? ?? edges.length;

    final reviews = edges.map<ProductReview>((edge) {
      final node = edge['node'] ?? edge;
      return ProductReview.fromJson(node);
    }).toList();

    debugPrint(
      '⭐ AccountRepo.getProductReviews — got ${reviews.length} reviews, total: $totalCount',
    );
    return (reviews: reviews, totalCount: totalCount);
  }

  /// Fetch customer reviews via customerReviews query (cursor-paginated).
  /// Returns review list with nested product data (name, images).
  /// Falls back to productReviews if customerReviews is unavailable.
  Future<
    ({
      List<ProductReview> reviews,
      int totalCount,
      bool hasNextPage,
      String? endCursor,
    })
  >
  getCustomerReviews({int first = 10, String? after}) async {
    debugPrint('⭐ AccountRepo.getCustomerReviews');

    // reviewsList is not paginated by page in the storefront schema; it
    // returns the customer's reviews in one shot inside a paginator wrapper.
    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCustomerReviews),
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('⭐ AccountRepo.getCustomerReviews — error: $message');
      throw AccountException(message);
    }

    final page = BagistoPage.fromPaginator<ProductReview>(
      result.data?['reviewsList'] as Map<String, dynamic>?,
      ProductReview.fromJson,
    );

    debugPrint(
      '⭐ AccountRepo.getCustomerReviews — ${page.items.length} reviews (total: ${page.totalCount})',
    );
    return (
      reviews: page.items,
      totalCount: page.totalCount,
      hasNextPage: page.hasNextPage,
      endCursor: page.endCursor,
    );
  }

  /// Set an address as the default address.
  ///
  /// The real API is `setDefaultAddress(id: ID!)` — it needs ONLY the id.
  ///
  /// The other named parameters are kept so existing callers compile unchanged,
  /// but they are no longer sent: re-uploading the whole address to flip one
  /// boolean was an artefact of the old (non-existent) create-or-update
  /// mutation.
  Future<CustomerAddress> setDefaultAddress({
    required int addressId,
    String? firstName,
    String? lastName,
    String? address,
    String? city,
    String? state,
    String? country,
    String? postcode,
    String? phone,
    String? email,
  }) async {
    debugPrint('📍 AccountRepo.setDefaultAddress (addressId=$addressId)');

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.setDefaultAddress),
        variables: {'id': addressId},
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('📍 AccountRepo.setDefaultAddress — error: $message');
      throw AccountException(message);
    }

    final payload = result.data?['setDefaultAddress'];

    if (payload?['success'] == false) {
      throw AccountException(
        payload?['message']?.toString() ?? 'Failed to set default address',
      );
    }

    final data = payload?['address'];
    if (data == null) {
      throw AccountException('Failed to set default address');
    }

    debugPrint('📍 AccountRepo.setDefaultAddress — success');
    return CustomerAddress.fromJson(data as Map<String, dynamic>);
  }

  /// Delete a customer address.
  ///
  /// Real API: `deleteAddress(id: ID!): StatusResponse`.
  Future<void> deleteAddress({required int addressId}) async {
    debugPrint('🗑️ AccountRepo.deleteAddress (id=$addressId)');

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.deleteCustomerAddress),
        variables: {'id': addressId},
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🗑️ AccountRepo.deleteAddress — error: $message');
      throw AccountException(message);
    }

    final payload = result.data?['deleteAddress'];
    if (payload?['success'] == false) {
      throw AccountException(
        payload?['message']?.toString() ?? 'Failed to delete address',
      );
    }

    debugPrint('🗑️ AccountRepo.deleteAddress — success');
  }

  /// Add a new customer address via createAddUpdateCustomerAddress mutation.
  /// Schema introspection: createAddUpdateCustomerAddressInput fields:
  ///   firstName, lastName, email, phone, address1, address2,
  ///   country, state, city, postcode, defaultAddress
  Future<CustomerAddress> createAddress({
    required String firstName,
    required String lastName,
    required String address,
    required String city,
    required String state,
    required String country,
    required String postcode,
    required String phone,
    String? email,
    String? companyName,
    String? vatId,
    bool defaultAddress = false,
  }) async {
    debugPrint('📍 AccountRepo.createAddress');

    // companyName and vatId ARE supported by the real AddressInput.
    final input = buildCustomerAddressMutationInput(
      firstName: firstName,
      lastName: lastName,
      address: address,
      city: city,
      state: state,
      country: country,
      postcode: postcode,
      phone: phone,
      email: email,
      companyName: companyName,
      vatId: vatId,
      defaultAddress: defaultAddress,
    );

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.createAddUpdateCustomerAddress),
        variables: {'input': input},
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('📍 AccountRepo.createAddress — error: $message');
      throw AccountException(message);
    }

    final payload = result.data?['createAddress'];
    if (payload?['success'] == false) {
      throw AccountException(
        payload?['message']?.toString() ?? 'Failed to create address',
      );
    }

    final data = payload?['address'];
    if (data == null) {
      throw AccountException('Failed to create address');
    }

    debugPrint('📍 AccountRepo.createAddress — success');
    return CustomerAddress.fromJson(data as Map<String, dynamic>);
  }

  /// Update an existing customer address via createAddUpdateCustomerAddress mutation.
  /// The `addressId` (Int) tells the API which address to update.
  /// API: https://api-docs.bagisto.com/api/graphql-api/shop/mutations/update-customer-address.html
  Future<CustomerAddress> updateAddress({
    required int addressId,
    required String firstName,
    required String lastName,
    required String address,
    required String city,
    required String state,
    required String country,
    required String postcode,
    required String phone,
    String? email,
    String? companyName,
    String? vatId,
    bool defaultAddress = false,
  }) async {
    debugPrint('📍 AccountRepo.updateAddress (addressId=$addressId)');

    // The id is NOT part of AddressInput — it is a separate mutation argument.
    final input = buildCustomerAddressMutationInput(
      firstName: firstName,
      lastName: lastName,
      address: address,
      city: city,
      state: state,
      country: country,
      postcode: postcode,
      phone: phone,
      email: email,
      companyName: companyName,
      vatId: vatId,
      defaultAddress: defaultAddress,
    );

    final result = await client.mutate(
      MutationOptions(
        // Separate mutation: create and update are NOT one operation here.
        document: gql(AccountQueries.updateCustomerAddress),
        variables: {'id': addressId, 'input': input},
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('📍 AccountRepo.updateAddress — error: $message');
      throw AccountException(message);
    }

    final payload = result.data?['updateAddress'];
    if (payload?['success'] == false) {
      throw AccountException(
        payload?['message']?.toString() ?? 'Failed to update address',
      );
    }

    final data = payload?['address'];
    if (data == null) {
      throw AccountException('Failed to update address');
    }

    debugPrint('📍 AccountRepo.updateAddress — success');
    return CustomerAddress.fromJson(data as Map<String, dynamic>);
  }

  /// Update customer profile via updateCustomerProfile mutation.
  /// Fields: firstName, lastName, phone, gender, dateOfBirth, subscribedToNewsLetter
  Future<CustomerProfile> updateCustomerProfile({
    required String firstName,
    required String lastName,
    String? phone,
    String? gender,
    String? dateOfBirth,
    bool? subscribedToNewsLetter,
  }) async {
    debugPrint('👤 AccountRepo.updateCustomerProfile');

    final input = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
    };
    if (phone != null) input['phone'] = phone;
    if (gender != null) input['gender'] = gender;
    if (dateOfBirth != null) input['dateOfBirth'] = dateOfBirth;
    if (subscribedToNewsLetter != null) {
      input['subscribedToNewsLetter'] = subscribedToNewsLetter;
    }

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.updateCustomerProfile),
        variables: {'input': input},
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('👤 AccountRepo.updateCustomerProfile — error: $message');
      throw AccountException(message);
    }

    final payload = result.data?['updateAccount'];
    if (payload == null || payload['success'] == false) {
      throw AccountException(
        (payload?['message'] as String?) ?? 'Failed to update profile',
      );
    }

    // Re-fetch the full profile since the mutation only returns id
    debugPrint(
      '👤 AccountRepo.updateCustomerProfile — mutation success, re-fetching profile',
    );
    return getCustomerProfile();
  }

  /// Change customer email — requires current password for verification
  Future<CustomerProfile> changeEmail({
    required String email,
    required String currentPassword,
  }) async {
    debugPrint('📧 AccountRepo.changeEmail');

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.changeCustomerEmail),
        variables: {
          'input': {'email': email, 'oldPassword': currentPassword},
        },
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('📧 AccountRepo.changeEmail — error: $message');
      throw AccountException(message);
    }

    final payload = result.data?['updateAccount'];
    if (payload == null || payload['success'] == false) {
      throw AccountException(
        (payload?['message'] as String?) ?? 'Failed to change email',
      );
    }

    // Re-fetch the full profile since the mutation only returns id
    debugPrint(
      '📧 AccountRepo.changeEmail — mutation success, re-fetching profile',
    );
    return getCustomerProfile();
  }

  /// Change customer password — requires current + new password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    debugPrint('🔑 AccountRepo.changePassword');

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.changeCustomerPassword),
        variables: {
          'input': {
            'oldPassword': currentPassword,
            'password': newPassword,
            'passwordConfirmation': confirmPassword,
          },
        },
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🔑 AccountRepo.changePassword — error: $message');
      throw AccountException(message);
    }

    debugPrint('🔑 AccountRepo.changePassword — success');
  }

  /// Delete customer account — requires current password
  Future<void> deleteCustomerAccount({required String password}) async {
    debugPrint('🗑️ AccountRepo.deleteCustomerAccount');

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.deleteCustomerAccount),
        variables: {'password': password},
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🗑️ AccountRepo.deleteCustomerAccount — error: $message');
      throw AccountException(message);
    }

    debugPrint('🗑️ AccountRepo.deleteCustomerAccount — success');
  }

  /// Fetch list of available countries (cursor-paginated).
  /// Uses FetchPolicy.cacheFirst — countries rarely change.
  Future<List<Country>> getCountries() async {
    debugPrint('🌍 AccountRepo.getCountries');

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCountries),
        // networkOnly: a stale `countries` entry cached by the old broken query
        // would otherwise be replayed and the picker would stay empty.
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🌍 AccountRepo.getCountries — error: $message');
      throw AccountException(message);
    }

    // `countries` is a PLAIN LIST on this schema (no edges/node wrapper).
    final list = result.data?['countries'] as List<dynamic>? ?? [];
    // Country.fromJson reads `_id`, which this schema does not return —
    // normalizeBagistoIds back-fills it from `id`. `_applyTranslation` swaps in
    // the localized name so the picker isn't English-only.
    final locale = await _currentLocaleCode();
    final countries = list
        .whereType<Map<String, dynamic>>()
        .map<Country>(
          (row) => Country.fromJson(
            normalizeBagistoIds(_applyTranslation(row, locale, 'name')),
          ),
        )
        .toList();
    countries.sort((a, b) => a.name.compareTo(b.name));

    debugPrint('🌍 AccountRepo.getCountries — got ${countries.length}');
    return countries;
  }

  /// Fetch states/provinces for a given country using its numeric _id.
  /// Uses FetchPolicy.cacheFirst — states rarely change.
  Future<List<CountryState>> getCountryStates({required int countryId}) async {
    debugPrint('🏛️ AccountRepo.getCountryStates (countryId=$countryId)');

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCountryStates),
        variables: {'countryId': countryId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🏛️ AccountRepo.getCountryStates — error: $message');
      throw AccountException(message);
    }

    // `countrieStates` is a PLAIN LIST on this schema.
    final list = result.data?['countrieStates'] as List<dynamic>? ?? [];
    final locale = await _currentLocaleCode();
    final states = list
        .whereType<Map<String, dynamic>>()
        .map<CountryState>(
          (row) => CountryState.fromJson(
            normalizeBagistoIds(_applyTranslation(row, locale, 'defaultName')),
          ),
        )
        .toList();
    states.sort((a, b) => a.name.compareTo(b.name));

    debugPrint('🏛️ AccountRepo.getCountryStates — got ${states.length}');
    return states;
  }

  // ──────────────────────────────────────────────
  // Compare Items
  // ──────────────────────────────────────────────

  /// Fetch compare items (cursor-paginated).
  Future<({List<CompareItem> items, int totalCount})> getCompareItems({
    int first = 20,
    String? after,
  }) async {
    debugPrint('🔀 AccountRepo.getCompareItems');

    final variables = <String, dynamic>{
      'first': first,
      'page': BagistoPage.pageFromCursor(after),
    };

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCompareItems),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🔀 AccountRepo.getCompareItems — error: $message');
      throw AccountException(message);
    }

    final page = BagistoPage.fromPaginator<CompareItem>(
      result.data?['compareProducts'] as Map<String, dynamic>?,
      CompareItem.fromJson,
    );

    debugPrint(
      '🔀 AccountRepo.getCompareItems — got ${page.items.length} of ${page.totalCount}',
    );
    return (items: page.items, totalCount: page.totalCount);
  }

  /// Delete a single compare item by IRI id.
  Future<void> deleteCompareItem(String id) async {
    debugPrint('🔀 AccountRepo.deleteCompareItem($id)');

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.deleteCompareItem),
        variables: {'id': id},
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🔀 AccountRepo.deleteCompareItem — error: $message');
      throw AccountException(message);
    }

    debugPrint('🔀 AccountRepo.deleteCompareItem — success');
  }

  /// Delete all compare items at once.
  Future<void> deleteAllCompareItems() async {
    debugPrint('🔀 AccountRepo.deleteAllCompareItems');

    final result = await client.mutate(
      MutationOptions(document: gql(AccountQueries.deleteAllCompareItems)),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🔀 AccountRepo.deleteAllCompareItems — error: $message');
      throw AccountException(message);
    }

    debugPrint('🔀 AccountRepo.deleteAllCompareItems — success');
  }

  /// Add product to wishlist.
  /// [productId] is the numeric product ID.
  /// Add product to wishlist.
  /// [productId] is the numeric product ID.
  /// Returns the wishlist item IRI id (e.g. "/api/shop/wishlists/69").
  Future<String?> addToWishlist({required int productId}) async {
    debugPrint('❤️ AccountRepo.addToWishlist (productId=$productId)');

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.createWishlist),
        variables: {'productId': productId},
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('❤️ AccountRepo.addToWishlist — error: $message');
      throw AccountException(message);
    }

    final payload = result.data?['addToWishlist'];

    if (payload?['success'] == false) {
      final msg =
          payload?['message']?.toString() ?? 'Failed to add to wishlist';
      debugPrint('❤️ AccountRepo.addToWishlist — server refused: $msg');
      throw AccountException(msg);
    }

    // `addToWishlist` returns the customer's FULL wishlist, so find the row
    // matching the product we just added and hand back its id.
    final rows = payload?['wishlist'] as List?;
    final match = rows?.cast<Map<String, dynamic>?>().firstWhere(
      (row) => row?['productId']?.toString() == productId.toString(),
      orElse: () => null,
    );

    final wishlistId = match?['id']?.toString();
    debugPrint('❤️ AccountRepo.addToWishlist — success (id=$wishlistId)');
    return wishlistId;
  }

  /// Add product to compare list.
  /// [productId] is the numeric product ID.
  Future<void> addToCompare({required int productId}) async {
    debugPrint('🔀 AccountRepo.addToCompare (productId=$productId)');

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.createCompareItem),
        variables: {
          'input': {'productId': productId},
        },
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🔀 AccountRepo.addToCompare — error: $message');
      throw AccountException(message);
    }

    debugPrint('🔀 AccountRepo.addToCompare — success');
  }

  /// Create a product review.
  /// [productId] — numeric product _id (Int).
  /// [title] — review headline.
  /// [comment] — full review text.
  /// [rating] — 1 to 5 star rating.
  /// [name] — reviewer's display name.
  /// Returns the created ProductReview.
  Future<ProductReview> createProductReview({
    required int productId,
    required String title,
    required String comment,
    required int rating,
    required String name,
  }) async {
    debugPrint('📝 AccountRepo.createProductReview (product=$productId)');

    final result = await client.mutate(
      MutationOptions(
        document: gql(AccountQueries.createProductReview),
        variables: {
          'input': {
            'productId': productId,
            'title': title,
            'comment': comment,
            'rating': rating,
            'name': name,
          },
        },
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('📝 AccountRepo.createProductReview — error: $message');
      throw AccountException(message);
    }

    final data = result.data?['createReview']?['review'];
    if (data == null) {
      throw AccountException('Failed to create review');
    }

    debugPrint('📝 AccountRepo.createProductReview — success');
    return ProductReview.fromJson(data as Map<String, dynamic>);
  }

  /// Fetch customer orders with cursor-based pagination.
  /// Supports optional [status] filter and cursor [after] for pagination.
  Future<
    ({
      List<CustomerOrder> orders,
      int totalCount,
      bool hasNextPage,
      String? endCursor,
    })
  >
  getCustomerOrders({int first = 20, String? after, String? status}) async {
    debugPrint(
      '📦 AccountRepo.getCustomerOrders (first=$first, status=$status)',
    );

    // `after` carries the next page number (see BagistoPage). Decode it.
    final variables = <String, dynamic>{
      'first': first,
      'page': BagistoPage.pageFromCursor(after),
    };
    if (status != null) variables['status'] = status;

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCustomerOrders),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('📦 AccountRepo.getCustomerOrders — error: $message');
      throw AccountException(message);
    }

    final page = BagistoPage.fromPaginator<CustomerOrder>(
      result.data?['ordersList'] as Map<String, dynamic>?,
      CustomerOrder.fromJson,
    );

    debugPrint(
      '📦 AccountRepo.getCustomerOrders — ${page.items.length} orders (total: ${page.totalCount}, hasNext: ${page.hasNextPage})',
    );
    return (
      orders: page.items,
      totalCount: page.totalCount,
      hasNextPage: page.hasNextPage,
      endCursor: page.endCursor,
    );
  }

  /// Fetch a single customer order detail by numeric ID.
  /// The Bagisto API expects an IRI ID for the `customerOrder(id: ID!)` query.
  /// We construct it as: `/api/shop/customer-orders/{numericId}`
  Future<OrderDetail> getCustomerOrder(int orderId) async {
    debugPrint('📦 AccountRepo.getCustomerOrder (id=$orderId)');

    // `orderDetail(id: ID!)` takes the PLAIN numeric id. The old IRI string
    // ('/api/shop/customer-orders/1') was an artefact of the invented
    // `customerOrder` query and would never match.
    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCustomerOrder),
        variables: {'id': orderId},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('📦 AccountRepo.getCustomerOrder — error: $message');
      throw AccountException(message);
    }

    final data = result.data?['orderDetail'];
    if (data == null) {
      throw const AccountException('Order not found');
    }

    debugPrint('📦 AccountRepo.getCustomerOrder — success');
    return OrderDetail.fromJson(data as Map<String, dynamic>);
  }

  /// Fetch customer invoices with cursor-based pagination.
  /// Supports optional [orderId] and [state] filters.
  Future<
    ({
      List<OrderInvoice> invoices,
      int totalCount,
      bool hasNextPage,
      String? endCursor,
    })
  >
  getCustomerInvoices({
    int first = 20,
    String? after,
    int? orderId,
    String? state,
  }) async {
    debugPrint(
      '🧾 AccountRepo.getCustomerInvoices (first=$first, orderId=$orderId, state=$state)',
    );

    // PAGINATOR uses page/first — there is no cursor `after`, and
    // OrderInvoiceInput has no `state` filter.
    final variables = <String, dynamic>{'first': first, 'page': 1};
    if (orderId != null) variables['orderId'] = orderId;

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCustomerInvoices),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🧾 AccountRepo.getCustomerInvoices — error: $message');
      throw AccountException(message);
    }

    final data = result.data?['viewInvoices'];
    if (data == null) {
      return (
        invoices: const <OrderInvoice>[],
        totalCount: 0,
        hasNextPage: false,
        endCursor: null,
      );
    }

    // PAGINATOR shape: { paginatorInfo, data } — not edges/node/pageInfo.
    final rows = data['data'] as List<dynamic>? ?? [];
    final invoices = rows
        .whereType<Map<String, dynamic>>()
        .map(OrderInvoice.fromJson)
        .toList();
    final info = data['paginatorInfo'] as Map<String, dynamic>?;
    final totalCount = info?['total'] as int? ?? invoices.length;
    final currentPage = info?['currentPage'] as int? ?? 1;
    final lastPage = info?['lastPage'] as int? ?? 1;
    final hasNextPage = currentPage < lastPage;
    // PAGINATOR has no cursors; keep the field for the existing record shape.
    final endCursor = hasNextPage ? '${currentPage + 1}' : null;

    debugPrint(
      '🧾 AccountRepo.getCustomerInvoices — ${invoices.length} invoices (total: $totalCount, hasNext: $hasNextPage)',
    );
    return (
      invoices: invoices,
      totalCount: totalCount,
      hasNextPage: hasNextPage,
      endCursor: endCursor,
    );
  }

  /// Fetch a single customer invoice detail by numeric ID.
  /// The Bagisto API expects an IRI ID for the `customerInvoice(id: ID!)` query.
  /// We construct it as: `/api/shop/customer-invoices/{numericId}`
  Future<OrderInvoice> getCustomerInvoice(int invoiceId) async {
    debugPrint('🧾 AccountRepo.getCustomerInvoice (id=$invoiceId)');

    // `viewInvoice(id: ID)` takes the PLAIN numeric id, not an IRI string.
    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCustomerInvoice),
        variables: {'id': invoiceId},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🧾 AccountRepo.getCustomerInvoice — error: $message');
      throw AccountException(message);
    }

    final data = result.data?['viewInvoice'];
    if (data == null) {
      throw const AccountException('Invoice not found');
    }

    debugPrint('🧾 AccountRepo.getCustomerInvoice — success');
    return OrderInvoice.fromJson(data as Map<String, dynamic>);
  }

  // ──────────────────────────────────────────────
  // Customer Shipments
  // ──────────────────────────────────────────────

  /// Fetch customer order shipments for a given order.
  Future<({List<OrderShipment> shipments, int totalCount})>
  getCustomerOrderShipments({required int orderId}) async {
    debugPrint('📦 AccountRepo.getCustomerOrderShipments (orderId=$orderId)');

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCustomerOrderShipments),
        variables: {'orderId': orderId, 'first': 50, 'page': 1},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('📦 AccountRepo.getCustomerOrderShipments — error: $message');
      throw AccountException(message);
    }

    final data = result.data?['viewShipments'];
    if (data == null) {
      return (shipments: const <OrderShipment>[], totalCount: 0);
    }

    final edges = data['data'] as List<dynamic>? ?? [];
    final shipments = edges
        .whereType<Map<String, dynamic>>()
        .map(OrderShipment.fromJson)
        .toList();
    final totalCount = data['totalCount'] as int? ?? shipments.length;

    debugPrint(
      '📦 AccountRepo.getCustomerOrderShipments — ${shipments.length} shipments (total: $totalCount)',
    );
    return (shipments: shipments, totalCount: totalCount);
  }

  /// Fetch a single customer order shipment detail by numeric ID.
  Future<OrderShipment> getCustomerOrderShipment(int shipmentId) async {
    debugPrint('📦 AccountRepo.getCustomerOrderShipment (id=$shipmentId)');

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCustomerOrderShipment),
        variables: {'id': shipmentId},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('📦 AccountRepo.getCustomerOrderShipment — error: $message');
      throw AccountException(message);
    }

    final data = result.data?['viewShipment'];
    if (data == null) {
      throw const AccountException('Shipment not found');
    }

    debugPrint('📦 AccountRepo.getCustomerOrderShipment — success');
    return OrderShipment.fromJson(data as Map<String, dynamic>);
  }

  /// Extract error message from GraphQL exception
  String _extractErrorMessage(OperationException exception) {
    return ErrorMapper.getUserMessage(exception);
  }

  /// Reorder an existing order.
  /// [orderId] is the numeric order ID.
  /// Returns a tuple with success status, message, orderId, and itemsAddedCount.
  Future<({bool success, String message, int orderId, int itemsAddedCount})>
  reorderOrder({required int orderId}) async {
    debugPrint('🔄 AccountRepo.reorderOrder (orderId=$orderId)');

    final result = await client.mutate(
      MutationOptions(
        // Schema: reorder(id: ID!) — no input wrapper.
        document: gql(AccountQueries.reorderOrder),
        variables: {'id': orderId},
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint('🔄 AccountRepo.reorderOrder — error: $message');
      throw AccountException(message);
    }

    final data = result.data?['reorder'];
    if (data == null) {
      throw AccountException('Failed to reorder');
    }

    // `reorder` returns CartItemResponse { success, message, cart } — there is
    // no `orderId` or `itemsAddedCount` on the payload. Derive the item count
    // from the returned cart and echo back the order we reordered from.
    final success = data['success'] as bool? ?? false;
    final message = data['message'] as String? ?? '';
    final reorderedOrderId = orderId;
    final cart = data['cart'] as Map<String, dynamic>?;
    final itemsAddedCount = cart?['itemsCount'] as int? ?? 0;

    debugPrint(
      '🔄 AccountRepo.reorderOrder — success: $success, message: $message, itemsAddedCount: $itemsAddedCount',
    );
    return (
      success: success,
      message: message,
      orderId: reorderedOrderId,
      itemsAddedCount: itemsAddedCount,
    );
  }

  /// Fetch customer downloadable products (cursor-paginated)
  /// Returns downloadable products associated with customer's orders
  Future<
    ({
      List<DownloadableProduct> products,
      int totalCount,
      bool hasNextPage,
      String? endCursor,
    })
  >
  getCustomerDownloadableProducts({int first = 10, String? after}) async {
    debugPrint('📥 AccountRepo.getCustomerDownloadableProducts');

    final variables = <String, dynamic>{
      'first': first,
      'page': BagistoPage.pageFromCursor(after),
    };

    final result = await client.query(
      QueryOptions(
        document: gql(AccountQueries.getCustomerDownloadableProducts),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final message = _extractErrorMessage(result.exception!);
      debugPrint(
        '📥 AccountRepo.getCustomerDownloadableProducts — error: $message',
      );
      throw AccountException(message);
    }

    final page = BagistoPage.fromPaginator<DownloadableProduct>(
      result.data?['downloadableLinkPurchases'] as Map<String, dynamic>?,
      DownloadableProduct.fromJson,
    );

    debugPrint(
      '📥 AccountRepo.getCustomerDownloadableProducts — ${page.items.length} products (total: ${page.totalCount}, hasNext: ${page.hasNextPage})',
    );
    return (
      products: page.items,
      totalCount: page.totalCount,
      hasNextPage: page.hasNextPage,
      endCursor: page.endCursor,
    );
  }
}

/// Account-specific exception
class AccountException implements Exception {
  final String message;
  const AccountException(this.message);

  @override
  String toString() => 'AccountException: $message';
}
