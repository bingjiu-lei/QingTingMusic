import 'package:flutter/material.dart';

import '../services/app_preferences_service.dart';
import '../theme/app_theme.dart';

class ThemeController extends ChangeNotifier {
  static const _darkModeKey = 'dark_mode';
  static const _accentColorKey = 'accent_color';
  static const _coverAccentKey = 'cover_accent';
  static const defaultAccentColor = Color(0xFF2788F5);
  final AppPreferencesService _preferences = AppPreferencesService();

  bool isDark = false;
  Color accentColor = defaultAccentColor;
  bool coverAccentEnabled = false;
  Color? _coverAccent;

  Future<void> initialize() async {
    isDark = await _preferences.read(_darkModeKey) == true;
    final storedColor = await _preferences.read(_accentColorKey);
    final colorValue = storedColor is int
        ? storedColor
        : int.tryParse(storedColor?.toString() ?? '');
    accentColor = colorValue == null ? defaultAccentColor : Color(colorValue);
    coverAccentEnabled = await _preferences.read(_coverAccentKey) == true;
    AppColors.isDark = isDark;
    AppColors.seedColor = _coverAccent ?? accentColor;
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
    if (!coverAccentEnabled) AppColors.seedColor = color;
    notifyListeners();
    await _preferences.write(_accentColorKey, color.toARGB32());
  }

  Future<void> setCoverAccentEnabled(bool value) async {
    if (coverAccentEnabled == value) return;
    coverAccentEnabled = value;
    if (!value) {
      _coverAccent = null;
      AppColors.seedColor = accentColor;
    }
    notifyListeners();
    await _preferences.write(_coverAccentKey, value);
  }

  void applyCoverAccent(Color? color) {
    if (!coverAccentEnabled) return;
    final next = color ?? accentColor;
    if ((_coverAccent ?? accentColor).toARGB32() == next.toARGB32()) return;
    _coverAccent = color;
    AppColors.seedColor = next;
    notifyListeners();
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
