import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../../core/graphql/queries.dart';
import '../../../home/data/models/home_models.dart' show BannerImage, ThemeCustomization;
import '../models/category_model.dart';
import '../models/filter_model.dart';
import '../models/product_model.dart';

class CategoryRepository {
  final GraphQLClient client;

  CategoryRepository({required this.client});

  /// Fetch tree categories (hierarchical)
  /// Maps to: GET_TREE_CATEGORIES from nextjs-commerce
  Future<List<CategoryModel>> getTreeCategories({int? parentId}) async {
    // Real Bagisto homeCategories expects parent_id as a String value.
    final Map<String, dynamic> variables = {
      'parentId': (parentId ?? 1).toString(),
    };

    final result = await client.query(
      QueryOptions(
        document: gql(CategoryQueries.getTreeCategories),
        variables: variables,
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final data = result.data?['homeCategories'] as List<dynamic>?;
    if (data == null) return [];

    return data
        .map((json) => CategoryModel.fromTreeJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch flat home categories
  /// Maps to: GET_HOME_CATEGORIES from nextjs-commerce
  Future<List<CategoryModel>> getHomeCategories() async {
    final result = await client.query(
      QueryOptions(
        document: gql(CategoryQueries.getHomeCategories),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final list = result.data?['homeCategories'] as List<dynamic>? ?? [];

    return list
        .whereType<Map<String, dynamic>>()
        .map(CategoryModel.fromHomeCategoryJson)
        .toList();
  }

  /// Fetch products with pagination & filters.
  /// Uses the real Bagisto `allProducts(input: [{key,value}])` query.
  Future<PaginatedProducts> getProducts({
    String? query,
    String? sortKey,
    bool? reverse,
    int? first,
    int? last,
    String? after,
    String? before,
    String? channel,
    String? locale,
    String? filter,
  }) async {
    final entries = _buildProductInputEntries(
      filter: filter,
      sortKey: sortKey,
      reverse: reverse,
      limit: first,
      page: _pageFromCursor(after),
      query: query,
    );

    final result = await client.query(
      QueryOptions(
        document: gql(ProductQueries.buildAllProductsQuery(entries)),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    return PaginatedProducts.fromJson(result.data!);
  }

  /// Fetch products filtered by category.
  /// [useCacheFirst] - if true, returns cached data immediately.
  Future<PaginatedProducts> getFilterProducts({
    required String filter,
    String? sortKey,
    bool? reverse,
    int? first,
    int? last,
    String? after,
    String? before,
    bool useCacheFirst = false,
  }) async {
    final entries = _buildProductInputEntries(
      filter: filter,
      sortKey: sortKey,
      reverse: reverse,
      limit: first,
      page: _pageFromCursor(after),
    );

    debugPrint('[CategoryRepo] getFilterProducts input=[$entries]');

    final result = await client.query(
      QueryOptions(
        document: gql(ProductQueries.buildAllProductsQuery(entries)),
        fetchPolicy: useCacheFirst
            ? FetchPolicy.cacheFirst
            : FetchPolicy.cacheAndNetwork,
      ),
    );

    if (result.hasException) {
      debugPrint('[CategoryRepo] getFilterProducts error: ${result.exception}');
      throw result.exception!;
    }

    debugPrint(
      '[CategoryRepo] getFilterProducts total=${result.data?['allProducts']?['paginatorInfo']?['total']}',
    );
    return PaginatedProducts.fromJson(result.data!);
  }

  /// Decode a page number previously encoded as an `after` cursor.
  int _pageFromCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) return 1;
    return int.tryParse(cursor) ?? 1;
  }

  /// Escapes a value for safe inline use inside a GraphQL string literal.
  String _esc(String v) => v.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  /// Builds the inline `input` entries for `allProducts`, e.g.:
  ///   { key: "page", value: "1" }, { key: "limit", value: "20" },
  ///   { key: "category_id", value: "22" }, { key: "sort", value: "price-desc" }
  ///
  /// [filter] is the JSON map produced by ProductListState.buildFilterString()
  /// (e.g. {"category_id":"22","price":"5,10"}). [sortKey]/[reverse] come from
  /// the UI and are translated to Bagisto's `sort` value.
  String _buildProductInputEntries({
    String? filter,
    String? sortKey,
    bool? reverse,
    int? limit,
    int page = 1,
    String? query,
  }) {
    final parts = <String>[];
    void add(String key, String value) =>
        parts.add('{ key: "${_esc(key)}", value: "${_esc(value)}" }');

    add('page', page.toString());
    add('limit', (limit ?? 20).toString());

    if (query != null && query.trim().isNotEmpty) {
      add('name', query.trim());
      add('search', query.trim());
    }

    // Expand the JSON filter map into individual key/value entries.
    if (filter != null && filter.isNotEmpty) {
      try {
        final map = jsonDecode(filter) as Map<String, dynamic>;
        map.forEach((k, v) {
          if (v == null) return;
          final val = v.toString();
          if (val.isEmpty) return;
          add(k, val);
        });
      } catch (_) {
        // ignore malformed filter JSON
      }
    }

    final sort = _mapSort(sortKey, reverse);
    if (sort != null) add('sort', sort);

    return parts.join(', ');
  }

  /// Maps the app's sortKey + reverse flag to Bagisto's `sort` filter value.
  String? _mapSort(String? sortKey, bool? reverse) {
    if (sortKey == null) return null;
    final desc = reverse == true;
    switch (sortKey.toUpperCase()) {
      case 'TITLE':
      case 'NAME':
        return desc ? 'name-desc' : 'name-asc';
      case 'PRICE':
        return desc ? 'price-desc' : 'price-asc';
      case 'CREATED_AT':
      case 'LATEST':
      case 'NEW':
        return desc ? 'created_at-desc' : 'created_at-asc';
      default:
        return null;
    }
  }

  /// Fetch single product by URL key
  /// Maps to: GET_PRODUCT_BY_URL_KEY from nextjs-commerce
  Future<ProductModel> getProductByUrlKey(
    String urlKey, {
    String? productType,
  }) async {
    // Backend has no product(urlKey:) resolver. Resolve the numeric id from
    // the product list by matching urlKey, then fetch full details by id.
    final resolvedId = await _resolveProductIdByUrlKey(urlKey);
    if (resolvedId != null && resolvedId.isNotEmpty) {
      return getProductById(resolvedId, productType: productType);
    }
    throw Exception('Could not resolve product id for urlKey: $urlKey');
  }

  /// Look up a product's numeric id from its urlKey using the products list.
  Future<String?> _resolveProductIdByUrlKey(String urlKey) async {
    final page = await getProducts(first: 100);
    for (final p in page.products) {
      if (p.urlKey == urlKey) {
        return p.numericId?.toString() ?? p.id;
      }
    }
    return null;
  }

  /// Fetch single product by ID
  /// Maps to: GET_PRODUCT_BY_ID from nextjs-commerce
  Future<ProductModel> getProductById(
    String productId, {
    String? productType,
  }) async {
    final normalizedType = (productType ?? '').toLowerCase().trim();
    if (normalizedType == 'booking') {
      final bookingType = await _resolveBookingTypeById(productId);
      final query = ProductQueries.getBookingProductByIdForType(bookingType);

      final result = await client.query(
        QueryOptions(
          document: gql(query),
          variables: {'id': productId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        throw result.exception!;
      }

      final product = ProductModel.fromJson(
        result.data!['product'] as Map<String, dynamic>,
      );
      _logBookingAvailability(product, source: 'id:$productId');
      return product;
    }

    final query = ProductQueries.getProductById;

    final result = await client.query(
      QueryOptions(
        document: gql(query),
        variables: {'id': productId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    // Storefront `allProducts` returns a paginated list; the id filter yields
    // a single element. Read the first item of `allProducts.data`.
    final allProducts = result.data?['allProducts'] as Map<String, dynamic>?;
    final dataList = allProducts?['data'] as List<dynamic>?;
    if (dataList == null || dataList.isEmpty) {
      throw Exception('Product not found for id: $productId');
    }

    final product = ProductModel.fromJson(
      dataList.first as Map<String, dynamic>,
    );
    _logBookingAvailability(product, source: 'id:$productId');
    return product;
  }

  Future<List<BookingSlotOption>> getBookingSlots({
    required BookingProductData booking,
    required String date,
    String? rentingType,
  }) async {
    final type = (booking.type ?? '').toLowerCase().trim();
    final normalizedRentingType = (rentingType ?? '').toLowerCase().trim();
    final bookingId = _resolveBookingSlotId(booking);

    if (bookingId <= 0) {
      throw Exception('Missing booking slot id for $type product');
    }

    final isRentalHourly =
        type == 'rental' && normalizedRentingType == 'hourly';
    final result = await client.query(
      QueryOptions(
        document: gql(
          isRentalHourly
              ? ProductQueries.getBookingRentalHourlySlots
              : ProductQueries.getBookingSlots,
        ),
        variables: {'id': bookingId, 'date': date},
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final slots = result.data?['bookingSlots'] as List<dynamic>? ?? const [];

    if (isRentalHourly) {
      return slots
          .whereType<Map<String, dynamic>>()
          .expand(BookingSlotOption.fromRentalSummaryJson)
          .where((slot) => slot.label.trim().isNotEmpty)
          .toList();
    }

    return slots
        .whereType<Map<String, dynamic>>()
        .map(BookingSlotOption.fromStandardJson)
        .where((slot) => slot.label.trim().isNotEmpty)
        .toList();
  }

  Future<String> _resolveBookingTypeByUrlKey(String urlKey) async {
    final result = await client.query(
      QueryOptions(
        document: gql(ProductQueries.getBookingProductTypeByUrlKey),
        variables: {'urlKey': urlKey},
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final product = result.data?['product'] as Map<String, dynamic>?;
    final edges = product?['bookingProducts']?['edges'] as List<dynamic>? ?? [];
    if (edges.isEmpty) return 'default';

    final node = edges.first['node'] as Map<String, dynamic>?;
    final bookingType = node?['type']?.toString().trim();
    if (bookingType == null || bookingType.isEmpty) return 'default';
    return bookingType;
  }

  Future<String> _resolveBookingTypeById(String productId) async {
    final result = await client.query(
      QueryOptions(
        document: gql(ProductQueries.getBookingProductTypeById),
        variables: {'id': productId},
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final product = result.data?['product'] as Map<String, dynamic>?;
    final edges = product?['bookingProducts']?['edges'] as List<dynamic>? ?? [];
    if (edges.isEmpty) return 'default';

    final node = edges.first['node'] as Map<String, dynamic>?;
    final bookingType = node?['type']?.toString().trim();
    if (bookingType == null || bookingType.isEmpty) return 'default';
    return bookingType;
  }

  int _resolveBookingSlotId(BookingProductData booking) {
    final type = (booking.type ?? '').toLowerCase().trim();

    switch (type) {
      case 'appointment':
      case 'rental':
      case 'table':
        return booking.activeSlot?.resolvedBookingId ?? 0;
      case 'default':
      default:
        return booking.numericId ?? int.tryParse(booking.id) ?? 0;
    }
  }

  void _logBookingAvailability(ProductModel product, {required String source}) {
    if (!product.isBooking || product.bookingProducts.isEmpty) return;

    for (final booking in product.bookingProducts) {
      debugPrint(
        '[CategoryRepo] booking availability ($source) '
        'type=${booking.type} '
        'availableFrom=${booking.availableFrom} '
        'availableTo=${booking.availableTo}',
      );
    }
  }

  /// Fetch filter attribute options (legacy – single attribute by ID)
  /// Maps to: GET_FILTER_OPTIONS from nextjs-commerce
  /// Attribute IDs: color=/api/admin/attributes/23, size=24, brand=25
  Future<FilterAttribute?> getFilterOptions({
    required String attributeId,
    String locale = 'en',
  }) async {
    final result = await client.query(
      QueryOptions(
        document: gql(FilterQueries.getFilterOptions),
        variables: {'id': attributeId},
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final data = result.data?['attribute'] as Map<String, dynamic>?;
    if (data == null) return null;

    return FilterAttribute.fromJson(data);
  }

  /// Fetch all filterable attributes for a category dynamically.
  ///
  /// Uses the `categoryAttributeFilters` GraphQL query.
  /// [categorySlug] – the category slug (or empty string for all).
  /// Returns a list of [FilterAttribute] with options, price range, etc.
  Future<List<FilterAttribute>> getCategoryAttributeFilters({
    String categorySlug = '',
    int first = 50,
  }) async {
    debugPrint(
      '[CategoryRepo] getCategoryAttributeFilters slug="$categorySlug", first=$first',
    );

    final result = await client.query(
      QueryOptions(
        document: gql(FilterQueries.getCategoryAttributeFilters),
        variables: {'categorySlug': categorySlug, 'first': first},
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    if (result.hasException) {
      debugPrint(
        '[CategoryRepo] getCategoryAttributeFilters error: ${result.exception}',
      );
      throw result.exception!;
    }

    final edges =
        result.data?['categoryAttributeFilters']?['edges'] as List<dynamic>? ??
        [];

    final attributes = edges.map((edge) {
      final node = edge['node'] as Map<String, dynamic>;
      return FilterAttribute.fromCategoryFilterJson(node);
    }).toList();

    // Ensure Price filter attribute always exists
    if (!attributes.any((a) => a.isPriceFilter)) {
      attributes.insert(
        0,
        const FilterAttribute(
          id: 'price',
          code: 'price',
          adminName: 'Price',
          type: 'price',
          translatedName: 'السعر (Price)',
          minPrice: 0,
          maxPrice: 1000,
        ),
      );
    }

    debugPrint(
      '[CategoryRepo] getCategoryAttributeFilters loaded ${attributes.length} attributes: '
      '${attributes.map((a) => "${a.code}(${a.options.length} opts, price=${a.isPriceFilter})").join(", ")}',
    );

    return attributes;
  }

  /// جلب كل بنرات image_carousel (كل الأنواع) من الباك إند.
  /// تُستخدم لاستخراج بنرات نوع "قسم" (category) وفلترتها حسب categoryId
  /// في الواجهة (عبر [BannerImage.categoryBanners]) — لا يوجد فلتر من السيرفر.
  Future<List<BannerImage>> fetchCategoryBanners() async {
    final result = await client.query(
      QueryOptions(
        document: gql(ThemeQueries.getThemeCustomization),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    if (result.hasException) {
      debugPrint('[CategoryRepo] fetchCategoryBanners error: ${result.exception}');
      return <BannerImage>[];
    }

    final list = result.data?['themeCustomization'] as List? ?? [];
    final banners = <BannerImage>[];
    for (final node in list.whereType<Map<String, dynamic>>()) {
      final tc = ThemeCustomization.fromJson(node);
      if (tc.type != 'image_carousel') continue;
      final imagesRaw = tc.options['images'] as List? ?? [];
      banners.addAll(
        imagesRaw.whereType<Map<String, dynamic>>().map(BannerImage.fromJson),
      );
    }
    return banners;
  }

  /// Fetch related products for a given product
  Future<List<ProductModel>> getRelatedProducts(
    String urlKey, {
    int first = 10,
  }) async {
    final result = await client.query(
      QueryOptions(
        document: gql(ProductQueries.getRelatedProducts),
        variables: {'urlKey': urlKey, 'first': first},
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final edges =
        result.data?['product']?['relatedProducts']?['edges']
            as List<dynamic>? ??
        [];
    return edges
        .map((e) => ProductModel.fromJson(e['node'] as Map<String, dynamic>))
        .toList();
  }
}
