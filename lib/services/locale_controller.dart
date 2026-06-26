import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app locale and persists the user's choice via SharedPreferences.
class LocaleController extends ChangeNotifier {
  static const _key = 'app_locale';
  static const supported = [Locale('en'), Locale('ur')];

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  /// Loads the saved locale (call before runApp).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null && supported.any((l) => l.languageCode == code)) {
      _locale = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }
}
