import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('es', 'ES');
  static const String _localeKey = 'selected_locale';

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_localeKey);
      if (localeCode != null) {
        final parts = localeCode.split('_');
        if (parts.length == 2) {
          _locale = Locale(parts[0], parts[1]);
          notifyListeners();
        }
      }
    } catch (e) {
      // Si hay error, usar el locale por defecto
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, '${locale.languageCode}_${locale.countryCode}');
    } catch (e) {
      // Si hay error guardando, continuar de todas formas
    }
  }

  void setLocaleFromCode(String languageCode) {
    Locale newLocale;
    switch (languageCode) {
      case 'es':
        newLocale = const Locale('es', 'ES');
        break;
      case 'en':
        newLocale = const Locale('en', 'US');
        break;
      case 'it':
        newLocale = const Locale('it', 'IT');
        break;
      case 'de':
        newLocale = const Locale('de', 'DE');
        break;
      default:
        newLocale = const Locale('es', 'ES');
    }
    setLocale(newLocale);
  }
}
