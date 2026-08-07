import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/graphql/graphql_client.dart';
import '../../../../core/graphql/queries.dart';

import '../models/cart_model.dart';

/// Repository for all cart operations via Bagisto GraphQL API.
///
/// TOKEN MANAGEMENT (matching Next.js reference):
///
///  • **Guest user**: Uses a `sessionToken` (UUID) from `createCartToken`.
///    Sent as `Authorization: Bearer <sessionToken>`.
///
///  • **Logged-in user**: Uses the Sanctum `accessToken` from login.
///    Sent as `Authorization: Bearer <accessToken>`.
///
///  • On **login**: Call `mergeCart(cartId)` to merge the guest cart into the
///    user's cart, then switch the Bearer token to the access token.
///
///  • On **logout**: Clear the auth token, create a fresh guest cart session.
class CartRepository {
  final GraphQLClient client;

  /// The Bearer token used for Authorization header.
  /// Guest → sessionToken UUID, Logged-in → Sanctum access token.
  String? _token;

  /// Whether the current token is a guest session token.
  bool _isGuest = true;

  CartRepository({required this.client, String? initialToken}) {
    _token = initialToken;
  }

  /// Set the Bearer token for all subsequent cart API calls.
  void updateToken(String? token, {bool isGuest = true}) {
    _token = token;
    _isGuest = isGuest;
    debugPrint('[CartRepo] token updated (isGuest=$isGuest)');
  }

  /// Whether the current session is a guest.
  bool get isGuest => _isGuest;

  /// The current token value (for reading from the bloc).
  String? get currentToken => _token;

  /// Cart requests use a client whose headers mirror the working Postman
  /// request exactly (only `is-cookie-exist: 0` + Bearer). See
  /// [GraphQLClientProvider.buildCartClient] for why.
  GraphQLClient get _authedClient =>
      GraphQLClientProvider.buildCartClient(token: _token);

