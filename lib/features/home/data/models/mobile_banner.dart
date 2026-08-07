import 'package:equatable/equatable.dart';

/// استعلام البنرات المخصصة من الباك إند (GraphQL).
///
/// يطابق النوع `MobileBanner` والـ query `mobileBanners` المعرّفين في
/// graphql/custom_extensions.graphql على الخادم.
class BannerQueries {
  BannerQueries._();

  /// جلب كل البنرات الظاهرة (مفعّلة + ضمن جدولتها الزمنية)، مرتّبة.
  static const String getMobileBanners = r'''
    query mobileBanners {
      mobileBanners {
        id
        title
        subtitle
        description
        imageUrl
        mobileImageUrl
        link
        buttonText
        type
        position
        sortOrder
        startDate
        endDate
      }
    }
  ''';

  /// جلب بنرات نوع واحد فقط (main | offers | seasonal | category).
  static const String getMobileBannersByType = r'''
    query mobileBanners($type: String) {
      mobileBanners(type: $type) {
        id
        title
        subtitle
        description
        imageUrl
        mobileImageUrl
        link
        buttonText
        type
        position
        sortOrder
        startDate
        endDate
      }
    }
  ''';
}

/// أنواع البنرات (تطابق enum الـ type في قاعدة البيانات).
enum BannerType {
  main,
  offers,
  seasonal,
  category,
  unknown;

  static BannerType fromString(String? value) {
    switch (value) {
      case 'main':
        return BannerType.main;
      case 'offers':
        return BannerType.offers;
      case 'seasonal':
        return BannerType.seasonal;
      case 'category':
        return BannerType.category;
      default:
        return BannerType.unknown;
    }
  }
}

/// بنر واحد قادم من الباك إند المخصص.
///
/// ملاحظة: `imageUrl` / `mobileImageUrl` قد تكون روابط مطلقة (http...) أو
/// مسارات نسبية حوّلها الخادم عبر Storage::url. يفضّل [displayImageUrl] صورة
/// الموبايل عند توفرها.
class MobileBanner extends Equatable {
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final String? mobileImageUrl;
  final String? link;
  final String? buttonText;
  final BannerType type;
  final String? position;
  final int sortOrder;
  final DateTime? startDate;
  final DateTime? endDate;

  const MobileBanner({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    this.imageUrl,
    this.mobileImageUrl,
    this.link,
    this.buttonText,
    this.type = BannerType.main,
    this.position,
    this.sortOrder = 0,
    this.startDate,
    this.endDate,
  });

  factory MobileBanner.fromJson(Map<String, dynamic> json) {
    return MobileBanner(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      mobileImageUrl: json['mobileImageUrl'] as String?,
      link: json['link'] as String? ?? json['target'] as String?,
      buttonText: json['buttonText'] as String?,
      type: BannerType.fromString(json['type'] as String?),
      position: json['position'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
    );
  }

  /// الصورة المفضّلة للعرض: صورة الموبايل إن وُجدت، وإلا الصورة الأساسية.
  String get displayImageUrl {
    final mobile = mobileImageUrl?.trim() ?? '';
    if (mobile.isNotEmpty) return mobile;
    return imageUrl?.trim() ?? '';
  }

  bool get hasImage => displayImageUrl.isNotEmpty;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    if (s.isEmpty || s.startsWith('0000')) return null;
    return DateTime.tryParse(s);
  }

  @override
  List<Object?> get props => [
    id,
    title,
    subtitle,
    imageUrl,
    mobileImageUrl,
    link,
    type,
    sortOrder,
  ];
}
