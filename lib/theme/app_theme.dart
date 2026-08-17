import 'package:flutter/material.dart';

abstract final class AppColors {
  static bool isDark = false;
  static Color seedColor = const Color(0xFF2788F5);
  static bool? _transitionFromDark;
  static bool? _transitionToDark;
  static double _transitionProgress = 1;

  static Color _tint(Color base, Color tint, double opacity) =>
      Color.alphaBlend(tint.withValues(alpha: opacity), base);
  static Color themed(Color light, Color dark) {
    final from = _transitionFromDark;
    final to = _transitionToDark;
    if (from == null || to == null) return isDark ? dark : light;
    return Color.lerp(
      from ? dark : light,
      to ? dark : light,
      _transitionProgress,
    )!;
  }

  static void beginThemeTransition({
    required bool fromDark,
    required bool toDark,
  }) {
    _transitionFromDark = fromDark;
    _transitionToDark = toDark;
    _transitionProgress = 0;
  }

  static void updateThemeTransition(double progress) =>
      _transitionProgress = progress.clamp(0, 1);

  static void endThemeTransition() {
    _transitionFromDark = null;
    _transitionToDark = null;
    _transitionProgress = 1;
  }

  static Color get page =>
      themed(const Color(0xFFF7F9FC), const Color(0xFF101317));
  static Color get sidebar =>
      themed(const Color(0xFFF9FBFD), const Color(0xFF151A21));
  static Color get surface => themed(Colors.white, const Color(0xFF181D24));
  static Color get surfaceElevated =>
      themed(Colors.white, const Color(0xFF202733));
  static Color get surfaceMuted =>
      themed(const Color(0xFFF4F7FB), const Color(0xFF222832));
  static Color get surfaceHover =>
      themed(const Color(0xFFF1F6FD), const Color(0xFF242C38));
  static Color get surfacePressed =>
      themed(const Color(0xFFE8F2FF), const Color(0xFF1E2631));
  // Keep the selected swatch and the real interface color identical. Material's
  // generated primary tone is intentionally avoided here because it muted vivid
  // seeds into a grey-blue/purple in the player controls.
  static Color get primary =>
      themed(seedColor, Color.lerp(seedColor, Colors.white, 0.20)!);
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
      themed(const Color(0xFF171A1F), const Color(0xFFF2F5F8));
  static Color get muted =>
      themed(const Color(0xFF7A8491), const Color(0xFF9AA6B2));
  static Color get faint =>
      themed(const Color(0xFFA9B1BC), const Color(0xFF6F7B88));
  static Color get divider =>
      themed(const Color(0xFFE9EDF2), const Color(0xFF28303A));
  static Color get border =>
      themed(const Color(0xFFE7ECF3), const Color(0xFF303945));
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

/// 液态玻璃材质 token。
/// 分两档模糊:常驻界面(播放栏、控制岛)用 blurChrome,
/// 瞬时浮层(队列、音量、弹窗)用 blurOverlay。
/// 静止背景上的玻璃(侧栏、标签胶囊)不做真实背景模糊,只用半透明叠色,
/// 保持每帧模糊数量可控。
abstract final class AppGlass {
  static const double blurChrome = 16;
  static const double blurOverlay = 26;

  static Color get surface => AppColors.themed(
    Colors.white.withValues(alpha: 0.88),
    const Color(0xFF131922).withValues(alpha: 0.92),
  );
  static Color get surfaceStrong => AppColors.themed(
    Colors.white.withValues(alpha: 0.94),
    const Color(0xFF151C26).withValues(alpha: 0.95),
  );
  static Color get surfaceSoft => AppColors.themed(
    const Color(0xFFF4F7FB).withValues(alpha: 0.85),
    const Color(0xFF1C2430).withValues(alpha: 0.70),
  );
  static Color get border => AppColors.border;
  static Color get highlight => AppColors.themed(
    Colors.white.withValues(alpha: 0.35),
    AppColors.primary.withValues(alpha: 0.08),
  );
  static Color get thumb =>
      AppColors.themed(Colors.white, const Color(0xFF242C38));
}

/// 统一字体层级。NotoSansSC 是应用原有的品牌字体；所有页面都从同一套
/// 字体和字重映射取值，避免导航、列表与播放页出现不一致的字形。
abstract final class AppTypography {
  static TextStyle style(
    double size,
    double weight, {
    double? height,
    double? letterSpacing,
    Color? color,
    List<FontFeature>? features,
  }) => TextStyle(
    fontSize: size,
    fontWeight: _closestWeight(weight),
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontFeatures: features,
    fontFamily: 'NotoSansSC',
  );

  static FontWeight _closestWeight(double weight) {
    final index = ((weight / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[index];
  }

  static TextStyle get pageTitle =>
      style(26, 800, letterSpacing: 0.3, color: AppColors.text);
  static TextStyle get pageSubtitle => style(13, 450, color: AppColors.muted);
  static TextStyle get panelTitle => style(16, 700, color: AppColors.text);
  static TextStyle get body => style(14, 500, color: AppColors.text);
  static TextStyle get caption => style(12, 500, color: AppColors.muted);
  static TextStyle timeCode(double size, {Color? color}) => style(
    size,
    500,
    color: color ?? AppColors.faint,
    features: const [FontFeature.tabularFigures()],
  );
}

abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 22;
  static const double pill = 999;
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
