import 'package:flutter/material.dart';

abstract final class AppColors {
  static bool isDark = false;
  static Color seedColor = const Color(0xFF2788F5);

  static Color _tint(Color base, Color tint, double opacity) =>
      Color.alphaBlend(tint.withValues(alpha: opacity), base);

  static Color get page => _tint(
    isDark ? const Color(0xFF101317) : const Color(0xFFF7F9FC),
    primary,
    isDark ? 0.025 : 0.018,
  );
  static Color get sidebar => _tint(
    isDark ? const Color(0xFF151A21) : const Color(0xFFF9FBFD),
    primary,
    isDark ? 0.055 : 0.035,
  );
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
  // Keep the selected swatch and the real interface color identical. Material's
  // generated primary tone is intentionally avoided here because it muted vivid
  // seeds into a grey-blue/purple in the player controls.
  static Color get primary =>
      isDark ? Color.lerp(seedColor, Colors.white, 0.20)! : seedColor;
  static Color get primaryPressed => isDark
      ? Color.lerp(primary, Colors.white, 0.24)!
      : Color.lerp(primary, Colors.black, 0.18)!;
  static Color get accent => HSLColor.fromColor(primary)
      .withHue((HSLColor.fromColor(primary).hue + 32) % 360)
      .withSaturation(
        (HSLColor.fromColor(primary).saturation * 0.92).clamp(0.46, 0.82),
      )
      .toColor();
  static Color get favorite =>
      isDark ? const Color(0xFFFF7698) : const Color(0xFFED4C75);
  static Color get favoriteSoft =>
      favorite.withValues(alpha: isDark ? 0.16 : 0.10);
  static Color get accentSoft => _tint(
    isDark ? const Color(0xFF20242C) : const Color(0xFFF5F7FA),
    accent,
    isDark ? 0.20 : 0.10,
  );
  static Color get selected => _tint(
    isDark ? const Color(0xFF20262F) : const Color(0xFFF3F6FA),
    primary,
    isDark ? 0.18 : 0.10,
  );
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
  static Color get playerSurface =>
      isDark ? const Color(0xE61A2029) : const Color(0xEFFFFFFF);
  static Color get progressTrack =>
      isDark ? const Color(0xFF303945) : const Color(0xFFDDE6F1);
  static Color get progressBuffered =>
      primary.withValues(alpha: isDark ? 0.25 : 0.18);
  static Color get tooltipSurface =>
      isDark ? const Color(0xFFF3F6FA) : const Color(0xFF171A1F);
  static Color get tooltipText =>
      isDark ? const Color(0xFF171A1F) : Colors.white;
}

abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 22;
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

  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: AppColors.isDark ? 0.32 : 0.72),
      blurRadius: AppColors.isDark ? 22 : 30,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color: AppColors.primary.withValues(
        alpha: AppColors.isDark ? 0.24 : 0.20,
      ),
      blurRadius: 22,
      offset: const Offset(0, 8),
    ),
  ];
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primary = dark
        ? Color.lerp(AppColors.seedColor, Colors.white, 0.20)!
        : AppColors.seedColor;
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
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: primary,
        inactiveTrackColor: dark
            ? const Color(0xFF303945)
            : const Color(0xFFDDE6F1),
        thumbColor: surface,
        overlayColor: primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark
            ? const Color(0xFF202733)
            : const Color(0xFFF5F8FC),
        selectedColor: Color.alphaBlend(
          primary.withValues(alpha: dark ? 0.18 : 0.10),
          dark ? const Color(0xFF202733) : const Color(0xFFF5F8FC),
        ),
        side: BorderSide(
          color: dark ? const Color(0xFF303945) : const Color(0xFFE3E9F1),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        labelStyle: TextStyle(
          color: dark ? const Color(0xFFB8C4D2) : const Color(0xFF536171),
          fontSize: 12,
          fontWeight: FontWeight.w600,
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
