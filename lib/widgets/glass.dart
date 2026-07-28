import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 液态玻璃面板。
///
/// [blur] 启用 BackdropFilter 模糊背景；
/// [showHighlight] 渲染顶部柔和微光高光；
/// [showBorder] 渲染 1px 半透明玻璃边框。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = AppRadius.xl,
    this.borderRadius,
    this.blur,
    this.tint,
    this.padding,
    this.shadows,
    this.showBorder = true,
    this.showHighlight = true,
  });

  final Widget child;
  final double radius;
  final BorderRadius? borderRadius;
  final double? blur;
  final Color? tint;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;
  final bool showBorder;
  final bool showHighlight;

  @override
  Widget build(BuildContext context) {
    final shape = borderRadius ?? BorderRadius.circular(radius);
    Widget core = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    if (showHighlight) {
      core = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppGlass.highlight, Colors.white.withValues(alpha: 0)],
            stops: const [0, 0.55],
          ),
        ),
        child: core,
      );
    }
    core = DecoratedBox(
      decoration: BoxDecoration(color: tint ?? AppGlass.surface),
      child: core,
    );
    if (blur != null) {
      core = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur!, sigmaY: blur!),
        child: core,
      );
    }
    core = ClipRRect(borderRadius: shape, child: core);
    return Container(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: shadows ?? AppShadows.soft,
        border: showBorder
            ? Border.all(color: AppGlass.border.withValues(alpha: 0.40))
            : null,
      ),
      child: core,
    );
  }
}

/// 轻量柔和胶囊分段标签。
/// 与侧边栏导航风格完全统一，平滑舒适，非侵入式。
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.dense = false,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) return const SizedBox.shrink();

    final tabRadius = BorderRadius.circular(AppRadius.lg);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) SizedBox(width: dense ? 4 : 6),
            _GlassTabCell(
              label: tabs[i],
              dense: dense,
              selected: i == selectedIndex,
              pillRadius: tabRadius,
              onTap: i == selectedIndex ? null : () => onChanged(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassTabCell extends StatefulWidget {
  const _GlassTabCell({
    required this.label,
    required this.dense,
    required this.selected,
    required this.pillRadius,
    required this.onTap,
  });

  final String label;
  final bool dense;
  final bool selected;
  final BorderRadius pillRadius;
  final VoidCallback? onTap;

  @override
  State<_GlassTabCell> createState() => _GlassTabCellState();
}

class _GlassTabCellState extends State<_GlassTabCell> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final isDark = AppColors.isDark;

    final backgroundColor = selected
        ? AppColors.primary.withValues(alpha: isDark ? 0.20 : 0.10)
        : _hovered
        ? AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.05)
        : Colors.transparent;

    final borderColor = selected
        ? AppColors.primary.withValues(alpha: isDark ? 0.38 : 0.22)
        : _hovered
        ? AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.10)
        : Colors.transparent;

    final boxShadow = selected
        ? [
            BoxShadow(
              color: AppColors.primary.withValues(
                alpha: isDark ? 0.16 : 0.08,
              ),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
        : null;

    final textColor = selected
        ? AppColors.primaryPressed
        : _hovered
        ? AppColors.text
        : AppColors.muted;

    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed
              ? 0.96
              : _hovered
              ? 1.02
              : 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            padding: EdgeInsets.symmetric(
              horizontal: widget.dense ? 14 : 16,
              vertical: widget.dense ? 6 : 7.5,
            ),
            decoration: BoxDecoration(
              borderRadius: widget.pillRadius,
              color: backgroundColor,
              border: Border.all(color: borderColor, width: 1),
              boxShadow: boxShadow,
            ),
            child: AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              style: AppTypography.style(
                13.5,
                selected ? 700 : 600,
                color: textColor,
                letterSpacing: selected ? 0.2 : 0,
              ),
              child: Text(widget.label, maxLines: 1),
            ),
          ),
        ),
      ),
    );
  }
}
