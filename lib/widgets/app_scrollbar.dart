import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 全局通用的现代化优雅滚轮/滚动条组件。
/// 自动通过 [ScrollConfiguration] 屏蔽系统默认的重复滚轮，彻底杜绝双滑轮现象；
/// 支持纤细胶囊跑道造型、悬停增宽以及当前主题色自适应。
class AppScrollbar extends StatelessWidget {
  const AppScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility,
    this.trackVisibility,
    this.thickness,
    this.radius,
    this.crossAxisMargin,
    this.mainAxisMargin,
    this.padding,
    this.interactive = true,
  });

  final Widget child;
  final ScrollController? controller;
  final bool? thumbVisibility;
  final bool? trackVisibility;
  final double? thickness;
  final Radius? radius;
  final double? crossAxisMargin;
  final double? mainAxisMargin;
  final EdgeInsetsGeometry? padding;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    // 强制关闭子级 ScrollView 在桌面端被系统自动注入的滚动条，确保全视图只存在一个滚动条
    final content = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: child,
    );

    Widget scrollbar = Scrollbar(
      controller: controller,
      thumbVisibility: thumbVisibility,
      trackVisibility: trackVisibility,
      interactive: interactive,
      thickness: thickness,
      radius: radius ?? const Radius.circular(AppRadius.pill),
      child: content,
    );

    if (padding != null) {
      scrollbar = Padding(padding: padding!, child: scrollbar);
    }
    return scrollbar;
  }
}
