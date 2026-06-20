import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class ThemeController extends ChangeNotifier {
  static const _key = 'dark_mode';

  bool isDark = false;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    isDark = preferences.getBool(_key) ?? false;
    AppColors.isDark = isDark;
    notifyListeners();
  }

  Future<void> toggle() async {
    isDark = !isDark;
    AppColors.isDark = isDark;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key, isDark);
  }
}
