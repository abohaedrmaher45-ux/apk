/// Category model matching Bagisto GraphQL schema
/// Derived from: nextjs-commerce/src/graphql/catelog/queries/Category.ts
///               nextjs-commerce/src/graphql/catelog/queries/HomeCategories.ts
class CategoryModel {
  final String id;
  final int? numericId; // _id field from API
  final int? position;
  final String? logoPath;
  final String? logoUrl;
  final String? bannerUrl;
  final String? status;
  final CategoryTranslation? translation;
  final List<CategoryModel> children;

  const CategoryModel({
    required this.id,
    this.numericId,
    this.position,
    this.logoPath,
    this.logoUrl,
    this.bannerUrl,
    this.status,
    this.translation,
    this.children = const [],
  });

  String get name => translation?.name ?? '';
  String get slug => translation?.slug ?? '';
  String get urlPath => translation?.urlPath ?? '';
  String? get imageUrl => logoUrl ?? logoPath;
  bool get isActive => status == '1';

  /// Factory for homeCategories response (real Bagisto schema).
  ///
  /// In the real Bagisto GraphQL API the localized fields (name/slug/urlPath/
  /// description) are FLAT on the category object — there is no `translation`
  /// sub-object — and `children` is a plain list, not an `edges/node`
  /// connection. This factory handles that shape while remaining tolerant of
  /// the older demo shape (translation + edges) for safety.
  factory CategoryModel.fromTreeJson(Map<String, dynamic> json) {
    List<CategoryModel> childrenList = [];
    final childrenData = json['children'];
    if (childrenData is List) {
      // Real Bagisto: plain list of children.
      childrenList = childrenData
          .whereType<Map<String, dynamic>>()
          .map((c) => CategoryModel.fromTreeJson(c))
          .toList();
    } else if (childrenData is Map<String, dynamic>) {
      // Legacy demo: cursor connection { edges: [{ node }] }.
      final edges = childrenData['edges'] as List<dynamic>?;
      if (edges != null) {
        childrenList = edges
            .where((e) => e['node'] != null)
            .map((e) =>
                CategoryModel.fromTreeJson(e['node'] as Map<String, dynamic>))
            .toList();
      }
    }

    return CategoryModel(
      id: json['id']?.toString() ?? '',
      numericId: json['_id'] as int? ?? int.tryParse('${json['id'] ?? ''}'),
      position: json['position'] as int?,
      logoPath: json['logoPath'] as String?,
      logoUrl: json['logoUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      status: json['status']?.toString(),
      translation: _resolveTranslation(json),
      children: childrenList,
    );
  }

  /// Factory for the flat homeCategories list response.
  factory CategoryModel.fromHomeCategoryJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      numericId: json['_id'] as int? ?? int.tryParse('${json['id'] ?? ''}'),
      logoUrl: json['logoUrl'] as String?,
      logoPath: json['logoPath'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      status: json['status']?.toString(),
      position: json['position'] as int?,
      translation: _resolveTranslation(json),
    );
  }

  /// Builds a [CategoryTranslation] from either the flat fields (real Bagisto)
  /// or a nested `translation` object (legacy demo schema).
  static CategoryTranslation? _resolveTranslation(Map<String, dynamic> json) {
    if (json['translation'] is Map<String, dynamic>) {
      return CategoryTranslation.fromJson(
        json['translation'] as Map<String, dynamic>,
      );
    }
    if (json['name'] != null ||
        json['slug'] != null ||
        json['urlPath'] != null) {
      return CategoryTranslation(
        id: json['id']?.toString(),
        name: json['name'] as String?,
        slug: json['slug'] as String?,
        description: json['description'] as String?,
        urlPath: json['urlPath'] as String?,
        metaTitle: json['metaTitle'] as String?,
      );
    }
    return null;
  }
}

class CategoryTranslation {
  final String? id;
  final String? name;
  final String? slug;
  final String? description;
  final String? urlPath;
  final String? metaTitle;

  const CategoryTranslation({
    this.id,
    this.name,
    this.slug,
    this.description,
    this.urlPath,
    this.metaTitle,
  });

  factory CategoryTranslation.fromJson(Map<String, dynamic> json) {
    return CategoryTranslation(
      id: json['id']?.toString(),
      name: json['name'] as String?,
      slug: json['slug'] as String?,
      description: json['description'] as String?,
      urlPath: json['urlPath'] as String?,
      metaTitle: json['metaTitle'] as String?,
    );
  }
}