  /// Create a guest cart token
  Future<CartTokenResponse> createCartToken() async {
    debugPrint('[CartRepo] creating cart token...');
    final result = await client.mutate(
      MutationOptions(
        document: gql(CartMutations.createCartToken),
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      debugPrint('[CartRepo] createCartToken error: ${result.exception}');
      throw result.exception!;
    }

    final data = result.data?['createCartToken']?['cartToken'];
    if (data == null) {
      throw Exception('Failed to create cart token');
    }

    final response = CartTokenResponse.fromJson(data as Map<String, dynamic>);
    debugPrint('[CartRepo] cart token created');
    return response;
  }

  /// Add product to cart
  Future<CartModel> addToCart({
    int? cartId,
    required int productId,
    required int quantity,
    List<String>? downloadableLinks,
    List<Map<String, int>>? groupedItems,
    List<Map<String, dynamic>>? bundleOptions,
    Map<String, dynamic>? bookingData,
    int? selectedConfigurableOption,
    List<Map<String, dynamic>>? superAttribute,
  }) async {
    debugPrint(
      '[CartRepo] addToCart: productId=$productId, qty=$quantity, '
      'links=$downloadableLinks, groupedItems=$groupedItems, bundleOptions=$bundleOptions, '
      'bookingData=$bookingData, configurableOption=$selectedConfigurableOption, superAttribute=$superAttribute',
    );
    final Map<String, dynamic> variables = {
      'productId': productId,
      'quantity': quantity,
    };

    String mutation;

    if (selectedConfigurableOption != null) {
      mutation = CartMutations.addConfigurableProductToCart;
      variables['selectedConfigurableOption'] = selectedConfigurableOption;
      if (superAttribute != null && superAttribute.isNotEmpty) {
        variables['superAttribute'] = superAttribute;
      }
    } else if (bookingData != null && bookingData.isNotEmpty) {
      mutation = CartMutations.addBookingProductToCart;
      final bookingPayload = _buildBookingPayload(bookingData);
      variables['booking'] = jsonEncode(bookingPayload['booking']);
      final specialNote = bookingPayload['specialNote']?.toString().trim();
      if (specialNote != null && specialNote.isNotEmpty) {
        variables['specialNote'] = specialNote;
      }
    } else if (bundleOptions != null && bundleOptions.isNotEmpty) {
      mutation = CartMutations.addBundleProductToCart;
      final bundlePayload = _buildBundlePayload(bundleOptions);
      variables['bundleOptions'] = jsonEncode(bundlePayload['options']);
      variables['bundleOptionQty'] = jsonEncode(bundlePayload['qty']);
    } else if (groupedItems != null && groupedItems.isNotEmpty) {
      mutation = CartMutations.addGroupedProductToCart;
      variables['groupedQty'] = jsonEncode(
        _buildGroupedQtyPayload(groupedItems),
      );
    } else if (downloadableLinks != null && downloadableLinks.isNotEmpty) {
      mutation = CartMutations.addDownloadableProductToCart;
      variables['links'] = downloadableLinks
          .map((id) => int.tryParse(id))
          .whereType<int>()
          .toList();
    } else {
      mutation = CartMutations.addSimpleProductToCart;
    }

    if (cartId != null) {
      variables['cartId'] = cartId;
    }

    debugPrint('[CartRepo] addToCart mutation: $mutation');
    debugPrint('[CartRepo] addToCart variables: $variables');

    final result = await _authedClient.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: variables,
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      debugPrint('[CartRepo] addToCart error: ${result.exception}');
      if (result.exception?.graphqlErrors.isNotEmpty == true) {
        for (final error in result.exception!.graphqlErrors) {
          debugPrint('[CartRepo] GraphQL error: ${error.message}');
        }
      }
      if (result.exception?.linkException != null) {
        debugPrint('[CartRepo] Link error: ${result.exception!.linkException}');
      }
      debugPrint('[CartRepo] addToCart raw data on error: ${result.data}');
      throw result.exception!;
    }

    // NEW schema: { addItemToCart: { success, message, cart { ... } } }
    final payload = result.data?['addItemToCart'] as Map<String, dynamic>?;
    if (payload == null) {
      debugPrint('[CartRepo] addToCart null payload: ${result.data}');
      throw Exception('Failed to add product to cart');
    }
    if (payload['success'] == false) {
      final msg = payload['message']?.toString() ?? 'Failed to add product';
      debugPrint('[CartRepo] addToCart server-side failure: $msg');
      throw Exception(msg);
    }

    final data = payload['cart'] as Map<String, dynamic>?;
    if (data == null) {
      debugPrint('[CartRepo] addToCart: success but no cart in payload');
      throw Exception('Failed to add product to cart');
    }

    debugPrint('[CartRepo] addToCart success: ${payload['message']}');
    return CartModel.fromJson(data);
  }

