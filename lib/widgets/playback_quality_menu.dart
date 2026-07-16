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
                    width: 174,
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_qualityTitle(quality)),
                              const SizedBox(height: 2),
                              Text(
                                _qualityDescription(quality),
                                style: TextStyle(
                                  color: AppColors.faint,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
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
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => menuController.isOpen
                      ? menuController.close()
                      : menuController.open(),
                  mouseCursor: SystemMouseCursors.click,
                  customBorder: const CircleBorder(),
                  hoverColor: AppColors.primary.withValues(alpha: 0.08),
                  child: Container(
                    width: compact ? 38 : 42,
                    height: compact ? 38 : 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: controller.quality == PlaybackQuality.standard
                          ? Colors.transparent
                          : AppColors.selected,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.graphic_eq_rounded,
                          size: 20,
                          color: controller.quality == PlaybackQuality.standard
                              ? AppColors.muted
                              : AppColors.primary,
                        ),
                        if (controller.quality != PlaybackQuality.standard)
                          Positioned(
                            right: 5,
                            bottom: 5,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.playerSurface,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                      ],
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

  String _qualityTitle(PlaybackQuality quality) => switch (quality) {
    PlaybackQuality.standard => '标准音质',
    PlaybackQuality.high => 'HQ 高品质',
    PlaybackQuality.lossless => '无损音质',
  };

  String _qualityDescription(PlaybackQuality quality) => switch (quality) {
    PlaybackQuality.standard => '流量更省，播放更稳定',
    PlaybackQuality.high => '更丰富的声音细节',
    PlaybackQuality.lossless => '优先播放 FLAC 无损资源',
  };
}
