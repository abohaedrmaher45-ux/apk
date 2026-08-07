// Cart models matching Bagisto GraphQL schema.
// Derived from: nextjs-commerce/src/graphql/cart/mutations/

import 'dart:convert';

import '../../../../core/currency/currency_formatter.dart';

class CartModel {
  final int id;
  final String? cartToken;
  final double subtotal;
  final String? formattedSubtotal;
  final double taxAmount;
  final String? formattedTaxAmount;
  final double shippingAmount;
  final String? formattedShippingAmount;
  final double grandTotal;
  final String? formattedGrandTotal;
  final double discountAmount;
  final String? formattedDiscountAmount;
  final String? couponCode;
  final int itemsCount;
  final int itemsQty;
  final bool isGuest;
  final List<CartItemModel> items;

  const CartModel({
    required this.id,
    this.cartToken,
    this.subtotal = 0,
    this.formattedSubtotal,
    this.taxAmount = 0,
    this.formattedTaxAmount,
    this.shippingAmount = 0,
    this.formattedShippingAmount,
    this.grandTotal = 0,
    this.formattedGrandTotal,
    this.discountAmount = 0,
    this.formattedDiscountAmount,
    this.couponCode,
    this.itemsCount = 0,
    this.itemsQty = 0,
    this.isGuest = true,
    this.items = const [],
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    // The current Bagisto schema returns a nested `formattedPrice { ... }`
    // object for the display strings, and uses camelCase totals such as
    // `subTotal` / `grandTotal`. Older code expected flat `formattedGrandTotal`
    // etc. — read both so the model works regardless of source.
    final fp = json['formattedPrice'] is Map<String, dynamic>
        ? json['formattedPrice'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return CartModel(
      id: _parseInt(json['id']),
      cartToken: json['cartToken'] as String?,
      subtotal: _parseDouble(json['subTotal'] ?? json['subtotal']),
      formattedSubtotal:
          (fp['subTotal'] ?? json['formattedSubtotal']) as String?,
      taxAmount: _parseDouble(json['taxTotal'] ?? json['taxAmount']),
      formattedTaxAmount:
          (fp['taxTotal'] ?? json['formattedTaxAmount']) as String?,
      shippingAmount: _parseDouble(json['shippingAmount']),
      formattedShippingAmount:
          (fp['shippingAmount'] ?? json['formattedShippingAmount']) as String?,
      grandTotal: _parseDouble(json['grandTotal']),
      formattedGrandTotal:
          (fp['grandTotal'] ?? json['formattedGrandTotal']) as String?,
      discountAmount: _parseDouble(json['discountAmount']),
      formattedDiscountAmount:
          (fp['discountAmount'] ?? json['formattedDiscountAmount']) as String?,
      couponCode: json['couponCode'] as String?,
      itemsCount: _parseInt(json['itemsCount']),
      itemsQty: _parseInt(json['itemsQty']),
      isGuest: json['isGuest'] as bool? ?? true,
      items: _parseItems(json['items']),
    );
  }

  /// Empty cart
  static const CartModel empty = CartModel(id: 0);

  bool get isEmpty => items.isEmpty;

  bool get hasCoupon => couponCode != null && couponCode!.isNotEmpty;

  /// Whether the cart contains only virtual or downloadable products (no shipping needed)
  bool get isVirtualOnly =>
      items.isNotEmpty &&
      items.every(
        (item) => item.isVirtual || item.isDownloadable || item.isBooking,
      );

  CartModel copyWith({
    int? id,
    String? cartToken,
    double? subtotal,
    String? formattedSubtotal,
    double? taxAmount,
    String? formattedTaxAmount,
    double? shippingAmount,
    String? formattedShippingAmount,
    double? grandTotal,
    String? formattedGrandTotal,
    double? discountAmount,
    String? formattedDiscountAmount,
    String? couponCode,
    int? itemsCount,
    int? itemsQty,
    bool? isGuest,
    List<CartItemModel>? items,
    bool clearCoupon = false,
  }) {
    return CartModel(
      id: id ?? this.id,
      cartToken: cartToken ?? this.cartToken,
      subtotal: subtotal ?? this.subtotal,
      formattedSubtotal: formattedSubtotal ?? this.formattedSubtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      formattedTaxAmount: formattedTaxAmount ?? this.formattedTaxAmount,
      shippingAmount: shippingAmount ?? this.shippingAmount,
      formattedShippingAmount:
          formattedShippingAmount ?? this.formattedShippingAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      formattedGrandTotal: formattedGrandTotal ?? this.formattedGrandTotal,
      discountAmount: discountAmount ?? this.discountAmount,
      formattedDiscountAmount:
          formattedDiscountAmount ?? this.formattedDiscountAmount,
      couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
      itemsCount: itemsCount ?? this.itemsCount,
      itemsQty: itemsQty ?? this.itemsQty,
      isGuest: isGuest ?? this.isGuest,
      items: items ?? this.items,
    );
  }

  static List<CartItemModel> _parseItems(dynamic json) {
    if (json == null) return [];

    // NEW schema: `items` is a plain list of item objects.
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(CartItemModel.fromJson)
          .toList();
    }

    // Legacy Relay-style: `items { edges { node { ... } } }`.
    if (json is Map<String, dynamic>) {
      final edges = json['edges'] as List<dynamic>?;
      if (edges == null) return [];
      return edges
          .map((e) => CartItemModel.fromJson(e['node'] as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }
}

class CartItemModel {
  final int id;
  final int cartId;
  final int productId;
  final String name;
  final double price;
  final String? formattedPrice;
  final double total;
  final String? formattedTotal;
  final String? baseImage; // JSON string with image URLs
  final String? sku;
  final int quantity;
  final String? type;
  final String? productUrlKey;
  final bool canChangeQty;
  final List<String> options;

  const CartItemModel({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.name,
    required this.price,
    this.formattedPrice,
    this.total = 0,
    this.formattedTotal,
    this.baseImage,
    this.sku,
    required this.quantity,
    this.type,
    this.productUrlKey,
    this.canChangeQty = true,
    this.options = const [],
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    // NEW schema: item has a nested `formattedPrice { price, total, ... }`.
    // Older schema had flat `formattedPrice` / `formattedTotal` strings.
    final fp = json['formattedPrice'] is Map<String, dynamic>
        ? json['formattedPrice'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final String? formattedPriceStr = fp.isNotEmpty
        ? fp['price'] as String?
        : json['formattedPrice'] as String?;
    final String? formattedTotalStr = fp.isNotEmpty
        ? fp['total'] as String?
        : json['formattedTotal'] as String?;

    // The `product { ... }` relation is NOT requested: the working Postman
    // query only pulls `customizableOptions` through it, and asking for images
    // there is not supported by this backend.
    final product = json['product'] is Map<String, dynamic>
        ? json['product'] as Map<String, dynamic>
        : const <String, dynamic>{};

    // VERIFIED against the live Postman response: `additional` comes back as a
    // JSON OBJECT (not a string), shaped like:
    //   { cart_id, quantity, product_id, attributes: [] }
    // It contains NO image and NO urlKey, so it cannot supply either.
    final additional = _decodeAdditional(json['additional']);

    // No image source exists in the cartDetail payload on this backend, so
    // imageUrl will normally be null and the UI shows its placeholder icon.
    // These fallbacks only fire if a caller (e.g. a future query) supplies one.
    final resolvedImageUrl = _resolveImageUrl(
      product['images'] ?? product['baseImage'] ?? json['baseImage'],
    );

    return CartItemModel(
      id: CartModel._parseInt(json['id']),
      cartId: CartModel._parseInt(json['cartId']),
      productId: CartModel._parseInt(json['productId']),
      name: json['name'] as String? ?? '',
      price: CartModel._parseDouble(json['price']),
      formattedPrice: formattedPriceStr,
      total: CartModel._parseDouble(json['total']),
      formattedTotal: formattedTotalStr,
      baseImage: resolvedImageUrl,
      sku: json['sku'] as String?,
      quantity: CartModel._parseInt(json['quantity']),
      // `type` comes back on the item itself — no product relation needed.
      type: (json['type'] ?? product['type']) as String?,
      productUrlKey:
          (product['urlKey'] ??
                  json['productUrlKey'] ??
                  additional['urlKey'] ??
                  additional['url_key'])
              as String?,
      canChangeQty: json['canChangeQty'] as bool? ?? true,
      // VERIFIED: selected options live under `additional.attributes` (a list).
      // The bare `additional` object also holds cart_id/quantity/product_id,
      // which must NOT be rendered as options.
      options: _parseOptions(json['options'] ?? additional['attributes']),
    );
  }

  /// `additional` arrives as a JSON-encoded string (or already-decoded map).
  /// Returns an empty map on anything unexpected — never throws.
  static Map<String, dynamic> _decodeAdditional(dynamic value) {
    if (value == null) return const <String, dynamic>{};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const <String, dynamic>{};
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    return const <String, dynamic>{};
  }

  /// Resolve a usable image URL from any of the shapes the API may return:
  ///  • a nested object: { mediumImageUrl, smallImageUrl, originalImageUrl }
  ///  • a nested object with snake_case keys
  ///  • a JSON-encoded string of either of the above
  ///  • a plain URL string
  static String? _resolveImageUrl(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return _resolveImageUrl(jsonDecode(trimmed));
        } catch (_) {
          return trimmed;
        }
      }
      return trimmed; // already a plain URL
    }

    if (value is List) {
      for (final entry in value) {
        final url = _resolveImageUrl(entry);
        if (url != null) return url;
      }
      return null;
    }

    if (value is Map) {
      final map = value.cast<String, dynamic>();
      // `url` is what this schema returns on Product.images. The remaining
      // keys cover other/legacy shapes. `path` is a last resort (relative).
      final candidate =
          map['url'] ??
          map['mediumImageUrl'] ??
          map['medium_image_url'] ??
          map['smallImageUrl'] ??
          map['small_image_url'] ??
          map['largeImageUrl'] ??
          map['large_image_url'] ??
          map['originalImageUrl'] ??
          map['original_image_url'] ??
          map['path'];
      return candidate is String && candidate.trim().isNotEmpty
          ? candidate.trim()
          : null;
    }

    return null;
  }

  /// Resolved product image URL (already normalized in the constructor).
  String? get imageUrl =>
      (baseImage != null && baseImage!.isNotEmpty) ? baseImage : null;

  /// Total price for this item (price * quantity)
  double get totalPrice => price * quantity;

  String get displayPrice => CurrencyFormatter.normalizeDigits(
    formattedPrice ?? CurrencyFormatter.formatAmount(price),
  );

  String get displayTotal => CurrencyFormatter.normalizeDigits(
    formattedTotal ??
        CurrencyFormatter.formatAmount(total > 0 ? total : totalPrice),
  );

  /// Whether this is a virtual product
  bool get isVirtual => type == 'virtual';

  /// Whether this is a downloadable product
  bool get isDownloadable => type == 'downloadable';

  /// Whether this is a booking product
  bool get isBooking => type == 'booking';

  static List<String> _parseOptions(dynamic value) {
    final lines = _extractOptions(value);
    return lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet()
        .toList();
  }

  static List<String> _extractOptions(dynamic value) {
    if (value == null) return const [];

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const [];
      try {
        return _extractOptions(jsonDecode(trimmed));
      } catch (_) {
        return <String>[trimmed];
      }
    }

    if (value is List) {
      return value.expand(_extractOptions).toList();
    }

    if (value is Map) {
      // Try label + value pattern (e.g. {"label": "Color", "value": "Blue"})
      final label = value['label']?.toString().trim();
      final rawOptionValue =
          value['value'] ?? value['optionValue'] ?? value['option_value'];
      final formattedValue = _formatOptionValue(rawOptionValue);

      if ((label ?? '').isNotEmpty && formattedValue.isNotEmpty) {
        return <String>['${label!} : $formattedValue'];
      }

      // Try attributeName + optionLabel pattern
      // (e.g. {"attributeName": "Booking From", "optionLabel": "28th Mar, 2026"})
      final attrName =
          (value['attributeName'] ??
                  value['attribute_name'] ??
                  value['attributename'])
              ?.toString()
              .trim();
      final optLabel =
          (value['optionLabel'] ??
                  value['option_label'] ??
                  value['optionlabel'])
              ?.toString()
              .trim();

      if ((attrName ?? '').isNotEmpty && (optLabel ?? '').isNotEmpty) {
        return <String>['$attrName : $optLabel'];
      }

      final lines = <String>[];
      value.forEach((key, entryValue) {
        final k = '$key';
        // Skip internal/meta keys
        if (k == '__typename' ||
            k == 'optionId' ||
            k == 'option_id' ||
            k == 'optionid' ||
            k == 'id')
          return;

        final entryFormatted = _formatOptionValue(entryValue);
        if (entryFormatted.isNotEmpty &&
            entryValue is! Map &&
            entryValue is! List &&
            k != 'label') {
          lines.add('${_normalizeOptionLabel(k)} : $entryFormatted');
        } else {
          lines.addAll(_extractOptions(entryValue));
        }
      });
      return lines;
    }

    return <String>[value.toString()];
  }

  static String _formatOptionValue(dynamic value) {
    if (value == null) return '';

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return '';
      try {
        final decoded = jsonDecode(trimmed);
        return _formatOptionValue(decoded);
      } catch (_) {
        return trimmed;
      }
    }

    if (value is List) {
      return value
          .map(_formatOptionValue)
          .where((entry) => entry.isNotEmpty)
          .join(', ');
    }

    if (value is Map) {
      if (value.containsKey('label') && value.containsKey('value')) {
        return _formatOptionValue(value['value']);
      }

      final pieces = <String>[];
      value.forEach((key, entryValue) {
        if ('$key' == '__typename') return;
        final entryFormatted = _formatOptionValue(entryValue);
        if (entryFormatted.isEmpty) return;
        if (entryValue is Map || entryValue is List) {
          pieces.add(entryFormatted);
        } else {
          pieces.add('${_normalizeOptionLabel('$key')}: $entryFormatted');
        }
      });
      return pieces.join(', ');
    }

    return value.toString();
  }

  static String _normalizeOptionLabel(String raw) {
    return raw
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .trim();
  }
}

/// Response from createCartToken
class CartTokenResponse {
  final int id;
  final String cartToken;
  final String? sessionToken;
  final bool isGuest;
  final bool success;
  final String? message;

  const CartTokenResponse({
    required this.id,
    required this.cartToken,
    this.sessionToken,
    this.isGuest = true,
    this.success = false,
    this.message,
  });

  factory CartTokenResponse.fromJson(Map<String, dynamic> json) {
    return CartTokenResponse(
      id: CartModel._parseInt(json['id']),
      cartToken: json['cartToken'] as String? ?? '',
      sessionToken: json['sessionToken'] as String?,
      isGuest: json['isGuest'] as bool? ?? true,
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }
}
