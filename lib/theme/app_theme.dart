import 'package:flutter/material.dart';

abstract final class AppColors {
  static bool isDark = false;

  static Color get page =>
      isDark ? const Color(0xFF101317) : const Color(0xFFF7F9FC);
  static Color get sidebar =>
      isDark ? const Color(0xFF141820) : const Color(0xFFFFFFFF);
  static Color get surface =>
      isDark ? const Color(0xFF181D24) : const Color(0xFFFFFFFF);
  static Color get surfaceElevated =>
      isDark ? const Color(0xFF202733) : const Color(0xFFFFFFFF);
  static Color get surfaceMuted =>
      isDark ? const Color(0xFF222832) : const Color(0xFFF4F7FB);
  static Color get surfaceHover =>
      isDark ? const Color(0xFF242C38) : const Color(0xFFF1F6FD);
  static Color get surfacePressed =>
      isDark ? const Color(0xFF1E2631) : const Color(0xFFE8F2FF);
  static Color get primary =>
      isDark ? const Color(0xFF4B9BFF) : const Color(0xFF2788F5);
  static Color get primaryPressed =>
      isDark ? const Color(0xFF78B4FF) : const Color(0xFF126ED0);
  static Color get selected =>
      isDark ? const Color(0xFF1B2A3D) : const Color(0xFFEAF3FF);
  static Color get text =>
      isDark ? const Color(0xFFF2F5F8) : const Color(0xFF171A1F);
  static Color get muted =>
      isDark ? const Color(0xFF9AA6B2) : const Color(0xFF7A8491);
  static Color get faint =>
      isDark ? const Color(0xFF6F7B88) : const Color(0xFFA9B1BC);
  static Color get divider =>
      isDark ? const Color(0xFF28303A) : const Color(0xFFE9EDF2);
  static Color get border =>
      isDark ? const Color(0xFF303945) : const Color(0xFFE7ECF3);
  static Color get danger =>
      isDark ? const Color(0xFFFF7373) : const Color(0xFFD94B4B);
  static Color get shadow =>
      isDark ? Colors.black.withValues(alpha: 0.26) : const Color(0x1A6A7890);
  static Color get scrim =>
      Colors.black.withValues(alpha: isDark ? 0.42 : 0.18);
}

abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 16;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 260);
  static const curve = Curves.easeOutCubic;
}

abstract final class AppShadows {
  static List<BoxShadow> get soft => [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: AppColors.isDark ? 18 : 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get popover => [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
  ];
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? const Color(0xFF4B9BFF) : const Color(0xFF2788F5);
    final surface = dark ? const Color(0xFF181D24) : Colors.white;
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
          ? const Color(0xFF101317)
          : const Color(0xFFF7F9FC),
      colorScheme: scheme.copyWith(
        primary: primary,
        onPrimary: Colors.white,
        surface: surface,
      ),
      splashFactory: InkSparkle.splashFactory,
      dividerColor: dark ? const Color(0xFF28303A) : const Color(0xFFE9EDF2),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.38),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dark
              ? const Color(0xFFB8C4D2)
              : const Color(0xFF536171),
          side: BorderSide(
            color: dark ? const Color(0xFF303945) : const Color(0xFFE2E8F0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: dark
              ? const Color(0xFF9AA6B2)
              : const Color(0xFF7A8491),
          hoverColor: primary.withValues(alpha: dark ? 0.10 : 0.08),
          highlightColor: primary.withValues(alpha: dark ? 0.14 : 0.10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF303945) : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF303945) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: primary, width: 1.4),
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
