import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sentry_ui.dart';
import '../../../../core/dev/preview_data.dart'; // PREVIEW-ONLY
import '../../../../l10n/app_localizations.dart';
import '../../../home/data/models/home_models.dart' show BannerImage;
import '../../../home/presentation/widgets/image_carousel.dart';
import '../../data/models/category_model.dart';
import '../../data/repository/category_repository.dart';
import '../bloc/category_bloc.dart';
import '../widgets/category_chip_row.dart';
import '../widgets/category_banner.dart';
import '../widgets/sub_category_section.dart';
import '../widgets/product_grid_section.dart';
import '../widgets/category_search_bar.dart';
import '../widgets/category_shimmer.dart';
import '../../../search/presentation/pages/search_page.dart';
import 'category_products_grid_page.dart';

/// Category Page – matches Figma "categories-sub"
/// Light: node-id=92-1679 | Dark: node-id=92-1730
///
/// Layout:
///  ┌────────────────────────┐
///  │  Search bar (Women ▼)  │  ← header with category name + search icon
///  ├────────────────────────┤
///  │  ○ Women ○ Men ○ Kids  │  ← horizontal scrollable category chips
///  ├────────────────────────┤
///  │     [ Banner Image ]   │  ← promotional banner
///  ├────────────────────────┤
///  │  Tops          ▼       │  ← sub-category section header
///  │  ○ ○ ○ ○ ○ ○ ○ ○      │  ← sub-category chips (wrap grid)
///  ├────────────────────────┤
///  │  Bottoms        ▼      │
///  │  ○ ○ ○ ○               │
///  ├────────────────────────┤
///  │  Products       ▼      │  ← section header
///  │  ┌──┐ ┌──┐             │
///  │  │  │ │  │             │  ← 2-column product grid
///  │  └──┘ └──┘             │
///  └────────────────────────┘
class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<CategoryBloc, CategoryState>(
      builder: (context, state) {
        if (state.status == CategoryStatus.loading &&
            state.categories.isEmpty) {
          return const CategoryShimmer();
        }

        if (state.status == CategoryStatus.error && state.categories.isEmpty) {
          // PREVIEW-ONLY: show mock catalogue instead of the error screen
          // while the backend is not connected.
          if (kUsePreviewData) {
            return _buildContent(context, _previewCategoryState());
          }
          return _buildError(
            context,
            state.errorMessage ?? l10n.categoryUnknownError,
          );
        }

        return _buildContent(context, state);
      },
    );
  }

  // PREVIEW-ONLY: a fully-populated CategoryState built from mock data.
  CategoryState _previewCategoryState() {
    return CategoryState(
      status: CategoryStatus.loaded,
      categories: PreviewData.categories(),
      selectedCategory: PreviewData.selectedCategory(),
      products: PreviewData.products(),
    );
  }

  Widget _buildContent(BuildContext context, CategoryState state) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: SentryPalette.pageBackground(isDark),
      body: Stack(
        children: [
          const Positioned.fill(child: SentryBackground(variant: 2)),
          SafeArea(
            child: Column(
              children: [
                // ── Search Bar ──
                CategorySearchBar(
                  categoryName:
                      state.selectedCategory?.name ?? l10n.categoryDefaultName,
                  onSearchTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchPage()),
                    );
                  },
                ),

                // ── Scrollable Content ──
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification &&
                          notification.metrics.extentAfter < 200) {
                        context.read<CategoryBloc>().add(LoadMoreProducts());
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),

                          // ── Category Chips (horizontal scroll) ──
                          CategoryChipRow(
                            categories: state.categories,
                            selectedCategory: state.selectedCategory,
                            onCategorySelected: (cat) {
                              context.read<CategoryBloc>().add(
                                SelectCategory(cat),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // ── Banner ──
                          // بنر القسم (يحدده الأدمن، البند 15) يحل محل الصورة
                          // العرضية الافتراضية عند وجوده لنفس القسم المختار.
                          if (state.categoryBanners.isNotEmpty) ...[
                            ImageCarousel(
                              images: state.categoryBanners,
                              onBannerTap: (banner) =>
                                  _onCategoryBannerTap(context, banner),
                            ),
                            const SizedBox(height: 32),
                          ] else if (state.selectedCategory?.bannerUrl !=
                                  null &&
                              state.selectedCategory!.bannerUrl!.isNotEmpty) ...[
                            CategoryBanner(
                              bannerUrl: state.selectedCategory?.bannerUrl,
                              title: state.selectedCategory?.name,
                            ),
                            const SizedBox(height: 32),
                          ],

                          // ── Sub-category Sections ──
                          ..._buildSubCategorySections(
                            context,
                            state.subCategories,
                          ),

                          if (state.subCategories.isNotEmpty)
                            const SizedBox(height: 24),

                          // ── Products Grid ──
                          ProductGridSection(
                            products: state.products,
                            isLoadingMore: state.isLoadingMore,
                            categoryId: state.selectedCategory?.numericId,
                            categoryName: state.selectedCategory?.name,
                            categorySlug: state.selectedCategory?.slug,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// زر بنر القسم: ينقل للقسم نفسه (المحدد فيه هذا البنر من قبل الأدمن).
  void _onCategoryBannerTap(BuildContext context, BannerImage banner) {
    if (banner.categoryId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepositoryProvider.value(
          value: RepositoryProvider.of<CategoryRepository>(context),
          child: CategoryProductsGridPage(
            categoryId: banner.categoryId!,
            categoryName: banner.title ?? '',
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSubCategorySections(
    BuildContext context,
    List<CategoryModel> subCategories,
  ) {
    if (subCategories.isEmpty) return [];

    final l10n = AppLocalizations.of(context)!;

    // Group sub-categories into sections (like "Tops" and "Bottoms" in Figma)
    // If we have grouped children, show them; otherwise show all as one section
    return [
      SubCategorySection(
        title: l10n.categorySubCategories,
        categories: subCategories,
      ),
    ];
  }

  Widget _buildError(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNetwork = message == l10n.commonUnableToReachServer ||
        message == l10n.commonNetworkError ||
        message == l10n.commonTimeoutError;
    final title = isNetwork
        ? (Localizations.localeOf(context).languageCode == 'ar' ? 'أنت غير متصل' : 'You are offline')
        : l10n.categorySomethingWentWrong;

    return Scaffold(
      backgroundColor: SentryPalette.pageBackground(isDark),
      body: Stack(
        children: [
          const Positioned.fill(child: SentryBackground(variant: 2)),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: AppTextStyles.text3(context),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: AppTextStyles.text5(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    context.read<CategoryBloc>().add(LoadCategories());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SentryPalette.violet,
                    foregroundColor: AppColors.white,
                  ),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
