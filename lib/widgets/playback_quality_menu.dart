import 'package:flutter/material.dart';

import '../controllers/playback_quality_controller.dart';
import '../theme/app_theme.dart';

class PlaybackQualityMenu extends StatelessWidget {
  const PlaybackQualityMenu({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final PlaybackQualityController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MenuAnchor(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(AppColors.surface),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(color: AppColors.border),
              ),
            ),
            elevation: const WidgetStatePropertyAll(5),
          ),
          menuChildren: PlaybackQuality.values
              .map(
                (quality) => MenuItemButton(
                  onPressed: () => controller.select(quality),
                  child: SizedBox(
                    width: 126,
                    child: Row(
                      children: [
                        Icon(
                          quality == controller.quality
                              ? Icons.check_rounded
                              : Icons.high_quality_rounded,
                          size: 18,
                          color: quality == controller.quality
                              ? AppColors.primary
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          quality == PlaybackQuality.standard
                              ? '标准音质'
                              : '${quality.label} 音质',
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
          builder: (context, menuController, _) {
            return Tooltip(
              message: '播放音质：${controller.quality.label}',
              child: Material(
                color: Colors.transparent,
                shape: const StadiumBorder(),
                child: InkWell(
                  onTap: () => menuController.isOpen
                      ? menuController.close()
                      : menuController.open(),
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(999),
                  hoverColor: AppColors.primary.withValues(alpha: 0.08),
                  child: Container(
                    height: compact ? 32 : 36,
                    padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted.withValues(
                        alpha: AppColors.isDark ? 0.42 : 0.76,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      controller.quality.label,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
