import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'quinch_theme';
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString(_themeKey);
    if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (theme == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      // Default to dark mode for new users
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.dark:
        await prefs.setString(_themeKey, 'dark');
        break;
      case ThemeMode.system:
        await prefs.setString(_themeKey, 'system');
        break;
      default:
        await prefs.setString(_themeKey, 'light');
    }
    notifyListeners();
  }

  void toggleTheme() {
    setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Alias for setThemeMode
  void setTheme(ThemeMode mode) => setThemeMode(mode);
}
