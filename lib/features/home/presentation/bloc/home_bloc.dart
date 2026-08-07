import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/error_mapper.dart';
import '../../data/models/home_models.dart' hide BannerType;
import '../../data/models/mobile_banner.dart';
import '../../data/repository/home_repository.dart';

// ──────────────────── EVENTS ────────────────────

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

/// Load the full homepage: theme customizations → categories → products.
class LoadHome extends HomeEvent {
  const LoadHome();
}

/// Pull-to-refresh.
class RefreshHome extends HomeEvent {
  const RefreshHome();
}

// ──────────────────── STATE ────────────────────

enum HomeStatus { initial, loading, loaded, refreshing, error }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<ThemeCustomization> customizations;
  final List<HomeCategory> categories;

  /// Keyed by customization `id` → products for that section.
  final Map<String, List<HomeProduct>> productSections;

  /// البنرات المخصصة (نظام البنرات المتقدم) مرتّبة حسب sortOrder.
  final List<MobileBanner> banners;

  final String? errorMessage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.customizations = const [],
    this.categories = const [],
    this.productSections = const {},
    this.banners = const [],
    this.errorMessage,
  });

  /// البنرات مجمّعة حسب النوع، لعرض كل نوع في مكانه.
  Map<BannerType, List<MobileBanner>> get bannersByType {
    final grouped = <BannerType, List<MobileBanner>>{};
    for (final banner in banners) {
      grouped.putIfAbsent(banner.type, () => []).add(banner);
    }
    return grouped;
  }

  HomeState copyWith({
    HomeStatus? status,
    List<ThemeCustomization>? customizations,
    List<HomeCategory>? categories,
    Map<String, List<HomeProduct>>? productSections,
    List<MobileBanner>? banners,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      customizations: customizations ?? this.customizations,
      categories: categories ?? this.categories,
      productSections: productSections ?? this.productSections,
      banners: banners ?? this.banners,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    customizations,
    categories,
    productSections,
    banners,
    errorMessage,
  ];
}

