import 'dart:convert';
import 'dart:developer' as developer;
import 'package:equatable/equatable.dart';

import '../../../../core/currency/currency_formatter.dart';

/// Represents a theme customization entry from the Bagisto API.
/// Each node defines a section of the homepage (image_carousel, product_carousel,
/// category_carousel, etc.) along with its translated options JSON.
class ThemeCustomization extends Equatable {
  final String id;
  final String type;
  final String name;
  final bool status;
  final int sortOrder;
  final Map<String, dynamic> options;

  const ThemeCustomization({
    required this.id,
    required this.type,
    required this.name,
    required this.status,
    required this.sortOrder,
    required this.options,
  });

  factory ThemeCustomization.fromJson(
    Map<String, dynamic> json, {
    String preferredLocale = 'en',
  }) {
    // Parse translations → find the preferred locale, fallback to 'en', then first available
    Map<String, dynamic> options = {};
    Map<String, dynamic>? enOptions;

    // Real Bagisto returns `translations` as a plain list with `localeCode`
    // and a structured `options` object. Older demo schema used
    // `translations.edges[].node` with `locale` and a JSON-string `options`.
    final rawTranslations = json['translations'];
    final List translations;
    if (rawTranslations is List) {
      translations = rawTranslations;
    } else if (rawTranslations is Map && rawTranslations['edges'] is List) {
      translations = (rawTranslations['edges'] as List)
          .map((e) => (e as Map)['node'])
          .toList();
    } else {
      translations = const [];
    }

    for (final entry in translations) {
      final node = (entry as Map).cast<String, dynamic>();
      final locale = (node['localeCode'] ?? node['locale']) as String? ?? '';

      Map<String, dynamic>? parsed;
      final rawOptions = node['options'];
      if (rawOptions is String) {
        try {
          parsed = jsonDecode(rawOptions) as Map<String, dynamic>;
        } catch (_) {}
      } else if (rawOptions is Map) {
        parsed = Map<String, dynamic>.from(rawOptions);
      }
      if (parsed == null || parsed.isEmpty) continue;

      if (locale == preferredLocale) {
        options = parsed;
        break; // exact match found
      } else if (locale == 'en') {
        enOptions = parsed; // keep English as fallback
      } else if (options.isEmpty) {
        options = parsed; // first available as last resort
      }
    }
    // Use English fallback if preferred locale wasn't found
    if (options.isEmpty && enOptions != null) {
      options = enOptions;
    }

    return ThemeCustomization(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status:
          json['status'] == true ||
          json['status'] == 'true' ||
          json['status'] == 1 ||
          json['status'] == '1',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      options: options,
    );
  }

  @override
  List<Object?> get props => [id, type, name, status, sortOrder];
}

/// A category for the homepage carousel (circular icons).
class HomeCategory extends Equatable {
  final String id;
  final int? numericId;
  final String name;
  final String slug;
  final String? logoUrl;
  final int position;

  const HomeCategory({
    required this.id,
    this.numericId,
    required this.name,
    required this.slug,
    this.logoUrl,
    required this.position,
  });

  factory HomeCategory.fromJson(Map<String, dynamic> json) {
    // Real Bagisto homeCategories returns flat fields; the older demo schema
    // nested them under `translation`. Support both.
    final translation =
        json['translation'] as Map<String, dynamic>? ?? const {};
    final numericId =
        json['_id'] as int? ??
        int.tryParse('${json['id'] ?? ''}'.split('/').last);
    return HomeCategory(
      id: json['id']?.toString() ?? '',
      numericId: numericId,
      name: (json['name'] ?? translation['name']) as String? ?? '',
      slug: (json['slug'] ?? translation['slug']) as String? ?? '',
      logoUrl: (json['logoUrl'] ?? json['logoPath']) as String?,
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, numericId, name, slug, logoUrl, position];
}

/// A product for homepage product carousels.
class HomeProduct extends Equatable {
  final String id;
  final int? numericId;
  final String sku;
  final String type;
  final String name;
  final String urlKey;
  final String? baseImageUrl;
  final double price;
  final double? minimumPrice;
  final double? specialPrice;
  final String? formattedPrice;
  final String? formattedMinimumPrice;
  final String? formattedSpecialPrice;

