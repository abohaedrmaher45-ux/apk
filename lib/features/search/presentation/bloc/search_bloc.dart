import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../category/data/models/product_model.dart';
import '../../../category/data/models/category_model.dart';
import '../../../category/data/repository/category_repository.dart';

// ─── Events ────────────────────────────────────────────────────────────────

abstract class SearchEvent extends Equatable {
  const SearchEvent();
  @override
  List<Object?> get props => [];
}

/// Initialize search page (load recent searches + top categories)
class InitSearch extends SearchEvent {}

/// User typed a search query
class SearchQueryChanged extends SearchEvent {
  final String query;
  const SearchQueryChanged(this.query);
  @override
  List<Object?> get props => [query];
}

/// User submitted search
class SubmitSearch extends SearchEvent {
  final String query;
  const SubmitSearch(this.query);
  @override
  List<Object?> get props => [query];
}

/// Clear search results (go back to initial state)
class ClearSearch extends SearchEvent {}

/// Remove a recent search
class RemoveRecentSearch extends SearchEvent {
  final String query;
  const RemoveRecentSearch(this.query);
  @override
  List<Object?> get props => [query];
}

/// Clear all recent searches
class ClearAllRecentSearches extends SearchEvent {}

// ─── State ─────────────────────────────────────────────────────────────────

enum SearchStatus { initial, searching, results, empty, error }

class SearchState extends Equatable {
  final SearchStatus status;
  final String query;
  final List<ProductModel> searchResults;
  final List<String> recentSearches;
  final List<CategoryModel> topCategories;
  final String? errorMessage;
  final bool hasMore;
  final int totalCount;

  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.searchResults = const [],
    this.recentSearches = const [],
    this.topCategories = const [],
    this.errorMessage,
    this.hasMore = false,
    this.totalCount = 0,
  });

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<ProductModel>? searchResults,
    List<String>? recentSearches,
    List<CategoryModel>? topCategories,
    String? errorMessage,
    bool? hasMore,
    int? totalCount,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      searchResults: searchResults ?? this.searchResults,
      recentSearches: recentSearches ?? this.recentSearches,
      topCategories: topCategories ?? this.topCategories,
      errorMessage: errorMessage ?? this.errorMessage,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    query,
    searchResults,
    recentSearches,
    topCategories,
    errorMessage,
    hasMore,
    totalCount,
  ];
}

