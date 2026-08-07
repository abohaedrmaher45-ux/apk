import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/category/data/models/product_model.dart';
import '../../features/home/data/models/home_models.dart';

class RecentlyViewedProductsService {
  RecentlyViewedProductsService._();

  static const _prefsKey = 'recently_viewed_products';
  static const _maxItems = 12;
  static const _trackKey = 'settings_track_recently_viewed';

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static bool _isTrackingEnabled(SharedPreferences prefs) {
    return prefs.getBool(_trackKey) ?? true;
  }

  static Future<List<HomeProduct>> getRecentProducts() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_isTrackingEnabled(prefs)) return const <HomeProduct>[];
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const <HomeProduct>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <HomeProduct>[];

      return decoded
          .whereType<Map<String, dynamic>>()
          // Drop any formatted price strings that older app versions may have
          // already written to disk with a stale currency symbol. Without this,
          // entries cached before the currency switch would keep showing "$".
          .map(
            (json) => {
              ...json,
              'formattedPrice': null,
              'formattedMinimumPrice': null,
              'formattedSpecialPrice': null,
            },
          )
          .map(HomeProduct.fromJson)
          .where(
            (product) => product.name.isNotEmpty && product.urlKey.isNotEmpty,
          )
          .toList();
    } catch (_) {
      return const <HomeProduct>[];
    }
  }

  static Future<void> trackProduct(ProductModel product) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_isTrackingEnabled(prefs)) return;

    final numericId =
        product.numericId ?? int.tryParse(product.id.split('/').last);
    final name = product.name?.trim() ?? '';
    final urlKey = product.urlKey?.trim() ?? '';

    if (numericId == null || numericId <= 0 || name.isEmpty || urlKey.isEmpty) {
      return;
    }

    final current = await getRecentProducts();
    final recentProduct = HomeProduct(
      id: product.id,
      numericId: numericId,
      sku: product.sku ?? '',
      type: product.type ?? 'simple',
      name: name,
      urlKey: urlKey,
      baseImageUrl: product.baseImageUrl,
      price: product.price ?? 0,
      minimumPrice: product.minimumPrice,
      specialPrice: product.specialPrice,
      // NOTE: the backend-formatted price strings (e.g. "$45.00") are
      // deliberately NOT persisted.
      //
      // They embed the CURRENCY SYMBOL that was active at the moment the
      // product was viewed. Once written to SharedPreferences they are replayed
      // forever, so after the admin switched the channel currency to EUR the
      // "Recently viewed" row kept showing the old "$" prices while the rest of
      // the home screen correctly showed "€".
      //
      // Leaving these null makes `HomeProduct.displayPriceLabel` fall back to
      // `CurrencyFormatter.formatAmount(...)`, which renders the RAW number
      // with the CURRENT backend-synced symbol. See home_models.dart.
      formattedPrice: null,
      formattedMinimumPrice: null,
      formattedSpecialPrice: null,
      // Persist the CURRENCY CODE (not the formatted string). The code is
      // stable data; the formatted string is a stale snapshot of a symbol.
      // displayPriceLabel uses this to render "\u20ac" rather than defaulting to "$".
      currencyCode: product.currencyCode,
      isSaleable: product.isSaleable ?? true,
      averageRating: product.averageRating,
      reviewCount: product.reviewCount,
    );

    final updated = <HomeProduct>[
      recentProduct,
      ...current.where(
        (item) =>
            item.numericId != recentProduct.numericId &&
            item.urlKey != recentProduct.urlKey,
      ),
    ].take(_maxItems).toList();

    await prefs.setString(
      _prefsKey,
      jsonEncode(updated.map((product) => product.toJson()).toList()),
    );
    changes.value++;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    changes.value++;
  }
}
