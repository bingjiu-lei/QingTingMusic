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
      width: compact ? 70 : 176,
      padding: EdgeInsets.fromLTRB(compact ? 8 : 9, 14, compact ? 8 : 9, 12),
      decoration: BoxDecoration(color: AppColors.sidebar),
      child: Column(
        children: [
          _Brand(
            compact: compact,
            isDark: isDark,
            onToggleTheme: onToggleTheme,
          ),
          const SizedBox(height: 24),
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
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
                      cacheWidth: 126,
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
          Flexible(
            child: Text(
              '晴听音乐',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                17,
                800,
                color: AppColors.text,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _NavigationItem extends StatefulWidget {
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
  State<_NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<_NavigationItem> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final pillRadius = BorderRadius.circular(AppRadius.lg);
    final selected = widget.selected;
    final compact = widget.compact;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: compact ? widget.label : '',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
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
                  ? 1.01
                  : 1.0,
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.curve,
                height: 46,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: isDark ? 0.20 : 0.10)
                      : _hovered
                      ? AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.05)
                      : Colors.transparent,
                  borderRadius: pillRadius,
                  border: Border.all(
                    color: selected
                        ? AppColors.primary.withValues(alpha: isDark ? 0.38 : 0.22)
                        : _hovered
                        ? AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.10)
                        : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                              alpha: isDark ? 0.16 : 0.08,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: compact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    if (!compact) const SizedBox(width: 14),
                    Icon(
                      widget.icon,
                      size: 20,
                      color: selected
                          ? AppColors.primary
                          : _hovered
                          ? AppColors.text
                          : AppColors.muted,
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 12),
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          14,
                          selected ? 700 : 600,
                          color: selected
                              ? AppColors.primaryPressed
                              : AppColors.text,
                          letterSpacing: selected ? 0.2 : 0,
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 54,
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
                        style: AppTypography.style(
                          12,
                          700,
                          color: AppColors.text,
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
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Tooltip(
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
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.16),
            ),
          ),
          child: avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  cacheWidth: (38 * pixelRatio).round(),
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => _AvatarFallback(label: label),
                )
              : _AvatarFallback(label: label),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      label.trim().isEmpty ? '听' : label.trim().characters.first,
      style: AppTypography.style(14, 860, color: AppColors.primaryPressed),
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
