import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppIconButtonVariant {
  /// Completely transparent by default; on hover, shows subtle theme tint + scale lift.
  /// Ideal for toolbar items, song rows, bottom player bar, now playing page, and sidebar docks.
  ghost,

  /// Subtle muted/surface background by default; on hover, slightly elevates with scale lift & glow.
  /// Ideal for header action buttons (Play All, Favorite, Delete, Back, etc.).
  filled,
}

/// A unified, highly-polished circular icon button with smooth floating lift animation and glow.
class AppIconButton extends StatefulWidget {
  const AppIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.variant = AppIconButtonVariant.ghost,
    this.size = 36.0,
    this.iconSize,
    this.iconColor,
    this.hoverIconColor,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.shadowColor,
    this.selected = false,
    this.selectedColor,
    this.selectedBackgroundColor,
    this.alwaysGlow = false,
    this.scaleFactor = 1.08,
    this.child,
  });

  /// Factory for standard header action buttons (like Play All, Favorite, Delete, Back)
  factory AppIconButton.filled({
    Key? key,
    required String tooltip,
    required VoidCallback? onPressed,
    IconData? icon,
    double size = 36.0,
    double? iconSize,
    Color? iconColor,
    Color? hoverIconColor,
    Color? backgroundColor,
    Color? hoverBackgroundColor,
    Color? shadowColor,
    bool selected = false,
    Color? selectedColor,
    Color? selectedBackgroundColor,
    bool alwaysGlow = false,
    double scaleFactor = 1.08,
    Widget? child,
  }) => AppIconButton(
    key: key,
    icon: icon,
    tooltip: tooltip,
    onPressed: onPressed,
    variant: AppIconButtonVariant.filled,
    size: size,
    iconSize: iconSize,
    iconColor: iconColor,
    hoverIconColor: hoverIconColor,
    backgroundColor: backgroundColor,
    hoverBackgroundColor: hoverBackgroundColor,
    shadowColor: shadowColor,
    selected: selected,
    selectedColor: selectedColor,
    selectedBackgroundColor: selectedBackgroundColor,
    alwaysGlow: alwaysGlow,
    scaleFactor: scaleFactor,
    child: child,
  );

  /// Factory for clean toolbar / row / player bar buttons (no heavy box, smooth floating hover)
  factory AppIconButton.ghost({
    Key? key,
    required String tooltip,
    required VoidCallback? onPressed,
    IconData? icon,
    double size = 36.0,
    double? iconSize,
    Color? iconColor,
    Color? hoverIconColor,
    Color? shadowColor,
    bool selected = false,
    Color? selectedColor,
    Color? selectedBackgroundColor,
    bool alwaysGlow = false,
    double scaleFactor = 1.08,
    Widget? child,
  }) => AppIconButton(
    key: key,
    icon: icon,
    tooltip: tooltip,
    onPressed: onPressed,
    variant: AppIconButtonVariant.ghost,
    size: size,
    iconSize: iconSize,
    iconColor: iconColor,
    hoverIconColor: hoverIconColor,
    shadowColor: shadowColor,
    selected: selected,
    selectedColor: selectedColor,
    selectedBackgroundColor: selectedBackgroundColor,
    alwaysGlow: alwaysGlow,
    scaleFactor: scaleFactor,
    child: child,
  );

  final IconData? icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;
  final double size;
  final double? iconSize;
  final Color? iconColor;
  final Color? hoverIconColor;
  final Color? backgroundColor;
  final Color? hoverBackgroundColor;
  final Color? shadowColor;
  final bool selected;
  final Color? selectedColor;
  final Color? selectedBackgroundColor;
  final bool alwaysGlow;
  final Widget? child;
  final double scaleFactor;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final isDark = AppColors.isDark;
    final size = widget.size;
    final iconSize = widget.iconSize ?? (size * 0.52);

    final selected = widget.selected;

    // Normal foreground
    final defaultColor = selected
        ? (widget.selectedColor ?? AppColors.primary)
        : (widget.iconColor ?? AppColors.muted);

    // Hovered foreground
    final hoverColor = selected
        ? (widget.selectedColor ?? AppColors.primary)
        : (widget.hoverIconColor ?? (widget.iconColor ?? AppColors.primary));

    // Background color resolution
    Color bg;
    if (!enabled) {
      bg = Colors.transparent;
    } else if (widget.variant == AppIconButtonVariant.filled) {
      if (_hovered) {
        bg =
            widget.hoverBackgroundColor ??
            (widget.backgroundColor != null
                ? widget.backgroundColor!
                : AppColors.primary.withValues(alpha: isDark ? 0.20 : 0.12));
      } else if (selected) {
        bg =
            widget.selectedBackgroundColor ??
            (widget.backgroundColor ??
                AppColors.surfaceMuted.withValues(alpha: isDark ? 0.40 : 0.60));
      } else {
        bg =
            widget.backgroundColor ??
            AppColors.surfaceMuted.withValues(alpha: isDark ? 0.40 : 0.60);
      }
    } else {
      // ghost variant
      if (_hovered) {
        bg =
            widget.hoverBackgroundColor ??
            AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08);
      } else if (selected) {
        bg =
            widget.selectedBackgroundColor ??
            AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10);
      } else {
        bg = widget.backgroundColor ?? Colors.transparent;
      }
    }

    // Shadow / Halo calculation
    final activeGlow = enabled && (widget.alwaysGlow || _hovered);
    final baseShadowColor =
        widget.shadowColor ??
        (selected
            ? (widget.selectedColor ?? AppColors.primary)
            : AppColors.primary);

    final List<BoxShadow>? shadows = activeGlow
        ? [
            BoxShadow(
              color: baseShadowColor.withValues(
                alpha: widget.alwaysGlow
                    ? (_hovered
                          ? (isDark ? 0.45 : 0.32)
                          : (isDark ? 0.30 : 0.18))
                    : (isDark ? 0.24 : 0.12),
              ),
              blurRadius: _hovered ? 14 : 8,
              offset: Offset(0, _hovered ? 3 : 2),
            ),
          ]
        : null;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: !enabled
                ? 1.0
                : _pressed
                ? 0.94
                : _hovered
                ? widget.scaleFactor
                : 1.0,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOutQuad,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOutQuad,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
                boxShadow: shadows,
              ),
              child: Center(
                child: widget.child != null
                    ? IconTheme(
                        data: IconThemeData(
                          color: enabled
                              ? (_hovered ? hoverColor : defaultColor)
                              : AppColors.faint.withValues(alpha: 0.40),
                          size: iconSize,
                        ),
                        child: widget.child!,
                      )
                    : (widget.icon != null
                          ? Icon(
                              widget.icon,
                              size: iconSize,
                              color: enabled
                                  ? (_hovered ? hoverColor : defaultColor)
                                  : AppColors.faint.withValues(alpha: 0.40),
                            )
                          : const SizedBox.shrink()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
