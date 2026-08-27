import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/playback_quality_controller.dart';
import '../controllers/player_controller.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'app_icon_button.dart';

class PlaybackQualityMenu extends StatelessWidget {
  const PlaybackQualityMenu({
    super.key,
    required this.controller,
    this.playerController,
    this.compact = false,
  });

  final PlaybackQualityController controller;
  final PlayerController? playerController;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final song = playerController?.currentSong;
        final isCloudSong = song?.isCloud == true;
        final hasLinkedCatalog =
            isCloudSong && song?.catalogHash?.isNotEmpty == true;
        final isCloudSourceSelected =
            isCloudSong && song?.playbackSource != 'catalog';
        final qualities = controller.availableQualities;
        final triggerLabel = isCloudSourceSelected
            ? '云盘文件'
            : controller.quality.label;

        return MenuAnchor(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(AppColors.surfaceElevated),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(color: AppColors.border),
              ),
            ),
            elevation: const WidgetStatePropertyAll(4),
          ),
          menuChildren: [
            if (isCloudSong)
              _QualityMenuItem(
                selected: isCloudSourceSelected,
                onPressed: () => playerController?.preferCloudSource(),
                leading: _QualityBadge(
                  label: 'CLD',
                  selected: isCloudSourceSelected,
                ),
                title: '云盘文件',
                description: _cloudDescription(song),
              ),
            if (isCloudSong && qualities.isNotEmpty) const SizedBox(height: 4),
            ...qualities.map((quality) {
              final selected =
                  !isCloudSourceSelected && controller.quality == quality;
              return _QualityMenuItem(
                selected: selected,
                onPressed: () {
                  final qualityChanged = controller.quality != quality;
                  final sourceChanged = isCloudSong
                      ? playerController?.preferCatalogSource(refresh: false) ??
                            false
                      : false;
                  unawaited(controller.select(quality));
                  if (sourceChanged && !qualityChanged) {
                    final player = playerController;
                    if (player != null) unawaited(player.refreshCurrentSong());
                  }
                },
                leading: _QualityBadge(
                  label: _qualityBadge(quality),
                  selected: selected,
                ),
                title: _qualityTitle(quality),
                description: _qualityDescription(quality),
              );
            }),
            if (qualities.isEmpty &&
                (!isCloudSong || hasLinkedCatalog) &&
                !controller.availabilityChecked)
              _QualityMenuItem(
                onPressed: null,
                leading: const _QualityBadge(label: '…'),
                title: '正在检测音质',
                description: hasLinkedCatalog ? '等待线上官方资源信息' : '等待官方资源信息',
              ),
            if (qualities.isEmpty &&
                (!isCloudSong || hasLinkedCatalog) &&
                controller.availabilityChecked)
              _QualityMenuItem(
                onPressed: null,
                leading: const _QualityBadge(label: '—'),
                title: '暂无可用音质',
                description: hasLinkedCatalog
                    ? '没有可播放的线上官方资源'
                    : '当前歌曲没有可播放的官方资源',
              ),
          ],
          builder: (context, menuController, _) {
            return AppIconButton.ghost(
              tooltip: '播放来源/音质：$triggerLabel',
              onPressed: () => menuController.isOpen
                  ? menuController.close()
                  : menuController.open(),
              size: compact ? 38 : 42,
              iconSize: 20,
              iconColor: AppColors.muted,
              hoverIconColor: AppColors.primary,
              shadowColor: AppColors.primary,
              child: const Icon(Icons.graphic_eq_rounded, size: 20),
            );
          },
        );
      },
    );
  }

  String _qualityBadge(PlaybackQuality quality) => switch (quality) {
    PlaybackQuality.standard => 'STD',
    PlaybackQuality.high => 'HQ',
    PlaybackQuality.lossless => 'SQ',
    PlaybackQuality.hiRes => 'HI',
  };

  String _cloudDescription(Song? song) {
    final quality = PlaybackQuality.fromRequestValue(song?.cloudQuality);
    return quality == null ? '当前歌曲的云盘资源' : '${quality.label} 云盘资源';
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

class _QualityMenuItem extends StatelessWidget {
  const _QualityMenuItem({
    required this.leading,
    required this.title,
    required this.description,
    required this.onPressed,
    this.selected = false,
  });

  final Widget leading;
  final String title;
  final String description;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        ),
        backgroundColor: WidgetStatePropertyAll(
          selected ? AppColors.selected : Colors.transparent,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      child: SizedBox(
        width: 208,
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: onPressed == null
                          ? AppColors.muted
                          : AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppColors.faint,
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.muted.withValues(alpha: 0.34),
          ),
        ),
        child: Center(
          child: selected
              ? Icon(Icons.check_rounded, size: 16, color: AppColors.primary)
              : Text(
                  label,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: label.length > 2 ? 8 : 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
