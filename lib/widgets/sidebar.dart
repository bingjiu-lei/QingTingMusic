import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.compact,
    required this.loginLabel,
    required this.isLoggedIn,
    required this.vipTooltip,
    required this.onLogin,
    required this.isDark,
    required this.onToggleTheme,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool compact;
  final String loginLabel;
  final bool isLoggedIn;
  final String vipTooltip;
  final VoidCallback onLogin;
  final bool isDark;
  final VoidCallback onToggleTheme;

  static final items = [
    (Icons.library_music_rounded, '我的音乐'),
    (Icons.search_rounded, '搜索'),
    (Icons.settings_rounded, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 76 : 214,
      color: AppColors.sidebar,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 18,
        vertical: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Brand(
            compact: compact,
            isDark: isDark,
            onToggleTheme: onToggleTheme,
          ),
          SizedBox(height: 24),
          for (var index = 0; index < items.length; index++)
            _NavigationItem(
              icon: items[index].$1,
              label: items[index].$2,
              compact: compact,
              selected: selectedIndex == index,
              onTap: () => onChanged(index),
            ),
          Spacer(),
          _LoginEntry(
            compact: compact,
            label: loginLabel,
            isLoggedIn: isLoggedIn,
            vipTooltip: vipTooltip,
            onTap: onLogin,
          ),
        ],
      ),
    );
  }
}

class _LoginEntry extends StatelessWidget {
  const _LoginEntry({
    required this.compact,
    required this.label,
    required this.isLoggedIn,
    required this.vipTooltip,
    required this.onTap,
  });

  final bool compact;
  final String label;
  final bool isLoggedIn;
  final String vipTooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tooltip = isLoggedIn ? '$label\n$vipTooltip' : '登录晴听音乐';
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          hoverColor: AppColors.surfaceHover,
          mouseCursor: SystemMouseCursors.click,
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (!compact) SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isLoggedIn
                        ? AppColors.selected
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    isLoggedIn
                        ? Icons.diamond_rounded
                        : Icons.person_outline_rounded,
                    color: isLoggedIn ? AppColors.primary : AppColors.muted,
                    size: isLoggedIn ? 16 : 18,
                  ),
                ),
                if (!compact) ...[
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isLoggedIn ? AppColors.text : AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({
    required this.compact,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool compact;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final tooltip = isDark ? '切换浅色模式' : '切换深色模式';
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: onToggleTheme,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            hoverColor: AppColors.surfaceHover,
            highlightColor: AppColors.surfacePressed,
            mouseCursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 46,
              padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 4),
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final scale = Tween<double>(
                          begin: 0.96,
                          end: 1,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(scale: scale, child: child),
                        );
                      },
                      child: Image.asset(
                        isDark
                            ? 'assets/images/app_icon_dark.png'
                            : 'assets/images/app_icon_light.png',
                        key: ValueKey(isDark),
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        child: const Text('晴听音乐'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: compact ? label : '',
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          decoration: BoxDecoration(
            color: selected ? AppColors.selected : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              hoverColor: AppColors.surfaceHover,
              mouseCursor: SystemMouseCursors.click,
              child: SizedBox(
                height: 46,
                child: Row(
                  mainAxisAlignment: compact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    if (!compact) SizedBox(width: 12),
                    Icon(
                      icon,
                      size: 21,
                      color: selected ? AppColors.primary : AppColors.muted,
                    ),
                    if (!compact) ...[
                      SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          color: selected ? AppColors.primary : AppColors.text,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
