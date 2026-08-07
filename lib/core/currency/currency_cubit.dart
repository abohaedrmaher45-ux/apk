import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_formatter.dart';

class CurrencyCubit extends Cubit<String?> {
  static const String currencyKey = 'app_currency_code';
  late SharedPreferences _prefs;

  CurrencyCubit() : super('EUR');

  Future<void> initialize(SharedPreferences prefs) async {
    _prefs = prefs;
    CurrencyFormatter.initialize(prefs);
    await _prefs.setString(currencyKey, 'EUR');
    await CurrencyFormatter.updateSelectedCurrency('EUR', prefs: _prefs);
    emit('EUR');
  }

  Future<void> setCurrency(String currencyCode) async {
    emit('EUR');
    await CurrencyFormatter.updateSelectedCurrency(
      'EUR',
      prefs: _prefs,
    );
  }

  Future<void> clearCurrency() async {
    emit('EUR');
    await CurrencyFormatter.updateSelectedCurrency('EUR', prefs: _prefs);
  }
}
