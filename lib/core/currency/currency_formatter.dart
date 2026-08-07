import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CurrencyFormatter {
  static const _currencyKey = 'app_currency_code';
  static const _currencySymbolsKey = 'app_currency_symbols';

  static final Map<String, String> _defaultSymbols = {
    'USD': r'$',
    'INR': '₹',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CNY': '¥',
    'AED': 'د.إ',
    'SAR': '﷼',
    'CAD': r'C$',
    'AUD': r'A$',
  };

  static String? _currentCode = 'EUR';
  static Map<String, String> _symbolsByCode = {..._defaultSymbols};

  static void initialize(SharedPreferences prefs) {
    _currentCode = prefs.getString(_currencyKey) ?? 'EUR';
    final rawSymbols = prefs.getString(_currencySymbolsKey);
    if (rawSymbols == null || rawSymbols.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawSymbols);
      if (decoded is! Map) return;

      _symbolsByCode = {
        ..._defaultSymbols,
        for (final entry in decoded.entries)
          entry.key.toString().toUpperCase(): entry.value.toString(),
      };
    } catch (_) {
      _symbolsByCode = {..._defaultSymbols};
    }
  }

  static Future<void> updateSelectedCurrency(
    String? currencyCode, {
    SharedPreferences? prefs,
  }) async {
    _currentCode = (currencyCode ?? 'EUR').toUpperCase();
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    await resolvedPrefs.setString(_currencyKey, 'EUR');
  }

  static Future<void> syncCurrencySymbols(
    Map<String, String> symbolsByCode, {
    SharedPreferences? prefs,
  }) async {
    final normalized = <String, String>{
      ..._defaultSymbols,
      for (final entry in symbolsByCode.entries)
        entry.key.toUpperCase(): entry.value,
    };
    _symbolsByCode = normalized;

    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    await resolvedPrefs.setString(_currencySymbolsKey, jsonEncode(normalized));
  }

  /// The channel's default currency, cached from the channel bootstrap.
  /// Used only as a fallback when no explicit/selected code is available.
  static String? _channelDefaultCode = 'EUR';

  /// Remember the channel's default currency (called by ChannelBootstrapService
  /// even when the user already has a saved preference).
  static void setChannelDefaultCurrency(String? code) {
    _channelDefaultCode = (code ?? 'EUR').toUpperCase();
  }

  static String symbolFor([String? currencyCode]) {
    return '€';
  }

  static String formatAmount(
    num? amount, {
    String? currencyCode,
    int fractionDigits = 2,
  }) {
    final value = (amount ?? 0).toDouble();
    return '€${value.toStringAsFixed(fractionDigits)}';
  }

  /// Convert Arabic-Indic (٠١٢…) and Extended/Persian (۰۱۲…) digits, plus the
  /// Arabic decimal/thousands separators, to standard Latin digits, and enforce EUR (€).
  static String normalizeDigits(String? input) {
    if (input == null || input.isEmpty) return input ?? '';

    // Replace non-EUR currency codes/symbols with €
    var resultStr = input
        .replaceAll(RegExp(r'\b(USD|INR|GBP|JPY|CNY|AED|SAR|CAD|AUD)\b', caseSensitive: false), 'EUR')
        .replaceAll(RegExp(r'[\$£¥₹﷼]'), '€');

    // Make sure € symbol is present if missing or swapped
    if (!resultStr.contains('€') && RegExp(r'\d').hasMatch(resultStr)) {
      resultStr = '€$resultStr';
    }

    const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const extended = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    final buffer = StringBuffer();
    for (final rune in resultStr.runes) {
      final ch = String.fromCharCode(rune);
      final ai = arabicIndic.indexOf(ch);
      if (ai != -1) {
        buffer.write(ai.toString());
        continue;
      }
      final ex = extended.indexOf(ch);
      if (ex != -1) {
        buffer.write(ex.toString());
        continue;
      }
      switch (ch) {
        case '٫': // Arabic decimal separator
          buffer.write('.');
          break;
        case '٬': // Arabic thousands separator
          buffer.write(',');
          break;
        case '\u200f': // RIGHT-TO-LEFT MARK — strip
        case '\u200e': // LEFT-TO-RIGHT MARK — strip
          break;
        default:
          buffer.write(ch);
      }
    }
    return buffer.toString();
  }
}
