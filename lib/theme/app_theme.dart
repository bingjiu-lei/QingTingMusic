import 'package:flutter/material.dart';

abstract final class AppColors {
  static const page = Color(0xFFF7F9FC);
  static const sidebar = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF4F7FB);
  static const primary = Color(0xFF2788F5);
  static const primaryPressed = Color(0xFF126ED0);
  static const selected = Color(0xFFEAF3FF);
  static const text = Color(0xFF171A1F);
  static const muted = Color(0xFF7A8491);
  static const faint = Color(0xFFA9B1BC);
  static const divider = Color(0xFFE9EDF2);
  static const danger = Color(0xFFD94B4B);
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Microsoft YaHei',
      scaffoldBackgroundColor: AppColors.page,
      colorScheme: scheme.copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: AppColors.surface,
      ),
      splashFactory: InkSparkle.splashFactory,
      dividerColor: AppColors.divider,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.muted),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
