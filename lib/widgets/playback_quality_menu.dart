import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/playback_quality_controller.dart';
import '../controllers/player_controller.dart';
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
              EdgeInsets.symmetric(horizontal: 5, vertical: 5),
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
              QualityMenuItem(
                selected: isCloudSourceSelected,
                onPressed: () => playerController?.preferCloudSource(),
                leading: QualityBadge(
                  label: 'CLD',
                  selected: isCloudSourceSelected,
                ),
                title: '云盘文件',
              ),
            if (isCloudSong && qualities.isNotEmpty) const SizedBox(height: 3),
            ...qualities.map((quality) {
              final selected =
                  !isCloudSourceSelected && controller.quality == quality;
              return QualityMenuItem(
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
                leading: QualityBadge(label: quality.badge, selected: selected),
                title: quality.title,
              );
            }),
            if (qualities.isEmpty &&
                (!isCloudSong || hasLinkedCatalog) &&
                !controller.availabilityChecked)
              const QualityMenuItem(
                onPressed: null,
                leading: QualityBadge(label: '…'),
                title: '正在检测音质',
              ),
            if (qualities.isEmpty &&
                (!isCloudSong || hasLinkedCatalog) &&
                controller.availabilityChecked)
              const QualityMenuItem(
                onPressed: null,
                leading: QualityBadge(label: '—'),
                title: '暂无可用音质',
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
}

class QualityMenuItem extends StatefulWidget {
  const QualityMenuItem({
    super.key,
    required this.leading,
    required this.title,
    required this.onPressed,
    this.selected = false,
    this.width = 148,
  });

  final Widget leading;
  final String title;
  final VoidCallback? onPressed;
  final bool selected;
  final double width;

  @override
  State<QualityMenuItem> createState() => _QualityMenuItemState();
}

class _QualityMenuItemState extends State<QualityMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                widget.onPressed?.call();
                Actions.maybeInvoke(context, const DismissIntent());
              }
            : null,
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.selected
                : (_hovered && enabled
                      ? AppColors.surfaceHover
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.leading,
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: widget.selected
                        ? AppColors.primary
                        : (enabled ? AppColors.text : AppColors.muted),
                    fontSize: 12.5,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QualityBadge extends StatelessWidget {
  const QualityBadge({super.key, required this.label, this.selected = false});

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
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.muted.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Center(
          child: selected
              ? Icon(Icons.check_rounded, size: 15, color: AppColors.primary)
              : Text(
                  label,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: label.length > 2 ? 8.5 : 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