  /// ISO code of the currency these prices are expressed in (e.g. "EUR"),
  /// taken from `priceHtml.currencyCode`.
  ///
  /// Needed by "Recently viewed": those products are restored from disk, where
  /// the backend-formatted strings are NOT kept (they would freeze a stale
  /// currency symbol). Formatting then falls back to the raw number, and
  /// without a code `CurrencyFormatter` would default to USD and print "$".
  final String? currencyCode;

  final bool isSaleable;
  final double averageRating;
  final int reviewCount;

  const HomeProduct({
    required this.id,
    this.numericId,
    required this.sku,
    required this.type,
    required this.name,
    required this.urlKey,
    this.baseImageUrl,
    required this.price,
    this.minimumPrice,
    this.specialPrice,
    this.formattedPrice,
    this.formattedMinimumPrice,
    this.formattedSpecialPrice,
    this.currencyCode,
    required this.isSaleable,
    this.averageRating = 0,
    this.reviewCount = 0,
  });

  factory HomeProduct.fromJson(Map<String, dynamic> json) {
    // Parse numeric ID from _id field or from IRI
    int? numId;
    if (json['_id'] is int) {
      numId = json['_id'] as int;
    } else if (json['_id'] != null) {
      numId = int.tryParse(json['_id'].toString());
    }
    if (numId == null && json['id'] != null) {
      final parts = json['id'].toString().split('/');
      if (parts.isNotEmpty) numId = int.tryParse(parts.last);
    }

    // Debug: log raw price fields from API
    developer.log(
      'HomeProduct[${json['name']}] price=${json['price']} '
      'specialPrice=${json['specialPrice']} (${json['specialPrice']?.runtimeType}) '
      'minimumPrice=${json['minimumPrice']}',
      name: 'HomeProduct',
    );

    // Parse specialPrice — treat 0 as null (no discount)
    double? parsedSpecialPrice;
    if (json['specialPrice'] != null) {
      final sp = _toDouble(json['specialPrice']);
      if (sp > 0) parsedSpecialPrice = sp;
    }

    // Parse reviews for rating/count (real Bagisto: plain list; demo: edges)
    final rawReviews = json['reviews'];
    final List reviewList;
    if (rawReviews is List) {
      reviewList = rawReviews;
    } else if (rawReviews is Map && rawReviews['edges'] is List) {
      reviewList = (rawReviews['edges'] as List)
          .map((e) => (e as Map)['node'])
          .toList();
    } else {
      reviewList = const [];
    }
    final ratings = reviewList
        .map((e) => _toDouble((e as Map?)?['rating']))
        .where((r) => r > 0)
        .toList();
    final fallbackRating = _toDouble(json['averageRating']);
    final avgRating = ratings.isNotEmpty
        ? ratings.reduce((a, b) => a + b) / ratings.length
        : fallbackRating;
    final fallbackReviewCount = (json['reviewCount'] as num?)?.toInt() ?? 0;

    // Derive fields not present on the real Product type.
    String? baseImage = json['baseImageUrl'] as String?;
    final imgs = json['images'];
    if ((baseImage == null || baseImage.isEmpty) &&
        imgs is List &&
        imgs.isNotEmpty) {
      final first = imgs.first;
      if (first is Map) baseImage = (first['url'] ?? first['path'])?.toString();
    }
    final priceHtml = json['priceHtml'] is Map
        ? (json['priceHtml'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final formattedPrice =
        (json['formattedPrice'] as String?) ??
        priceHtml['formattedRegularPrice'] as String? ??
        priceHtml['formattedFinalPrice'] as String?;
    final formattedSpecial =
        (json['formattedSpecialPrice'] as String?) ??
        priceHtml['formattedFinalPrice'] as String?;

    return HomeProduct(
      id: json['id']?.toString() ?? '',
      numericId: numId,
      sku: json['sku'] as String? ?? '',
      type: json['type'] as String? ?? 'simple',
      name: json['name'] as String? ?? '',
      urlKey: json['urlKey'] as String? ?? '',
      baseImageUrl: baseImage,
      price: _toDouble(json['price']),
      minimumPrice: json['minimumPrice'] != null
          ? _toDouble(json['minimumPrice'])
          : null,
      specialPrice: parsedSpecialPrice,
      formattedPrice: formattedPrice,
      formattedMinimumPrice: json['formattedMinimumPrice'] as String?,
      formattedSpecialPrice: formattedSpecial,
      currencyCode:
          (json['currencyCode'] as String?) ??
          priceHtml['currencyCode'] as String?,
      isSaleable: json['isSaleable'] == true,
      averageRating: avgRating,
      reviewCount: ratings.isNotEmpty ? ratings.length : fallbackReviewCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      '_id': numericId,
      'sku': sku,
      'type': type,
      'name': name,
      'urlKey': urlKey,
      'baseImageUrl': baseImageUrl,
      'price': price,
      'minimumPrice': minimumPrice,
      'specialPrice': specialPrice,
      'formattedPrice': formattedPrice,
      'formattedMinimumPrice': formattedMinimumPrice,
      'formattedSpecialPrice': formattedSpecialPrice,
      'currencyCode': currencyCode,
      'isSaleable': isSaleable,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
    };
  }

  /// The effective display price: specialPrice > minimumPrice > price
  double get displayPrice {
    if (specialPrice != null && specialPrice! > 0) return specialPrice!;
    if (type == 'configurable' && minimumPrice != null && minimumPrice! > 0) {
      return minimumPrice!;
    }
    return price;
  }

  /// Whether a discount exists.
  bool get hasDiscount =>
      specialPrice != null && specialPrice! > 0 && specialPrice! < price;

  /// Discount percentage (0–100).
  int get discountPercent {
    if (!hasDiscount) return 0;
    return (((price - specialPrice!) / price) * 100).round();
  }

  String get displayPriceLabel {
    String label;
    if (specialPrice != null &&
        specialPrice! > 0 &&
        (formattedSpecialPrice?.isNotEmpty ?? false)) {
      label = formattedSpecialPrice!;
    } else if (type == 'configurable' &&
        minimumPrice != null &&
        minimumPrice! > 0 &&
        (formattedMinimumPrice?.isNotEmpty ?? false)) {
      label = formattedMinimumPrice!;
    } else if (formattedPrice != null && formattedPrice!.isNotEmpty) {
      // Backend-formatted price (already carries the € symbol).
      label = formattedPrice!;
    } else {
      // Fallback: format the raw number using THIS PRODUCT's currency code.
      //
      // Passing `currencyCode` explicitly matters: without it the formatter
      // falls back to the globally-selected code, which is still null on a cold
      // start (the channel bootstrap runs AFTER runApp), and it then defaults
      // to USD — which is why "Recently viewed" showed "$" while the rest of
      // the home screen, using backend-formatted strings, correctly showed "€".
      label = CurrencyFormatter.formatAmount(
        displayPrice,
        currencyCode: currencyCode,
      );
    }
    // Force Latin numerals regardless of the backend locale.
    return CurrencyFormatter.normalizeDigits(label);
  }

  String? get originalPriceLabel {
    if (hasDiscount && (formattedPrice?.isNotEmpty ?? false)) {
      return CurrencyFormatter.normalizeDigits(formattedPrice);
    }
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    numericId,
    sku,
    type,
    name,
    urlKey,
    baseImageUrl,
    price,
    formattedPrice,
    formattedMinimumPrice,
    formattedSpecialPrice,
    averageRating,
    reviewCount,
  ];
}

/// نوع البنر (البند 15): رئيسي/عروض/موسمي/قسم.
enum BannerType {
  main,
  offers,
  seasonal,
  category;

  static BannerType fromString(String? value) {
    switch (value) {
      case 'offers':
        return BannerType.offers;
      case 'seasonal':
        return BannerType.seasonal;
      case 'category':
        return BannerType.category;
      case 'main':
      default:
        return BannerType.main;
    }
  }
}

/// An image entry inside an image_carousel customization.
/// موسّع ليحمل حقول البنرات المتقدمة (البند 15).
class BannerImage extends Equatable {
  final String imageUrl;
  final String link;
  final String? title;

  // حقول البنرات المتقدمة
  final BannerType bannerType;
  final String? subtitle;
  final String? buttonText;
  final int sortOrder;
  final bool status;
  final DateTime? startDate;
  final DateTime? endDate;

  /// معرّف القسم (فقط لبنرات النوع category — البقية null).
  final int? categoryId;

  const BannerImage({
    required this.imageUrl,
    this.link = '',
    this.title,
    this.bannerType = BannerType.main,
    this.subtitle,
    this.buttonText,
    this.sortOrder = 0,
    this.status = true,
    this.startDate,
    this.endDate,
    this.categoryId,
  });

  factory BannerImage.fromJson(Map<String, dynamic> json) {
    // imageUrl = الرابط الكامل من الخادم (يحوي /storage/)
    // image    = المسار النسبي (theme/10/xxx.png) — نبنيه يدوياً إن غاب imageUrl
    final imageUrl = json['imageUrl'] as String?;
    final imagePath = json['image'] as String?;

    return BannerImage(
      imageUrl: imageUrl?.isNotEmpty == true ? imageUrl! : imagePath ?? '',
      link: json['link'] as String? ?? '',
      title: json['title'] as String?,
      bannerType: BannerType.fromString(json['banner_type'] as String?),
      subtitle: json['subtitle'] as String?,
      buttonText: json['button_text'] as String?,
      sortOrder: _toInt(json['sort_order']),
      status: _toBool(json['status']),
      startDate: _toDate(json['start_date']),
      endDate: _toDate(json['end_date']),
      categoryId: _toNullableInt(json['category_id']),
    );
  }

  /// بنرات نوع "قسم" (category) الظاهرة والمطابقة لقسم معيّن، مرتّبة حسب sortOrder.
  /// الفلترة بالكامل من جهة العميل (الباك إند يرجع كل الأنواع في مصفوفة واحدة).
  static List<BannerImage> categoryBanners(
    List<BannerImage> allBanners,
    int categoryId,
  ) {
    return allBanners
        .where(
          (b) =>
              b.bannerType == BannerType.category &&
              b.categoryId == categoryId &&
              b.isVisible,
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// هل البنر ضمن نافذته الزمنية الآن؟ (تواريخ فارغة = بلا قيد)
  bool get isWithinSchedule {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  /// هل يجب عرض هذا البنر؟ (ظاهر + ضمن الجدولة + له صورة)
  bool get isVisible => status && isWithinSchedule && imageUrl.isNotEmpty;

  /// Build full URL for displaying the image.
  /// - If imageUrl is already absolute (http/https) → return as-is.
  /// - If imageUrl is a relative path (e.g. "theme/10/xxx.png") →
  ///   prepend baseUrl + "/storage/" to build a complete URL.
  String fullImageUrl(String baseUrl) {
    if (imageUrl.isEmpty) return '';

    var url = imageUrl;

    // رابط كامل من الخادم
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // إصلاح رابط ناقص /storage: مثلاً .../theme/10/x.png → .../storage/theme/10/x.png
      if (url.contains('/theme/') && !url.contains('/storage/')) {
        url = url.replaceFirst('/theme/', '/storage/theme/');
      }
      return url;
    }

    // مسار نسبي — نبني الرابط بإضافة /storage/
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = url.startsWith('/') ? url.substring(1) : url;

    return '$cleanBase/storage/$cleanPath';
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static int? _toNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static bool _toBool(dynamic v) {
    if (v == null) return true; // الافتراضي: ظاهر
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return true;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s.startsWith('0000')) return null;
    return DateTime.tryParse(s);
  }

  @override
  List<Object?> get props => [
    imageUrl,
    link,
    title,
    bannerType,
    subtitle,
    buttonText,
    sortOrder,
    status,
    startDate,
    endDate,
    categoryId,
  ];
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
