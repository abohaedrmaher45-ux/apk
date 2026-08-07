import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../home/data/models/home_models.dart' show BannerImage;
import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repository/category_repository.dart';

// ─── Events ────────────────────────────────────────────────────────────────

abstract class CategoryEvent extends Equatable {
  const CategoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadCategories extends CategoryEvent {}

class SelectCategory extends CategoryEvent {
  final CategoryModel category;
  const SelectCategory(this.category);

  @override
  List<Object?> get props => [category.id];
}

class LoadSubCategories extends CategoryEvent {
  final int parentId;
  const LoadSubCategories(this.parentId);

  @override
  List<Object?> get props => [parentId];
}

class LoadCategoryProducts extends CategoryEvent {
  final String categorySlug;
  final String? after;

  const LoadCategoryProducts({required this.categorySlug, this.after});

  @override
  List<Object?> get props => [categorySlug, after];
}

class LoadMoreProducts extends CategoryEvent {}

// ─── State ─────────────────────────────────────────────────────────────────

enum CategoryStatus { initial, loading, loaded, error }

class CategoryState extends Equatable {
  final CategoryStatus status;
  final List<CategoryModel> categories;
  final List<CategoryModel> subCategories;
  final CategoryModel? selectedCategory;
  final List<ProductModel> products;
  final PageInfo? pageInfo;
  final int totalProducts;
  final bool isLoadingMore;
  final String? errorMessage;

  /// كل بنرات image_carousel (كل الأنواع) كما وردت من الباك إند — بدون فلترة.
  /// تُفلتَر حسب القسم الحالي عبر [categoryBanners].
  final List<BannerImage> banners;

  const CategoryState({
    this.status = CategoryStatus.initial,
    this.categories = const [],
    this.subCategories = const [],
    this.selectedCategory,
    this.products = const [],
    this.pageInfo,
    this.totalProducts = 0,
    this.isLoadingMore = false,
    this.errorMessage,
    this.banners = const [],
  });

  /// بنرات نوع "قسم" الظاهرة والمطابقة للقسم المختار حالياً.
  List<BannerImage> get categoryBanners {
    final categoryId = selectedCategory?.numericId;
    if (categoryId == null) return const [];
    return BannerImage.categoryBanners(banners, categoryId);
  }

  CategoryState copyWith({
    CategoryStatus? status,
    List<CategoryModel>? categories,
    List<CategoryModel>? subCategories,
    CategoryModel? selectedCategory,
    List<ProductModel>? products,
    PageInfo? pageInfo,
    int? totalProducts,
    bool? isLoadingMore,
    String? errorMessage,
    List<BannerImage>? banners,
  }) {
    return CategoryState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      subCategories: subCategories ?? this.subCategories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      products: products ?? this.products,
      pageInfo: pageInfo ?? this.pageInfo,
      totalProducts: totalProducts ?? this.totalProducts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
      banners: banners ?? this.banners,
    );
  }

  @override
  List<Object?> get props => [
    status,
    categories,
    subCategories,
    selectedCategory,
    products,
    pageInfo,
    totalProducts,
    isLoadingMore,
    errorMessage,
    banners,
  ];
}

