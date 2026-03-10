import 'package:flutter/material.dart';

/// Lightweight singleton that holds app-wide settings (theme, language)
/// and notifies listeners when they change.
class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  String _language = 'English';
  String get language => _language;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setThemeModeFromString(String value) {
    switch (value) {
      case 'Light':
        setThemeMode(ThemeMode.light);
      case 'Dark':
        setThemeMode(ThemeMode.dark);
      default:
        setThemeMode(ThemeMode.system);
    }
  }

  String get themeModeString {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  void setLanguage(String lang) {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
  }
}
