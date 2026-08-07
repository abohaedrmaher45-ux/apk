import 'dart:convert';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/locale/locale_cubit.dart';
import '../../../../core/graphql/queries.dart';
import '../models/home_models.dart';
import '../models/mobile_banner.dart';
import 'banner_repository.dart';

/// Repository that fetches all data needed for the homepage.
///
/// Uses:
///   • `ThemeQueries.getThemeCustomization` → homepage section layout
///   • `CategoryQueries.getHomeCategories` → category carousel
///   • `ProductQueries.getProducts` → product carousels (Featured, Hot Deals, New, etc.)
class HomeRepository {
  final GraphQLClient _client;
  final BannerRepository _bannerRepository;

  HomeRepository({required GraphQLClient client})
    : _client = client,
      _bannerRepository = BannerRepository(client: client);

  /// جلب البنرات المخصصة (نظام البنرات المتقدم) عبر GraphQL.
  /// اختيارية للصفحة الرئيسية — تُرجع قائمة فارغة عند أي خطأ.
  Future<List<MobileBanner>> fetchBanners() => _bannerRepository.fetchBanners();

  /// Fetches the theme customization entries that define homepage sections.
  Future<List<ThemeCustomization>> fetchThemeCustomizations() async {
    // Read the user's preferred locale for selecting the right translation
    final prefs = await SharedPreferences.getInstance();
    final locale = prefs.getString(LocaleCubit.localeKey) ?? 'en';

    final result = await _client.query(
      QueryOptions(
        document: gql(ThemeQueries.getThemeCustomization),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    // Theme customizations are optional for the homepage. If they fail
    // (e.g. slow network, endpoint issue) we must NOT abort the whole home
    // load — products are fetched separately and can still be shown.
    // So on error we log and return an empty list instead of throwing.
    if (result.hasException) {
      // ignore: avoid_print
      print(
        '⚠️ [HomeRepository] theme customizations failed (non-fatal): '
        '${result.exception}',
      );
      return <ThemeCustomization>[];
    }

    final list = result.data?['themeCustomization'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(
          (node) => ThemeCustomization.fromJson(node, preferredLocale: locale),
        )
        .where((tc) => tc.status)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Fetches categories for the horizontal category carousel.
  Future<List<HomeCategory>> fetchHomeCategories() async {
    final result = await _client.query(
      QueryOptions(
        document: gql(CategoryQueries.getHomeCategories),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    // Categories are also optional for showing products. Don't abort the
    // whole home load if only the category carousel fails.
    if (result.hasException) {
      // ignore: avoid_print
      print(
        '⚠️ [HomeRepository] home categories failed (non-fatal): '
        '${result.exception}',
      );
      return <HomeCategory>[];
    }

    final list = result.data?['homeCategories'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(HomeCategory.fromJson)
        .where((c) => c.numericId != 1) // exclude root category
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  /// Fetches products with optional filter JSON and sorting.
  ///
  /// Used by product_carousel sections: Featured Products, Hot Deals,
  /// New Products, etc.
  /// Sort key options per Bagisto API: PRICE, TITLE, NEWEST, BEST_SELLING
  Future<List<HomeProduct>> fetchProducts({
    int first = 8,
    String? filter,
    String sortKey = 'NEWEST',
    bool reverse = true,
  }) async {
    // Build inline input entries for allProducts(input:[{key,value}]).
    final entries = <String>[
      '{ key: "page", value: "1" }',
      '{ key: "limit", value: "$first" }',
    ];

    // Translate common home sort keys to Bagisto sort values.
    String? sort;
    switch (sortKey.toUpperCase()) {
      case 'NEWEST':
      case 'NEW':
        sort = 'created_at-desc';
        break;
      case 'PRICE':
        sort = reverse ? 'price-desc' : 'price-asc';
        break;
      case 'TITLE':
      case 'NAME':
        sort = reverse ? 'name-desc' : 'name-asc';
        break;
      case 'BEST_SELLING':
        sort = 'created_at-desc';
        break;
    }
    if (sort != null) entries.add('{ key: "sort", value: "$sort" }');

    // Expand a JSON filter map (e.g. {"new":"1","featured":"1"}).
    if (filter != null && filter.isNotEmpty) {
      try {
        final map = jsonDecode(filter) as Map<String, dynamic>;
        map.forEach((k, v) {
          if (v == null) return;
          final val = v.toString().replaceAll('"', r'\"');
          if (val.isEmpty) return;
          final key = k.replaceAll('"', r'\"');
          entries.add('{ key: "$key", value: "$val" }');
        });
      } catch (_) {}
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(ProductQueries.buildAllProductsQuery(entries.join(', '))),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    if (result.hasException) {
      throw Exception('Failed to load products: ${result.exception}');
    }

    final list = result.data?['allProducts']?['data'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(HomeProduct.fromJson)
        .toList();
  }
}