  Map<String, Map<String, dynamic>> _buildBundlePayload(
    List<Map<String, dynamic>> bundleOptions,
  ) {
    final Map<String, List<int>> options = {};
    final Map<String, int> qty = {};

    for (final option in bundleOptions) {
      final optionId = int.tryParse('${option['bundleOptionId']}') ?? 0;
      if (optionId <= 0) continue;

      final optionKey = optionId.toString();
      final selectedIds =
          (option['bundleOptionProductId'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((id) => int.tryParse('$id') ?? 0)
              .where((id) => id > 0)
              .toList();

      if (selectedIds.isEmpty) continue;

      final existing = options[optionKey] ?? <int>[];
      for (final id in selectedIds) {
        if (!existing.contains(id)) {
          existing.add(id);
        }
      }
      options[optionKey] = existing;

      final selectedQty = int.tryParse('${option['qty']}') ?? 1;
      qty[optionKey] = selectedQty > 0 ? selectedQty : 1;
    }

    return {'options': options, 'qty': qty};
  }

  Map<String, dynamic> _buildBookingPayload(Map<String, dynamic> bookingData) {
    final type = bookingData['type']?.toString().toLowerCase().trim() ?? '';
    final Map<String, dynamic> booking = {'type': type};

    switch (type) {
      case 'event':
        booking['qty'] = Map<String, dynamic>.from(
          bookingData['qty'] as Map? ?? const {},
        );
        break;
      case 'rental':
        booking['renting_type'] =
            bookingData['renting_type']?.toString().toLowerCase().trim() ??
            'daily';
        if ((booking['renting_type'] as String) == 'daily') {
          booking['date_from'] = bookingData['date_from'];
          booking['date_to'] = bookingData['date_to'];
        } else {
          booking['date'] = bookingData['date'];
          booking['slot'] = bookingData['slot'];
        }
        break;
      case 'default':
      case 'appointment':
      case 'table':
        booking['date'] = bookingData['date'];
        booking['slot'] = bookingData['slot'];
        break;
    }

    return {'booking': booking, 'specialNote': bookingData['specialNote']};
  }

  Map<String, int> _buildGroupedQtyPayload(
    List<Map<String, int>> groupedItems,
  ) {
    final Map<String, int> groupedQty = {};

    for (final item in groupedItems) {
      final productId = item['productId'] ?? 0;
      final quantity = item['quantity'] ?? 0;
      if (productId <= 0 || quantity <= 0) continue;

      groupedQty[productId.toString()] = quantity;
    }

    return groupedQty;
  }

  /// Read / fetch the current cart.
  /// Retries once on timeout (cold-start scenario).
  Future<CartModel> getCart({int attempt = 1}) async {
    debugPrint('[CartRepo] getCart... (attempt $attempt)');
    // NEW schema: `cartDetail` is a QUERY, not a mutation.
    final result = await _authedClient.query(
      QueryOptions(
        document: gql(CartMutations.getCart),
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    // Raw payload logging to diagnose empty-cart issues.
    debugPrint('[CartRepo] getCart raw data: ${result.data}');

    if (result.hasException) {
      // Log every GraphQL error explicitly. A schema error (e.g. querying a
      // field that does not exist) makes the server reject the WHOLE query and
      // return data:null — which is indistinguishable from an empty cart unless
      // we print it. Never let these fail silently again.
      for (final e in result.exception!.graphqlErrors) {
        debugPrint('[CartRepo] getCart GraphQL error: ${e.message}');
      }

      // A ServerException with an EMPTY graphqlErrors list means the server
      // itself threw (HTTP 500) — the query was schema-valid but execution
      // crashed. Retrying cannot help, and the response body carries the real
      // reason, so surface it instead of silently retrying 3 times.
      final linkEx = result.exception!.linkException;
      if (linkEx is ServerException) {
        debugPrint('[CartRepo] getCart SERVER ERROR (HTTP 500 likely).');
        debugPrint(
          '[CartRepo] server response: ${linkEx.parsedResponse?.response}',
        );
      }

      // Retry only on transient network errors.
      if (ErrorMapper.isNetworkError(result.exception!) && attempt < 3) {
        debugPrint(
          '[CartRepo] getCart timeout — retrying (attempt ${attempt + 1})...',
        );
        await Future.delayed(Duration(milliseconds: 500 * attempt));
        return getCart(attempt: attempt + 1);
      }

      // IMPORTANT: A *partial* GraphQL error (e.g. one unresolved field) can
      // still return valid cart data. Only abort if there is genuinely no data.
      final partial = result.data?['cartDetail'];
      if (partial == null) {
        debugPrint('[CartRepo] getCart error (no data): ${result.exception}');
        throw result.exception!;
      }
      debugPrint(
        '[CartRepo] getCart: GraphQL error but data present — using it. '
        '${result.exception}',
      );
      return CartModel.fromJson(partial as Map<String, dynamic>);
    }

    final data = result.data?['cartDetail'];
    if (data == null) {
      debugPrint('[CartRepo] getCart: empty cart (cartDetail is null)');
      return CartModel.empty;
    }

    final cart = CartModel.fromJson(data as Map<String, dynamic>);
    debugPrint(
      '[CartRepo] getCart: ${cart.items.length} items, '
      'itemsQty=${cart.itemsQty}, total=${cart.grandTotal}',
    );
    return cart;
  }

  /// Update cart item quantity
  Future<CartModel> updateCartItem({
    required int cartItemId,
    required int quantity,
  }) async {
    debugPrint('[CartRepo] updateCartItem: itemId=$cartItemId, qty=$quantity');
    final result = await _authedClient.mutate(
      MutationOptions(
        document: gql(CartMutations.updateCartItem),
        variables: {
          'qty': [
            {'cartItemId': cartItemId, 'quantity': quantity},
          ],
        },
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      debugPrint('[CartRepo] updateCartItem error: ${result.exception}');
      throw result.exception!;
    }

    final payload = result.data?['updateItemToCart'] as Map<String, dynamic>?;
    final data = payload?['cart'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception(
        payload?['message']?.toString() ?? 'Failed to update cart item',
      );
    }

    return CartModel.fromJson(data);
  }

  /// Remove item from cart
  Future<CartModel> removeCartItem({required int cartItemId}) async {
    debugPrint('[CartRepo] removeCartItem: itemId=$cartItemId');
    final result = await _authedClient.mutate(
      MutationOptions(
        document: gql(CartMutations.removeCartItem),
        variables: {'cartItemId': cartItemId},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      debugPrint('[CartRepo] removeCartItem error: ${result.exception}');
      throw result.exception!;
    }

    // Schema op is `removeCartItem` (verified against Bagisto's cart.graphql).
    final payload = result.data?['removeCartItem'] as Map<String, dynamic>?;
    final data = payload?['cart'] as Map<String, dynamic>?;
    if (data == null) {
      return CartModel.empty;
    }

    return CartModel.fromJson(data);
  }

  /// Apply coupon code to cart
  Future<CartModel> applyCoupon({required String couponCode}) async {
    debugPrint('[CartRepo] applyCoupon: $couponCode');
    final result = await _authedClient.mutate(
      MutationOptions(
        document: gql(CartMutations.applyCoupon),
        variables: {'code': couponCode},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      debugPrint('[CartRepo] applyCoupon error: ${result.exception}');
      throw result.exception!;
    }

    final payload = result.data?['applyCoupon'] as Map<String, dynamic>?;
    final data = payload?['cart'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception(
        payload?['message']?.toString() ?? 'Failed to apply coupon',
      );
    }

    return CartModel.fromJson(data);
  }

  /// Remove applied coupon from cart
  Future<CartModel> removeCoupon() async {
    debugPrint('[CartRepo] removeCoupon');
    final result = await _authedClient.mutate(
      MutationOptions(
        document: gql(CartMutations.removeCoupon),
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      debugPrint('[CartRepo] removeCoupon error: ${result.exception}');
      throw result.exception!;
    }

    final payload = result.data?['removeCoupon'] as Map<String, dynamic>?;
    final data = payload?['cart'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception(
        payload?['message']?.toString() ?? 'Failed to remove coupon',
      );
    }

    return CartModel.fromJson(data);
  }

  /// Merge a guest cart into the logged-in user's cart.
  /// Must be called AFTER switching the token to the auth access token.
  /// Source: nextjs-commerce/src/graphql/cart/mutations/CreateMergeCart.ts
  Future<CartModel> mergeCart({required int cartId}) async {
    debugPrint('[CartRepo] mergeCart: cartId=$cartId');
    final result = await _authedClient.mutate(
      MutationOptions(
        document: gql(CartMutations.mergeCart),
        variables: {'cartId': cartId},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      debugPrint('[CartRepo] mergeCart error: ${result.exception}');
      throw result.exception!;
    }

    final data = result.data?['createMergeCart']?['mergeCart'];
    if (data == null) {
      throw Exception('Failed to merge cart');
    }

    debugPrint('[CartRepo] mergeCart success: ${data['message']}');
    return CartModel.fromJson(data as Map<String, dynamic>);
  }
}
