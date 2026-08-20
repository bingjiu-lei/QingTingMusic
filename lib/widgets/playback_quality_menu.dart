import 'package:flutter/material.dart';

import '../controllers/playback_quality_controller.dart';
import '../theme/app_theme.dart';
import 'app_icon_button.dart';

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
            final isNotStandard =
                controller.quality != PlaybackQuality.standard;
            return AppIconButton.ghost(
              tooltip: '播放音质：${controller.quality.label}',
              onPressed: () => menuController.isOpen
                  ? menuController.close()
                  : menuController.open(),
              size: compact ? 38 : 42,
              iconSize: 20,
              selected: isNotStandard,
              selectedColor: AppColors.primary,
              selectedBackgroundColor: AppColors.selected,
              iconColor: AppColors.muted,
              hoverIconColor: AppColors.primary,
              shadowColor: AppColors.primary,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 20,
                    color: isNotStandard ? AppColors.primary : AppColors.muted,
                  ),
                  if (isNotStandard)
                    Positioned(
                      right: 4,
                      bottom: 4,
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
    PlaybackQuality.hiRes => 'Hi-Res 高解析',
  };

  String _qualityDescription(PlaybackQuality quality) => switch (quality) {
    PlaybackQuality.standard => '流量更省，播放更稳定',
    PlaybackQuality.high => '更丰富的声音细节',
    PlaybackQuality.lossless => '优先播放 FLAC 无损资源',
    PlaybackQuality.hiRes => '资源与账号支持时可用',
  };
}
