import 'package:flutter/foundation.dart';

import '../services/app_preferences_service.dart';
import '../theme/app_theme.dart';

class ThemeController extends ChangeNotifier {
  static const _key = 'dark_mode';
  final AppPreferencesService _preferences = AppPreferencesService();

  bool isDark = false;

  Future<void> initialize() async {
    isDark = await _preferences.read(_key) == true;
    AppColors.isDark = isDark;
    notifyListeners();
  }

  Future<void> toggle() async {
    isDark = !isDark;
    AppColors.isDark = isDark;
    notifyListeners();
    await _preferences.write(_key, isDark);
  }
}
