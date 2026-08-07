import 'package:graphql_flutter/graphql_flutter.dart';

import '../models/mobile_banner.dart';

/// يجلب البنرات المخصصة من الباك إند عبر GraphQL (query: mobileBanners).
///
/// البنرات اختيارية للصفحة الرئيسية: عند أي خطأ نُرجع قائمة فارغة بدل رمي
/// استثناء، حتى لا ينهار تحميل الصفحة إن تعذّر جلب البنرات فقط.
class BannerRepository {
  final GraphQLClient _client;

  BannerRepository({required GraphQLClient client}) : _client = client;

  /// جلب كل البنرات الظاهرة مرتّبة حسب sortOrder.
  Future<List<MobileBanner>> fetchBanners() async {
    final result = await _client.query(
      QueryOptions(
        document: gql(BannerQueries.getMobileBanners),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
    );

    if (result.hasException) {
      // ignore: avoid_print
      print('⚠️ [BannerRepository] fetch banners failed (non-fatal): '
          '${result.exception}');
      return const <MobileBanner>[];
    }

    final list = result.data?['mobileBanners'] as List? ?? const [];
    final banners = list
        .whereType<Map<String, dynamic>>()
        .map(MobileBanner.fromJson)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return banners;
  }

  /// جلب البنرات مجمّعة حسب النوع، جاهزة للعرض في أقسام مختلفة.
  Future<Map<BannerType, List<MobileBanner>>> fetchBannersGrouped() async {
    final banners = await fetchBanners();
    final grouped = <BannerType, List<MobileBanner>>{};

    for (final banner in banners) {
      grouped.putIfAbsent(banner.type, () => []).add(banner);
    }

    return grouped;
  }
}