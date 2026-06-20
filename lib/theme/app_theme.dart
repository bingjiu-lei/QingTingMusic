import 'package:flutter/material.dart';

abstract final class AppColors {
  static bool isDark = false;

  static Color get page =>
      isDark ? const Color(0xFF111419) : const Color(0xFFF7F9FC);
  static Color get sidebar =>
      isDark ? const Color(0xFF15191F) : const Color(0xFFFFFFFF);
  static Color get surface =>
      isDark ? const Color(0xFF191E25) : const Color(0xFFFFFFFF);
  static Color get surfaceMuted =>
      isDark ? const Color(0xFF20262F) : const Color(0xFFF4F7FB);
  static Color get primary =>
      isDark ? const Color(0xFF4B9BFF) : const Color(0xFF2788F5);
  static Color get primaryPressed =>
      isDark ? const Color(0xFF78B4FF) : const Color(0xFF126ED0);
  static Color get selected =>
      isDark ? const Color(0xFF1D3552) : const Color(0xFFEAF3FF);
  static Color get text =>
      isDark ? const Color(0xFFF3F6FA) : const Color(0xFF171A1F);
  static Color get muted =>
      isDark ? const Color(0xFF98A4B3) : const Color(0xFF7A8491);
  static Color get faint =>
      isDark ? const Color(0xFF687587) : const Color(0xFFA9B1BC);
  static Color get divider =>
      isDark ? const Color(0xFF2A313B) : const Color(0xFFE9EDF2);
  static Color get danger =>
      isDark ? const Color(0xFFFF7373) : const Color(0xFFD94B4B);
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? const Color(0xFF4B9BFF) : const Color(0xFF2788F5);
    final surface = dark ? const Color(0xFF191E25) : Colors.white;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansSC',
      brightness: brightness,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF111419)
          : const Color(0xFFF7F9FC),
      colorScheme: scheme.copyWith(
        primary: primary,
        onPrimary: Colors.white,
        surface: surface,
      ),
      splashFactory: InkSparkle.splashFactory,
      dividerColor: dark ? const Color(0xFF2A313B) : const Color(0xFFE9EDF2),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: dark
              ? const Color(0xFF98A4B3)
              : const Color(0xFF7A8491),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFF3F6FA) : const Color(0xFF171A1F),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(
          color: dark ? const Color(0xFF171A1F) : Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }
}