// ─── BLoC ──────────────────────────────────────────────────────────────────

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final CategoryRepository repository;

  CategoryBloc({required this.repository}) : super(const CategoryState()) {
    on<LoadCategories>(_onLoadCategories);
    on<SelectCategory>(_onSelectCategory);
    on<LoadSubCategories>(_onLoadSubCategories);
    on<LoadCategoryProducts>(_onLoadCategoryProducts);
    on<LoadMoreProducts>(_onLoadMoreProducts);
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<CategoryState> emit,
  ) async {
    emit(state.copyWith(status: CategoryStatus.loading));

    const maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Fetch tree categories (already includes children) and the
        // category-banner list together. Banners are optional — a failure
        // there must not abort loading the categories/products.
        final results = await Future.wait([
          repository.getTreeCategories(),
          repository.fetchCategoryBanners().catchError((e) {
            debugPrint('[CategoryBloc] fetchCategoryBanners failed (non-fatal): $e');
            return <BannerImage>[];
          }),
        ]);
        final treeCategories = results[0] as List<CategoryModel>;
        final banners = results[1] as List<BannerImage>;

        // Use tree categories as the main list
        final categories = treeCategories;

        CategoryModel? selected;
        List<CategoryModel> subCats = [];
        List<ProductModel> products = [];
        PageInfo? pageInfo;
        int totalProducts = 0;

        if (categories.isNotEmpty) {
          selected = categories.first;

          // Children are already included in tree response
          subCats = selected.children;

          // Load products for first category using its numeric id
          try {
            final catId = selected.numericId;
            if (catId != null) {
              final result = await repository.getFilterProducts(
                filter: '{"category_id":$catId}',
                first: 10,
              );
              products = result.products;
              pageInfo = result.pageInfo;
              totalProducts = result.totalCount;
            }
          } catch (_) {
            // Products may not exist for this category
          }
        }

        emit(
          state.copyWith(
            status: CategoryStatus.loaded,
            categories: categories,
            selectedCategory: selected,
            subCategories: subCats,
            products: products,
            pageInfo: pageInfo,
            totalProducts: totalProducts,
            banners: banners,
          ),
        );
        return; // success — exit retry loop
      } catch (e) {
        if (ErrorMapper.isNetworkError(e) && attempt < maxAttempts) {
          debugPrint(
            '[CategoryBloc] LoadCategories network error (attempt $attempt/$maxAttempts, retrying): $e',
          );
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }
        debugPrint('[CategoryBloc] LoadCategories failed: $e');
        emit(
          state.copyWith(
            status: CategoryStatus.error,
            errorMessage: ErrorMapper.getUserMessage(
              e,
              context: 'loading categories',
            ),
          ),
        );
      }
    }
  }

  Future<void> _onSelectCategory(
    SelectCategory event,
    Emitter<CategoryState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedCategory: event.category,
        subCategories: [],
        products: [],
        isLoadingMore: false,
      ),
    );

    try {
      // Children are already in the tree category model
      final subCats = event.category.children;

      // Load products using numeric id with JSON filter format per API docs
      final catId = event.category.numericId;
      PaginatedProducts? result;
      if (catId != null) {
        result = await repository.getFilterProducts(
          filter: '{"category_id":$catId}',
          first: 10,
        );
      }

      emit(
        state.copyWith(
          subCategories: subCats,
          products: result?.products ?? [],
          pageInfo: result?.pageInfo,
          totalProducts: result?.totalCount ?? 0,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: ErrorMapper.getUserMessage(
            e,
            context: 'loading category products',
          ),
        ),
      );
    }
  }

  Future<void> _onLoadSubCategories(
    LoadSubCategories event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      final subCats = await repository.getTreeCategories(
        parentId: event.parentId,
      );
      emit(state.copyWith(subCategories: subCats));
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: ErrorMapper.getUserMessage(
            e,
            context: 'loading subcategories',
          ),
        ),
      );
    }
  }

  Future<void> _onLoadCategoryProducts(
    LoadCategoryProducts event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      final result = await repository.getFilterProducts(
        filter: '{"category_id":${event.categorySlug}}',
        first: 10,
        after: event.after,
      );

      emit(
        state.copyWith(
          products: result.products,
          pageInfo: result.pageInfo,
          totalProducts: result.totalCount,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: ErrorMapper.getUserMessage(
            e,
            context: 'loading products',
          ),
        ),
      );
    }
  }

  Future<void> _onLoadMoreProducts(
    LoadMoreProducts event,
    Emitter<CategoryState> emit,
  ) async {
    if (state.isLoadingMore ||
        state.pageInfo == null ||
        !state.pageInfo!.hasNextPage) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      final category = state.selectedCategory;
      if (category == null) return;

      final catId = category.numericId;
      if (catId == null) return;

      final result = await repository.getFilterProducts(
        filter: '{"category_id":$catId}',
        first: 10,
        after: state.pageInfo!.endCursor,
      );

      emit(
        state.copyWith(
          products: [...state.products, ...result.products],
          pageInfo: result.pageInfo,
          totalProducts: result.totalCount,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          errorMessage: ErrorMapper.getUserMessage(
            e,
            context: 'loading more products',
          ),
        ),
      );
    }
  }
}
