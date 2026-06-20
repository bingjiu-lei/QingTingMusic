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
    required this.onLogin,
    required this.isDark,
    required this.onToggleTheme,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool compact;
  final String loginLabel;
  final bool isLoggedIn;
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
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Brand(compact: compact),
          SizedBox(height: 32),
          for (var index = 0; index < items.length; index++)
            _NavigationItem(
              icon: items[index].$1,
              label: items[index].$2,
              compact: compact,
              selected: selectedIndex == index,
              onTap: () => onChanged(index),
            ),
          Spacer(),
          _ThemeToggle(compact: compact, isDark: isDark, onTap: onToggleTheme),
          SizedBox(height: 6),
          _LoginEntry(
            compact: compact,
            label: loginLabel,
            isLoggedIn: isLoggedIn,
            onTap: onLogin,
          ),
        ],
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({
    required this.compact,
    required this.isDark,
    required this.onTap,
  });

  final bool compact;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = isDark ? '切换浅色模式' : '切换深色模式';
    return Tooltip(
      message: compact ? label : '',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.selected.withValues(alpha: 0.55),
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (!compact) SizedBox(width: 12),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 180),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey(isDark),
                    color: AppColors.muted,
                    size: 20,
                  ),
                ),
                if (!compact) ...[
                  SizedBox(width: 12),
                  Text(
                    isDark ? '浅色模式' : '深色模式',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
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

class _LoginEntry extends StatelessWidget {
  const _LoginEntry({
    required this.compact,
    required this.label,
    required this.isLoggedIn,
    required this.onTap,
  });

  final bool compact;
  final String label;
  final bool isLoggedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: compact ? label : '',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (!compact) SizedBox(width: 12),
                Icon(
                  isLoggedIn
                      ? Icons.account_circle_rounded
                      : Icons.person_outline_rounded,
                  color: isLoggedIn ? AppColors.primary : AppColors.muted,
                  size: 20,
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
  const _Brand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: compact
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 24),
        ),
        if (!compact) ...[
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '晴听音乐',
              maxLines: 1,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
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
        child: Material(
          color: selected ? AppColors.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            hoverColor: AppColors.selected.withValues(alpha: 0.55),
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
    );
  }
}