// ─── BLoC ──────────────────────────────────────────────────────────────────

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final CategoryRepository repository;
  static const String _recentSearchesKey = 'app_recent_searches';
  static const int _maxRecentSearches = 10;

  SearchBloc({required this.repository}) : super(const SearchState()) {
    on<InitSearch>(_onInitSearch);
    on<SearchQueryChanged>(_onSearchQueryChanged);
    on<SubmitSearch>(_onSubmitSearch);
    on<ClearSearch>(_onClearSearch);
    on<RemoveRecentSearch>(_onRemoveRecentSearch);
    on<ClearAllRecentSearches>(_onClearAllRecentSearches);
  }

  Future<List<String>> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentSearchesKey) ?? [];
  }

  Future<void> _saveRecentSearches(List<String> searches) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, searches);
  }

  Future<void> _addToRecentSearches(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final recent = await _loadRecentSearches();
    recent.remove(trimmed); // remove duplicate
    recent.insert(0, trimmed); // add to front
    if (recent.length > _maxRecentSearches) {
      recent.removeRange(_maxRecentSearches, recent.length);
    }
    await _saveRecentSearches(recent);
  }

  Future<void> _onInitSearch(
    InitSearch event,
    Emitter<SearchState> emit,
  ) async {
    // Load recent searches
    final recentSearches = await _loadRecentSearches();

    // Load top categories
    List<CategoryModel> categories = [];
    try {
      categories = await repository.getHomeCategories();
      // Take first 5 categories
      if (categories.length > 5) {
        categories = categories.sublist(0, 5);
      }
    } catch (_) {
      // Silently ignore category fetch errors
    }

    emit(
      state.copyWith(
        status: SearchStatus.initial,
        recentSearches: recentSearches,
        topCategories: categories,
      ),
    );
  }

  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();

    if (query.isEmpty) {
      emit(
        state.copyWith(
          status: SearchStatus.initial,
          query: '',
          searchResults: [],
        ),
      );
      return;
    }

    emit(state.copyWith(status: SearchStatus.searching, query: query));

    try {
      if (query.startsWith('price:')) {
        final parts = query.replaceFirst('price:', '').split('-');
        final minVal = double.tryParse(parts[0]) ?? 0.0;
        final maxVal = parts.length > 1 ? (double.tryParse(parts[1]) ?? 999999.0) : 999999.0;

        List<ProductModel> priceProducts = [];

        try {
          final allResult = await repository.getFilterProducts(filter: '{}', first: 100);
          priceProducts = allResult.products
              .where((p) => p.displayPrice >= minVal && p.displayPrice <= maxVal)
              .toList();
        } catch (e) {
          debugPrint('[SearchBloc] Price search error: $e');
        }

        emit(
          state.copyWith(
            status: priceProducts.isEmpty ? SearchStatus.empty : SearchStatus.results,
            searchResults: priceProducts,
            totalCount: priceProducts.length,
            hasMore: false,
          ),
        );
        return;
      }

      final cleanQuery = query.replaceAll(RegExp(r'[^0-9.]'), '');
      final numericPrice = double.tryParse(cleanQuery);

      if (numericPrice != null && numericPrice > 0 && cleanQuery == query.trim()) {
        try {
          final priceResult = await repository.getFilterProducts(
            filter: jsonEncode({'price': '0,${numericPrice.toInt()}'}),
            first: 30,
          );
          var priceProducts = priceResult.products
              .where((p) => p.displayPrice <= numericPrice)
              .toList();

          if (priceProducts.isNotEmpty) {
            emit(
              state.copyWith(
                status: SearchStatus.results,
                searchResults: priceProducts,
                totalCount: priceProducts.length,
                hasMore: false,
              ),
            );
            return;
          }
        } catch (_) {}
      }

      final result = await repository.getProducts(query: query, first: 20);

      if (result.products.isEmpty) {
        // 1. Try Brand Attribute Match (e.g. Nike / نايكي / Adidas / أديداس)
        try {
          final allProds = await repository.getFilterProducts(filter: '{}', first: 100);
          final q = query.toLowerCase().trim();

          final brandMatching = allProds.products.where((p) {
            final b = (p.brand ?? '').toLowerCase().trim();
            final sku = (p.sku ?? '').toLowerCase().trim();

            if (b.isNotEmpty && (b.contains(q) || q.contains(b))) return true;

            if ((q.contains('nike') || q.contains('نايك')) &&
                (b.contains('nike') || b.contains('نايك') || b == '1' || sku.contains('nike'))) {
              return true;
            }

            if ((q.contains('adidas') || q.contains('أديداس') || q.contains('اديداس')) &&
                (b.contains('adidas') || b.contains('أديداس') || b.contains('اديداس') || b == '2' || sku.contains('adidas'))) {
              return true;
            }

            return false;
          }).toList();

          if (brandMatching.isNotEmpty) {
            emit(
              state.copyWith(
                status: SearchStatus.results,
                searchResults: brandMatching,
                totalCount: brandMatching.length,
                hasMore: false,
              ),
            );
            return;
          }
        } catch (e) {
          debugPrint('[SearchBloc] Brand search error: $e');
        }

        // 2. Try Category Match
        try {
          final categories = await repository.getHomeCategories();
          final matchingCategory = categories.cast<CategoryModel?>().firstWhere(
            (c) =>
                c != null &&
                (c.name.toLowerCase().contains(query.toLowerCase()) ||
                    query.toLowerCase().contains(c.name.toLowerCase())),
            orElse: () => null,
          );

          if (matchingCategory != null) {
            final catResult = await repository.getFilterProducts(
              filter: jsonEncode({'category_id': matchingCategory.id}),
              first: 20,
            );
            if (catResult.products.isNotEmpty) {
              emit(
                state.copyWith(
                  status: SearchStatus.results,
                  searchResults: catResult.products,
                  totalCount: catResult.totalCount,
                  hasMore: catResult.pageInfo.hasNextPage,
                ),
              );
              return;
            }
          }
        } catch (_) {}

        emit(
          state.copyWith(
            status: SearchStatus.empty,
            searchResults: [],
            totalCount: 0,
            hasMore: false,
          ),
        );
      } else {
        var finalProducts = result.products;
        if (numericPrice != null && numericPrice > 0) {
          finalProducts = finalProducts
              .where((p) => p.displayPrice <= numericPrice)
              .toList();
        }
        emit(
          state.copyWith(
            status: SearchStatus.results,
            searchResults: finalProducts,
            totalCount: finalProducts.length,
            hasMore: result.pageInfo.hasNextPage,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: SearchStatus.error,
          errorMessage: ErrorMapper.getUserMessage(
            e,
            context: 'searching for products',
          ),
        ),
      );
    }
  }

  Future<void> _onSubmitSearch(
    SubmitSearch event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) return;

    if (!query.startsWith('price:')) {
      await _addToRecentSearches(query);
    }

    final recentSearches = await _loadRecentSearches();

    emit(
      state.copyWith(
        status: SearchStatus.searching,
        query: query,
        recentSearches: recentSearches,
      ),
    );

    try {
      if (query.startsWith('price:')) {
        final parts = query.replaceFirst('price:', '').split('-');
        final minVal = double.tryParse(parts[0]) ?? 0.0;
        final maxVal = parts.length > 1 ? (double.tryParse(parts[1]) ?? 999999.0) : 999999.0;

        List<ProductModel> priceProducts = [];

        try {
          final allResult = await repository.getFilterProducts(filter: '{}', first: 100);
          priceProducts = allResult.products
              .where((p) => p.displayPrice >= minVal && p.displayPrice <= maxVal)
              .toList();
        } catch (e) {
          debugPrint('[SearchBloc] Price search error: $e');
        }

        emit(
          state.copyWith(
            status: priceProducts.isEmpty ? SearchStatus.empty : SearchStatus.results,
            searchResults: priceProducts,
            totalCount: priceProducts.length,
            hasMore: false,
          ),
        );
        return;
      }

      final cleanQuery = query.replaceAll(RegExp(r'[^0-9.]'), '');
      final numericPrice = double.tryParse(cleanQuery);

      if (numericPrice != null && numericPrice > 0 && cleanQuery == query.trim()) {
        try {
          final priceResult = await repository.getFilterProducts(
            filter: jsonEncode({'price': '0,${numericPrice.toInt()}'}),
            first: 30,
          );
          var priceProducts = priceResult.products
              .where((p) => p.displayPrice <= numericPrice)
              .toList();

          if (priceProducts.isNotEmpty) {
            emit(
              state.copyWith(
                status: SearchStatus.results,
                searchResults: priceProducts,
                totalCount: priceProducts.length,
                hasMore: false,
              ),
            );
            return;
          }
        } catch (_) {}
      }

      final result = await repository.getProducts(query: query, first: 20);

      if (result.products.isEmpty) {
        // 1. Try Brand Attribute Match (e.g. Nike / نايكي / Adidas / أديداس)
        try {
          final allProds = await repository.getFilterProducts(filter: '{}', first: 100);
          final q = query.toLowerCase().trim();

          final brandMatching = allProds.products.where((p) {
            final b = (p.brand ?? '').toLowerCase().trim();
            final sku = (p.sku ?? '').toLowerCase().trim();

            if (b.isNotEmpty && (b.contains(q) || q.contains(b))) return true;

            if ((q.contains('nike') || q.contains('نايك')) &&
                (b.contains('nike') || b.contains('نايك') || b == '1' || sku.contains('nike'))) {
              return true;
            }

            if ((q.contains('adidas') || q.contains('أديداس') || q.contains('اديداس')) &&
                (b.contains('adidas') || b.contains('أديداس') || b.contains('اديداس') || b == '2' || sku.contains('adidas'))) {
              return true;
            }

            return false;
          }).toList();

          if (brandMatching.isNotEmpty) {
            emit(
              state.copyWith(
                status: SearchStatus.results,
                searchResults: brandMatching,
                totalCount: brandMatching.length,
                hasMore: false,
              ),
            );
            return;
          }
        } catch (e) {
          debugPrint('[SearchBloc] Brand search error: $e');
        }
        try {
          final categories = await repository.getHomeCategories();
          final matchingCategory = categories.cast<CategoryModel?>().firstWhere(
            (c) =>
                c != null &&
                (c.name.toLowerCase().contains(query.toLowerCase()) ||
                    query.toLowerCase().contains(c.name.toLowerCase())),
            orElse: () => null,
          );

          if (matchingCategory != null) {
            final catResult = await repository.getFilterProducts(
              filter: jsonEncode({'category_id': matchingCategory.id}),
              first: 20,
            );
            if (catResult.products.isNotEmpty) {
              emit(
                state.copyWith(
                  status: SearchStatus.results,
                  searchResults: catResult.products,
                  totalCount: catResult.totalCount,
                  hasMore: catResult.pageInfo.hasNextPage,
                ),
              );
              return;
            }
          }
        } catch (_) {}

        emit(
          state.copyWith(
            status: SearchStatus.empty,
            searchResults: [],
            totalCount: 0,
            hasMore: false,
          ),
        );
      } else {
        var finalProducts = result.products;
        if (numericPrice != null && numericPrice > 0) {
          finalProducts = finalProducts
              .where((p) => p.displayPrice <= numericPrice)
              .toList();
        }
        emit(
          state.copyWith(
            status: SearchStatus.results,
            searchResults: finalProducts,
            totalCount: finalProducts.length,
            hasMore: result.pageInfo.hasNextPage,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: SearchStatus.error,
          errorMessage: ErrorMapper.getUserMessage(
            e,
            context: 'searching for products',
          ),
        ),
      );
    }
  }

  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    emit(
      state.copyWith(
        status: SearchStatus.initial,
        query: '',
        searchResults: [],
      ),
    );
  }

  Future<void> _onRemoveRecentSearch(
    RemoveRecentSearch event,
    Emitter<SearchState> emit,
  ) async {
    final recent = List<String>.from(state.recentSearches)..remove(event.query);
    await _saveRecentSearches(recent);
    emit(state.copyWith(recentSearches: recent));
  }

  Future<void> _onClearAllRecentSearches(
    ClearAllRecentSearches event,
    Emitter<SearchState> emit,
  ) async {
    await _saveRecentSearches([]);
    emit(state.copyWith(recentSearches: []));
  }
}
