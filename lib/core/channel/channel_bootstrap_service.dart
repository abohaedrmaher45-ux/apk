import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/account/data/models/account_models.dart';
import '../../l10n/app_localizations.dart';
import '../constants/api_constants.dart';
import '../currency/currency_cubit.dart';
import '../currency/currency_formatter.dart';
import '../graphql/queries.dart';
import '../locale/locale_cubit.dart';

class ChannelBootstrapService {
  static const String _localesCacheKey = 'cached_shop_locales';
  static const String _currenciesCacheKey = 'cached_shop_currencies';

  final GraphQLClient client;
  final SharedPreferences prefs;

  const ChannelBootstrapService({required this.client, required this.prefs});

  Future<void> bootstrap() async {
    debugPrint('🟡 ChannelBootstrapService.bootstrap started');

    try {
      final result = await client.query(
        QueryOptions(
          document: gql(StoreConfigQueries.getChannelById),
          variables: {'id': channelId.toString()},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException || result.data?['channel'] == null) {
        debugPrint(
          '🔴 ChannelBootstrapService bootstrap failed/offline: ${result.exception}',
        );
        await _setupFallbackDefaults();
        return;
      }

      final channel = result.data!['channel'] as Map<String, dynamic>;
      final locales = _parseLocales(channel);
      if (locales.isNotEmpty && !locales.any((l) => l.code == 'de')) {
        locales.add(const ShopLocale(id: '3', code: 'de', name: 'Germany', direction: 'ltr'));
      }
      final currencies = _parseCurrencies(channel);
      final defaultLocaleCode = _resolveDefaultLocaleCode(channel, locales);
      final defaultCurrencyCode = _resolveDefaultCurrencyCode(
        channel,
        currencies,
      );

      await prefs.setString(
        _localesCacheKey,
        jsonEncode(_encodeLocales(locales.isNotEmpty ? locales : _fallbackLocales)),
      );
      await prefs.setString(
        _currenciesCacheKey,
        jsonEncode(_encodeCurrencies(currencies.isNotEmpty ? currencies : _fallbackCurrencies)),
      );

      final savedLocale = prefs.getString(LocaleCubit.localeKey);
      if (savedLocale == null &&
          defaultLocaleCode != null &&
          defaultLocaleCode.isNotEmpty) {
        await prefs.setString(LocaleCubit.localeKey, defaultLocaleCode);
      }

      CurrencyFormatter.setChannelDefaultCurrency(defaultCurrencyCode);

      final savedCurrency = prefs.getString(CurrencyCubit.currencyKey);
      if (savedCurrency == null &&
          defaultCurrencyCode != null &&
          defaultCurrencyCode.isNotEmpty) {
        await CurrencyFormatter.updateSelectedCurrency(
          defaultCurrencyCode,
          prefs: prefs,
        );
      }

      await CurrencyFormatter.syncCurrencySymbols({
        for (final currency in currencies)
          currency.code.toUpperCase(): currency.symbol,
      }, prefs: prefs);

      debugPrint(
        '🟢 ChannelBootstrapService bootstrap complete: '
        '${locales.length} locales, ${currencies.length} currencies',
      );
    } catch (e) {
      debugPrint('🔴 ChannelBootstrapService exception: $e');
      await _setupFallbackDefaults();
    }
  }

  static const List<ShopLocale> _fallbackLocales = [
    ShopLocale(id: '1', code: 'en', name: 'English', direction: 'ltr'),
    ShopLocale(id: '2', code: 'ar', name: 'العربية', direction: 'rtl'),
    ShopLocale(id: '3', code: 'de', name: 'Germany', direction: 'ltr'),
  ];

  static const List<ShopCurrency> _fallbackCurrencies = [
    ShopCurrency(id: '1', code: 'EUR', name: 'Euro', symbol: '€'),
  ];

  Future<void> _setupFallbackDefaults() async {
    if (!prefs.containsKey(_localesCacheKey)) {
      await prefs.setString(
        _localesCacheKey,
        jsonEncode(_encodeLocales(_fallbackLocales)),
      );
    }
    if (!prefs.containsKey(_currenciesCacheKey)) {
      await prefs.setString(
        _currenciesCacheKey,
        jsonEncode(_encodeCurrencies(_fallbackCurrencies)),
      );
    }
  }

  List<ShopLocale> _parseLocales(Map<String, dynamic> channel) {
    final rawLocales = channel['locales'];
    if (rawLocales is List) {
      return rawLocales
          .whereType<Map<String, dynamic>>()
          .map(ShopLocale.fromJson)
          .toList();
    }
    final edges = rawLocales?['edges'] as List<dynamic>? ?? const [];
    return edges
        .map((edge) => edge['node'])
        .whereType<Map<String, dynamic>>()
        .map(ShopLocale.fromJson)
        .toList();
  }

  List<ShopCurrency> _parseCurrencies(Map<String, dynamic> channel) {
    final rawCurrencies = channel['currencies'];
    if (rawCurrencies is List) {
      return rawCurrencies
          .whereType<Map<String, dynamic>>()
          .map(ShopCurrency.fromJson)
          .toList();
    }
    final edges = rawCurrencies?['edges'] as List<dynamic>? ?? const [];
    return edges
        .map((edge) => edge['node'])
        .whereType<Map<String, dynamic>>()
        .map(ShopCurrency.fromJson)
        .toList();
  }

  String? _resolveDefaultLocaleCode(
    Map<String, dynamic> channel,
    List<ShopLocale> locales,
  ) {
    final rawDefault =
        (channel['defaultLocale'] as Map<String, dynamic>?)?['code']
            ?.toString()
            .trim();
    final supportedCodes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode.toLowerCase())
        .toSet();

    if (rawDefault != null &&
        supportedCodes.contains(rawDefault.toLowerCase())) {
      return rawDefault;
    }

    for (final locale in locales) {
      if (supportedCodes.contains(locale.code.toLowerCase())) {
        return locale.code;
      }
    }

    return prefs.getString(LocaleCubit.localeKey);
  }

  String? _resolveDefaultCurrencyCode(
    Map<String, dynamic> channel,
    List<ShopCurrency> currencies,
  ) {
    final rawDefault =
        (channel['baseCurrency'] as Map<String, dynamic>?)?['code']
            ?.toString()
            .trim();

    if (rawDefault != null &&
        currencies.any(
          (currency) => currency.code.toUpperCase() == rawDefault.toUpperCase(),
        )) {
      return rawDefault;
    }

    if (currencies.isNotEmpty) {
      return currencies.first.code;
    }

    return prefs.getString(CurrencyCubit.currencyKey);
  }

  List<Map<String, dynamic>> _encodeLocales(List<ShopLocale> locales) {
    return locales.map((locale) => locale.toJson()).toList();
  }

  List<Map<String, dynamic>> _encodeCurrencies(List<ShopCurrency> currencies) {
    return currencies.map((currency) => currency.toJson()).toList();
  }
}
