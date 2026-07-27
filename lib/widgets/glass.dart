import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 液态玻璃面板。
///
/// [blur] 为 null 时不做真实背景模糊(用于静止背景上的玻璃,零额外开销);
/// 传入 [AppGlass.blurChrome] / [AppGlass.blurOverlay] 时启用 BackdropFilter,
/// 只应该用在会覆盖动态内容的常驻栏与浮层上。
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
        boxShadow: shadows,
        border: showBorder ? Border.all(color: AppGlass.border) : null,
      ),
      child: core,
    );
  }
}

/// 玻璃胶囊分段标签,选中丸子滑动跟随。
/// 统一取代原先分散在库页/详情页/搜索页的三套私有 tab 实现。
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
    // Keep tab text on the same 14px rhythm as the song title column. The
    // compact variant only shrinks its horizontal padding, not the type.
    const fontSize = 14.0;
    final measureStyle = AppTypography.style(fontSize, 600);
    var maxLabelWidth = 0.0;
    for (final label in tabs) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: measureStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      maxLabelWidth = math.max(maxLabelWidth, painter.width);
    }
    final segmentWidth = (maxLabelWidth + (dense ? 22 : 28)).ceilToDouble();
    final segmentHeight = dense ? 34.0 : 36.0;
    final index = selectedIndex.clamp(0, tabs.length - 1);

    return GlassSurface(
      radius: AppRadius.lg,
      tint: AppGlass.surfaceSoft,
      padding: const EdgeInsets.all(3),
      showHighlight: false,
      child: SizedBox(
        width: segmentWidth * tabs.length,
        height: segmentHeight,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              left: index * segmentWidth,
              top: 0,
              bottom: 0,
              width: segmentWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppGlass.thumb,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withValues(
                        alpha: AppColors.isDark ? 0.22 : 0.28,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  _GlassTabCell(
                    label: tabs[i],
                    width: segmentWidth,
                    fontSize: fontSize,
                    selected: i == index,
                    onTap: i == index ? null : () => onChanged(i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassTabCell extends StatefulWidget {
  const _GlassTabCell({
    required this.label,
    required this.width,
    required this.fontSize,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double width;
  final double fontSize;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_GlassTabCell> createState() => _GlassTabCellState();
}

class _GlassTabCellState extends State<_GlassTabCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? AppColors.primaryPressed
        : _hovered
        ? AppColors.text
        : AppColors.muted;
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          height: double.infinity,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              style: AppTypography.style(
                widget.fontSize,
                widget.selected ? 600 : 500,
                color: color,
              ),
              child: Text(widget.label, maxLines: 1),
            ),
          ),
        ),
      ),
    );
  }
}
