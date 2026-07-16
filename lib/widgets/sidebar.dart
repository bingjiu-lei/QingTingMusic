import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.compact,
    required this.loginLabel,
    required this.avatarUrl,
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
  final String avatarUrl;
  final bool isLoggedIn;
  final String vipTooltip;
  final VoidCallback onLogin;
  final bool isDark;
  final VoidCallback onToggleTheme;

  static final primaryItems = [
    (Icons.library_music_rounded, '我的音乐'),
    (Icons.search_rounded, '搜索'),
    (Icons.auto_awesome_rounded, '推荐'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 76 : 204,
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 14,
        14,
        compact ? 10 : 14,
        12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.sidebar,
            Color.alphaBlend(
              AppColors.primary.withValues(
                alpha: AppColors.isDark ? 0.035 : 0.018,
              ),
              AppColors.sidebar,
            ),
          ],
        ),
      ),
      child: Column(
        children: [
          _Brand(
            compact: compact,
            isDark: isDark,
            onToggleTheme: onToggleTheme,
          ),
          const SizedBox(height: 26),
          for (var index = 0; index < primaryItems.length; index++)
            _NavigationItem(
              icon: primaryItems[index].$1,
              label: primaryItems[index].$2,
              compact: compact,
              selected: selectedIndex == index,
              onTap: () => onChanged(index),
            ),
          const Spacer(),
          _AccountDock(
            compact: compact,
            label: loginLabel,
            avatarUrl: avatarUrl,
            isLoggedIn: isLoggedIn,
            vipTooltip: vipTooltip,
            settingsSelected: selectedIndex == 3,
            onLogin: onLogin,
            onSettings: () => onChanged(3),
          ),
        ],
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: compact ? 0 : 8),
    child: SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Tooltip(
            message: isDark ? '切换到浅色模式' : '切换到深色模式',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InkWell(
                onTap: onToggleTheme,
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                hoverColor: AppColors.selected,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: AnimatedSwitcher(
                      duration: AppMotion.normal,
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
                ),
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '晴听音乐',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Tooltip(
      message: compact ? label : '',
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        decoration: BoxDecoration(
          color: selected ? AppColors.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(
                    alpha: AppColors.isDark ? 0.22 : 0.10,
                  )
                : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            hoverColor: AppColors.surfaceHover.withValues(alpha: 0.78),
            child: SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (!compact) const SizedBox(width: 14),
                  SizedBox(
                    width: 24,
                    child: Icon(
                      icon,
                      size: 21,
                      color: selected ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primaryPressed
                            : AppColors.text,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
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

class _AccountDock extends StatelessWidget {
  const _AccountDock({
    required this.compact,
    required this.label,
    required this.avatarUrl,
    required this.isLoggedIn,
    required this.vipTooltip,
    required this.settingsSelected,
    required this.onLogin,
    required this.onSettings,
  });

  final bool compact;
  final String label;
  final String avatarUrl;
  final bool isLoggedIn;
  final String vipTooltip;
  final bool settingsSelected;
  final VoidCallback onLogin;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          _Avatar(
            label: label,
            avatarUrl: avatarUrl,
            isLoggedIn: isLoggedIn,
            onTap: onLogin,
          ),
          const SizedBox(height: 8),
          _DockIcon(
            tooltip: '设置',
            icon: Icons.settings_rounded,
            selected: settingsSelected,
            onPressed: onSettings,
          ),
        ],
      );
    }

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(
          alpha: AppColors.isDark ? 0.48 : 0.72,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          _Avatar(
            label: label,
            avatarUrl: avatarUrl,
            isLoggedIn: isLoggedIn,
            onTap: onLogin,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Tooltip(
              message: isLoggedIn ? '$label\n$vipTooltip' : '登录晴听音乐',
              child: InkWell(
                onTap: onLogin,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _DockIcon(
            tooltip: '设置',
            icon: Icons.settings_rounded,
            selected: settingsSelected,
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.label,
    required this.avatarUrl,
    required this.isLoggedIn,
    required this.onTap,
  });

  final String label;
  final String avatarUrl;
  final bool isLoggedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: isLoggedIn ? '账户' : '登录',
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.selected,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
        ),
        child: avatarUrl.isNotEmpty
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _AvatarFallback(label: label),
              )
            : _AvatarFallback(label: label),
      ),
    ),
  );
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      label.trim().isEmpty ? '听' : label.trim().characters.first,
      style: TextStyle(
        color: AppColors.primaryPressed,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    style: IconButton.styleFrom(
      minimumSize: const Size(36, 36),
      fixedSize: const Size(36, 36),
      foregroundColor: selected ? AppColors.primary : AppColors.muted,
      backgroundColor: selected ? AppColors.selected : Colors.transparent,
      hoverColor: AppColors.selected,
      shape: const CircleBorder(),
    ),
  );
}