// ──────────────────── BLOC ────────────────────

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeRepository _repository;

  HomeBloc({required HomeRepository repository})
    : _repository = repository,
      super(const HomeState()) {
    on<LoadHome>(_onLoadHome);
    on<RefreshHome>(_onRefreshHome);
  }

  Future<void> _onLoadHome(LoadHome event, Emitter<HomeState> emit) async {
    // Only show full-screen loader when there is no data yet.
    if (state.customizations.isEmpty) {
      emit(state.copyWith(status: HomeStatus.loading));
    }
    await _load(emit);
  }

  Future<void> _onRefreshHome(
    RefreshHome event,
    Emitter<HomeState> emit,
  ) async {
    // Emit refreshing state to indicate refresh is in progress
    emit(state.copyWith(status: HomeStatus.refreshing));
    await _load(emit);
  }

  Future<void> _load(Emitter<HomeState> emit) async {
    const maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _doLoad(emit);
      } catch (e) {
        if (ErrorMapper.isNetworkError(e) && attempt < maxAttempts) {
          debugPrint(
            '[HomeBloc] network error (attempt $attempt/$maxAttempts, retrying): $e',
          );
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }
        // Final failure — show error
        final friendlyMessage = ErrorMapper.getUserMessage(
          e,
          context: 'loading the home page',
        );
        if (state.customizations.isNotEmpty) {
          emit(
            state.copyWith(
              status: HomeStatus.loaded,
              errorMessage: friendlyMessage,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: HomeStatus.error,
              errorMessage: friendlyMessage,
            ),
          );
        }
        return; // Return after emitting state
      }
    }
    // If we exit the loop without returning, emit loaded state with existing data
    if (state.customizations.isNotEmpty) {
      emit(state.copyWith(status: HomeStatus.loaded));
    }
  }

  Future<void> _doLoad(Emitter<HomeState> emit) async {
    // 1) Fetch theme customizations + categories + banners in parallel
    final results = await Future.wait([
      _repository.fetchThemeCustomizations(),
      _repository.fetchHomeCategories(),
      _repository.fetchBanners(),
    ]);

    final customizations = results[0] as List<ThemeCustomization>;
    final categories = results[1] as List<HomeCategory>;
    final banners = results[2] as List<MobileBanner>;

    // 2) Fetch all product_carousel sections in parallel
    final productCarousels = customizations
        .where((tc) => tc.type == 'product_carousel')
        .toList();

    final productResults = await Future.wait(
      productCarousels.map((tc) async {
        try {
          final filters = tc.options['filters'] as Map<String, dynamic>? ?? {};
          final sort = filters['sort'] as String?;
          final limitRaw = filters['limit'];
          final limit = limitRaw != null
              ? int.tryParse(limitRaw.toString()) ?? 8
              : 8;

          // Build filter JSON excluding 'sort' and 'limit'
          final filterMap = <String, String>{};
          for (final entry in filters.entries) {
            if (entry.key == 'sort' || entry.key == 'limit') continue;
            if (entry.value != null) {
              filterMap[entry.key] = entry.value.toString();
            }
          }
          final filterJson = filterMap.isNotEmpty
              ? jsonEncode(filterMap)
              : null;

          String sortKey = 'NEWEST';
          bool reverse = true;
          if (sort == 'created_at-desc') {
            sortKey = 'NEWEST';
            reverse = true;
          } else if (sort == 'price-desc') {
            sortKey = 'PRICE';
            reverse = true;
          } else if (sort == 'price-asc') {
            sortKey = 'PRICE';
            reverse = false;
          } else if (sort == 'name-asc') {
            sortKey = 'TITLE';
            reverse = false;
          } else if (sort == 'name-desc') {
            sortKey = 'TITLE';
            reverse = true;
          }

          return MapEntry(
            tc.id,
            await _repository.fetchProducts(
              first: limit,
              filter: filterJson,
              sortKey: sortKey,
              reverse: reverse,
            ),
          );
        } catch (e) {
          // If one section fails, skip it — don't crash the whole homepage
          return MapEntry(tc.id, <HomeProduct>[]);
        }
      }),
    );

    final Map<String, List<HomeProduct>> productSections = Map.fromEntries(
      productResults,
    );

    // ── Fallback product section ─────────────────────────────────────────
    // The homepage should ALWAYS try to show products, even if the theme
    // customization API returned no `product_carousel` sections, or every
    // section came back empty. This matches the behaviour verified in
    // Postman where `allProducts(input: [...])` returns products directly.
    //
    // Without this, a failing/empty `themeCustomization` response would make
    // the whole home look broken ("network error") even though the product
    // query itself works fine.
    final hasAnyProducts = productSections.values.any((p) => p.isNotEmpty);
    var finalCustomizations = List<ThemeCustomization>.from(customizations);

    if (productCarousels.isEmpty || !hasAnyProducts) {
      final results4 = await Future.wait([
        _repository.fetchProducts(
          first: 8,
          sortKey: 'BEST_SELLING',
          reverse: true,
        ),
        _repository.fetchProducts(first: 8, sortKey: 'NEWEST', reverse: true),
        _repository.fetchProducts(
          first: 8,
          filter: jsonEncode({'featured': '1'}),
        ),
        _repository.fetchProducts(first: 8, sortKey: 'TITLE', reverse: false),
      ]);

      var bestSellers = results4[0];
      var newProducts = results4[1];
      var specialOffers = results4[2];
      var suggestedProducts = results4[3];

      if (specialOffers.isEmpty && newProducts.isNotEmpty) {
        specialOffers = newProducts
            .where((p) => p.specialPrice != null && p.specialPrice! > 0)
            .toList();
        if (specialOffers.isEmpty) {
          specialOffers = await _repository.fetchProducts(
            first: 8,
            sortKey: 'PRICE',
            reverse: false,
          );
        }
      }
      if (suggestedProducts.isEmpty && bestSellers.isNotEmpty) {
        suggestedProducts = bestSellers.reversed.toList();
      }

      if (bestSellers.isNotEmpty) {
        const id = '__best_sellers__';
        productSections[id] = bestSellers;
        finalCustomizations.add(
          const ThemeCustomization(
            id: id,
            type: 'product_carousel',
            name: '__best_sellers__',
            status: true,
            sortOrder: 1001,
            options: <String, dynamic>{},
          ),
        );
      }

      if (newProducts.isNotEmpty) {
        const id = '__new_products__';
        productSections[id] = newProducts;
        finalCustomizations.add(
          const ThemeCustomization(
            id: id,
            type: 'product_carousel',
            name: '__new_products__',
            status: true,
            sortOrder: 1002,
            options: <String, dynamic>{},
          ),
        );
      }

      if (specialOffers.isNotEmpty) {
        const id = '__special_offers__';
        productSections[id] = specialOffers;
        finalCustomizations.add(
          const ThemeCustomization(
            id: id,
            type: 'product_carousel',
            name: '__special_offers__',
            status: true,
            sortOrder: 1003,
            options: <String, dynamic>{},
          ),
        );
      }

      if (suggestedProducts.isNotEmpty) {
        const id = '__suggested_products__';
        productSections[id] = suggestedProducts;
        finalCustomizations.add(
          const ThemeCustomization(
            id: id,
            type: 'product_carousel',
            name: '__suggested_products__',
            status: true,
            sortOrder: 1004,
            options: <String, dynamic>{},
          ),
        );
      }
    }

    emit(
      state.copyWith(
        status: HomeStatus.loaded,
        customizations: finalCustomizations,
        categories: categories,
        productSections: productSections,
        banners: banners,
        errorMessage: null,
      ),
    );
  }
}
