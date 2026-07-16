import 'package:flutter/material.dart';

import '../services/app_preferences_service.dart';
import '../theme/app_theme.dart';

class ThemeController extends ChangeNotifier {
  static const _darkModeKey = 'dark_mode';
  static const _accentColorKey = 'accent_color';
  static const defaultAccentColor = Color(0xFF2788F5);
  final AppPreferencesService _preferences = AppPreferencesService();

  bool isDark = false;
  Color accentColor = defaultAccentColor;

  Future<void> initialize() async {
    isDark = await _preferences.read(_darkModeKey) == true;
    final storedColor = await _preferences.read(_accentColorKey);
    final colorValue = storedColor is int
        ? storedColor
        : int.tryParse(storedColor?.toString() ?? '');
    accentColor = colorValue == null ? defaultAccentColor : Color(colorValue);
    AppColors.isDark = isDark;
    AppColors.seedColor = accentColor;
    notifyListeners();
  }

  Future<void> toggle() async {
    isDark = !isDark;
    AppColors.isDark = isDark;
    notifyListeners();
    await _preferences.write(_darkModeKey, isDark);
  }

  Future<void> setAccentColor(Color color) async {
    if (accentColor.toARGB32() == color.toARGB32()) return;
    accentColor = color;
    AppColors.seedColor = color;
    notifyListeners();
    await _preferences.write(_accentColorKey, color.toARGB32());
  }

  Future<void> resetAccentColor() => setAccentColor(defaultAccentColor);

  Future<void> setDarkMode(bool value) async {
    if (isDark == value) return;
    isDark = value;
    AppColors.isDark = value;
    notifyListeners();
    await _preferences.write(_darkModeKey, value);
  }
}
