import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_icon_button.dart';

/// 统一的弹窗外壳与美化组件，包含背景柔和光晕、通透玻璃质感、圆润倒角与统一的操作按钮体系。
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    required this.title,
    this.subtitle,
    required this.content,
    this.actions,
    this.maxWidth = 420,
    this.maxHeight,
    this.showCloseButton = false,
    this.onClose,
  });

  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final String title;
  final String? subtitle;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final double? maxHeight;
  final bool showCloseButton;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight ?? double.infinity,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF161B22).withValues(alpha: 0.96)
              : Colors.white.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.border,
            width: 1,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 36,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, -2),
                  ),
                ]
              : AppShadows.popover,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          child: Stack(
            children: [
              // Subtle ambient glow at top
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: isDark ? 0.10 : 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: iconBackgroundColor ??
                                  AppColors.primary.withValues(
                                    alpha: isDark ? 0.14 : 0.08,
                                  ),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: (iconColor ?? AppColors.primary)
                                    .withValues(alpha: 0.18),
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: iconColor ?? AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 13),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              if (subtitle != null &&
                                  subtitle!.trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subtitle!,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (showCloseButton)
                          AppIconButton.ghost(
                            tooltip: '关闭',
                            icon: Icons.close_rounded,
                            size: 32,
                            iconSize: 18,
                            onPressed: onClose ?? () => Navigator.of(context).pop(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Body content
                    content,
                    // Action buttons
                    if (actions != null && actions!.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 统一的弹窗按钮（支持 Primary 主色、Danger 危险红、Ghost 幽灵灰）
class AppDialogButton extends StatefulWidget {
  const AppDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDanger = false,
    this.icon,
  });

  const AppDialogButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  })  : isPrimary = true,
        isDanger = false;

  const AppDialogButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  })  : isPrimary = false,
        isDanger = true;

  const AppDialogButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  })  : isPrimary = false,
        isDanger = false;

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDanger;
  final IconData? icon;

  @override
  State<AppDialogButton> createState() => _AppDialogButtonState();
}

class _AppDialogButtonState extends State<AppDialogButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final enabled = widget.onPressed != null;

    Color bg;
    Color fg;
    Color borderColor;
    List<BoxShadow>? shadow;

    if (widget.isPrimary) {
      bg = enabled
          ? (_hovered
              ? AppColors.primaryPressed
              : AppColors.primary)
          : AppColors.primary.withValues(alpha: 0.4);
      fg = Colors.white;
      borderColor = Colors.transparent;
      shadow = (_hovered && enabled)
          ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null;
    } else if (widget.isDanger) {
      bg = enabled
          ? (_hovered
              ? AppColors.danger.withValues(alpha: 0.9)
              : AppColors.danger)
          : AppColors.danger.withValues(alpha: 0.4);
      fg = Colors.white;
      borderColor = Colors.transparent;
      shadow = (_hovered && enabled)
          ? [
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.32),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null;
    } else {
      bg = _hovered
          ? (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05))
          : Colors.transparent;
      fg = _hovered ? AppColors.text : AppColors.muted;
      borderColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08);
      shadow = null;
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
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
          scale: _pressed
              ? 0.96
              : _hovered
                  ? 1.02
                  : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutQuad,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOutQuad,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: borderColor),
              boxShadow: shadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: widget.isPrimary || widget.isDanger
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 统一的美化输入框组件（支持聚焦微光、清空按钮、前缀图标）
class AppDialogTextField extends StatelessWidget {
  const AppDialogTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLength,
    this.prefixIcon,
    this.errorText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hintText;
  final bool autofocus;
  final bool obscureText;
  final int? maxLength;
  final IconData? prefixIcon;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: obscureText,
      maxLength: maxLength,
      style: TextStyle(
        color: AppColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppColors.muted.withValues(alpha: 0.7),
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
        ),
        errorText: errorText,
        counterText: '',
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                size: 18,
                color: AppColors.muted,
              )
            : null,
        filled: true,
        fillColor: isDark
            ? const Color(0xFF1C222B)
            : const Color(0xFFF3F6FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: AppColors.danger,
            width: 1.5,
          ),
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

/// 统一的弹窗开关选项条
class AppDialogSwitchTile extends StatelessWidget {
  const AppDialogSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Material(
      color: isDark
          ? const Color(0xFF1C222B)
          : const Color(0xFFF3F6FA),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadius.md),
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: value ? AppColors.primary : AppColors.muted,
                  ),
                ),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppColors.primary,
                inactiveThumbColor: isDark
                    ? const Color(0xFF8B949E)
                    : const Color(0xFF6E7781),
                inactiveTrackColor: isDark
                    ? const Color(0xFF2E3642)
                    : const Color(0xFFD0D7DE),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 标准确认/危险确认通用弹窗
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.icon,
    this.isDanger = false,
    this.cancelLabel = '取消',
    this.confirmLabel = '确认',
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final String content;
  final IconData? icon;
  final bool isDanger;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      icon: icon ??
          (isDanger
              ? Icons.delete_outline_rounded
              : Icons.help_outline_rounded),
      iconColor: isDanger ? AppColors.danger : AppColors.primary,
      iconBackgroundColor: (isDanger ? AppColors.danger : AppColors.primary)
          .withValues(alpha: AppColors.isDark ? 0.14 : 0.08),
      title: title,
      content: Text(
        content,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 13.5,
          height: 1.55,
        ),
      ),
      actions: [
        AppDialogButton.ghost(
          label: cancelLabel,
          onPressed: onCancel,
        ),
        const SizedBox(width: 8),
        isDanger
            ? AppDialogButton.danger(
                label: confirmLabel,
                onPressed: onConfirm,
              )
            : AppDialogButton.primary(
                label: confirmLabel,
                onPressed: onConfirm,
              ),
      ],
    );
  }
}
