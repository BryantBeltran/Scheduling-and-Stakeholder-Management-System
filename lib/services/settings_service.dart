import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Lightweight singleton that holds app-wide settings (theme, language)
/// and notifies listeners when they change.
class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  bool _loaded = false;

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

  /// Load theme/language from Firestore for the given user.
  /// Call this at app startup after authentication.
  Future<void> loadUserSettings(String userId) async {
    if (_loaded) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = doc.data();
      if (data != null) {
        final settings = data['settings'] as Map<String, dynamic>? ?? {};
        final theme = settings['theme'] as String? ?? 'System';
        final lang = settings['language'] as String? ?? 'English';
        setThemeModeFromString(theme);
        setLanguage(lang);
      }
      _loaded = true;
    } catch (e) {
      debugPrint('Error loading user settings: $e');
    }
  }

  /// Reset loaded state (call on sign-out).
  void reset() {
    _loaded = false;
    _themeMode = ThemeMode.system;
    _language = 'English';
    notifyListeners();
  }
}
