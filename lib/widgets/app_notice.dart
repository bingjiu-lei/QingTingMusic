import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'preparing_dots.dart';

enum AppNoticeKind { loading, info, success, error }

class AppNoticeData {
  const AppNoticeData({
    required this.id,
    required this.message,
    required this.kind,
  });

  final int id;
  final String message;
  final AppNoticeKind kind;
}

/// Shared visual language for transient async, success, and error feedback.
class AppNoticeCard extends StatelessWidget {
  const AppNoticeCard({
    super.key,
    required this.message,
    required this.kind,
    this.minWidth = 220,
    this.maxWidth = 360,
  });

  final String message;
  final AppNoticeKind kind;
  final double minWidth;
  final double maxWidth;

  Color get _accent => switch (kind) {
    AppNoticeKind.loading => AppColors.primary,
    AppNoticeKind.info => AppColors.primary,
    AppNoticeKind.success => const Color(0xFF39A879),
    AppNoticeKind.error => AppColors.danger,
  };

  IconData get _icon => switch (kind) {
    AppNoticeKind.loading => Icons.more_horiz_rounded,
    AppNoticeKind.info => Icons.info_outline_rounded,
    AppNoticeKind.success => Icons.check_circle_outline_rounded,
    AppNoticeKind.error => Icons.error_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppGlass.surfaceStrong,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: _accent.withValues(alpha: 0.20)),
          boxShadow: AppShadows.popover,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: kind == AppNoticeKind.loading
                    ? PreparingDots(color: _accent)
                    : Icon(_icon, size: 19, color: _accent),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppNoticeHost extends StatelessWidget {
  const AppNoticeHost({super.key, this.notice});

  final AppNoticeData? notice;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 54,
      right: 18,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: AppMotion.normal,
          switchInCurve: AppMotion.curve,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: notice == null
              ? const SizedBox.shrink(key: ValueKey('notice-hidden'))
              : AppNoticeCard(
                  key: ValueKey(notice!.id),
                  message: notice!.message,
                  kind: notice!.kind,
                ),
        ),
      ),
    );
  }
}
