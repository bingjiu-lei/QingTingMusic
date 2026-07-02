import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'song_row.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.controller,
    this.onQueuePressed,
    this.onNowPlayingPressed,
    this.onOpenAlbum,
    this.onLike,
    this.onAddToPlaylist,
  });

  final PlayerController controller;
  final VoidCallback? onQueuePressed;
  final VoidCallback? onNowPlayingPressed;
  final ValueChanged<Song>? onOpenAlbum;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;

  @override
  Widget build(BuildContext context) {
    final song = controller.currentSong;
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 22),
            child: Row(
              children: [
                MouseRegion(
                  cursor: song == null || onNowPlayingPressed == null
                      ? MouseCursor.defer
                      : SystemMouseCursors.click,
                  child: Tooltip(
                    message: song == null ? '' : '打开播放页',
                    child: GestureDetector(
                      onTap: song == null ? null : onNowPlayingPressed,
                      child: AlbumArt(
                        size: 58,
                        emphasized: song != null,
                        imageUrl: song?.coverUrl,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: compact ? 120 : 190,
                  child: song == null
                      ? Text(
                          '选择一首歌开始播放',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              controller.errorText ??
                                  controller.playbackNotice ??
                                  (controller.isPreparing
                                      ? '正在准备播放'
                                      : song.artist),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: controller.errorText != null
                                    ? AppColors.danger
                                    : controller.playbackNotice != null
                                    ? AppColors.primary
                                    : AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
                if (song != null && !compact) ...[
                  IconButton(
                    tooltip: song.liked ? '取消收藏' : '收藏',
                    onPressed: onLike == null ? null : () => onLike!(song),
                    icon: Icon(
                      song.liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: song.liked ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                  IconButton(
                    tooltip: '添加到歌单',
                    onPressed: onAddToPlaylist == null
                        ? null
                        : () => onAddToPlaylist!(song),
                    icon: const Icon(Icons.playlist_add_rounded),
                  ),
                  IconButton(
                    tooltip: '打开专辑',
                    onPressed: _hasAlbum(song) && onOpenAlbum != null
                        ? () => onOpenAlbum!(song)
                        : null,
                    icon: const Icon(Icons.album_rounded),
                  ),
                ],
                IconButton(
                  tooltip: controller.playbackMode.label,
                  onPressed: controller.cyclePlaybackMode,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(38, 38),
                    iconSize: 21,
                  ),
                  icon: Icon(_modeIcon(controller.playbackMode)),
                ),
                IconButton(
                  tooltip: '上一首',
                  onPressed: song == null ? null : controller.playPrevious,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(42, 42),
                    iconSize: 24,
                  ),
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                FilledButton(
                  onPressed: song == null || controller.isPreparing
                      ? null
                      : controller.togglePlay,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.5,
                    ),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                    elevation: 0,
                  ),
                  child: controller.isPreparing
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          controller.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 28,
                        ),
                ),
                IconButton(
                  tooltip: '下一首',
                  onPressed: song == null ? null : () => controller.playNext(),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(42, 42),
                    iconSize: 24,
                  ),
                  icon: const Icon(Icons.skip_next_rounded),
                ),
                SizedBox(width: compact ? 8 : 18),
                Text(
                  formatDuration(controller.position),
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(child: _BufferedProgress(controller: controller)),
                const SizedBox(width: 8),
                Text(
                  formatDuration(
                    controller.duration == Duration.zero && song != null
                        ? song.duration
                        : controller.duration,
                  ),
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  _HoverVolumeControl(
                    volume: controller.volume,
                    onChanged: controller.setVolume,
                  ),
                  IconButton(
                    tooltip: '播放队列',
                    onPressed: onQueuePressed,
                    icon: const Icon(Icons.queue_music_rounded),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _modeIcon(PlaybackMode mode) {
    return switch (mode) {
      PlaybackMode.sequence => Icons.format_list_numbered_rounded,
      PlaybackMode.repeatAll => Icons.repeat_rounded,
      PlaybackMode.repeatOne => Icons.repeat_one_rounded,
      PlaybackMode.shuffle => Icons.shuffle_rounded,
    };
  }

  bool _hasAlbum(Song song) {
    final album = song.album.trim();
    return album.isNotEmpty && album != '未知专辑';
  }
}

class _HoverVolumeControl extends StatefulWidget {
  const _HoverVolumeControl({required this.volume, required this.onChanged});

  final double volume;
  final ValueChanged<double> onChanged;

  @override
  State<_HoverVolumeControl> createState() => _HoverVolumeControlState();
}

class _HoverVolumeControlState extends State<_HoverVolumeControl> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;
  bool _anchorHovered = false;
  bool _panelHovered = false;

  @override
  void didUpdateWidget(covariant _HoverVolumeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volume != widget.volume) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    _hideTimer?.cancel();
    if (_overlayEntry != null) {
      _overlayEntry?.markNeedsBuild();
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0, -10),
          child: UnconstrainedBox(
            alignment: Alignment.bottomCenter,
            child: Material(
              type: MaterialType.transparency,
              child: MouseRegion(
                cursor: SystemMouseCursors.basic,
                onEnter: (_) {
                  _panelHovered = true;
                  _hideTimer?.cancel();
                },
                onExit: (_) {
                  _panelHovered = false;
                  _scheduleHide();
                },
                child: _VolumePopover(
                  volume: widget.volume,
                  onChanged: (value) {
                    widget.onChanged(value);
                    _overlayEntry?.markNeedsBuild();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 320), () {
      if (!_anchorHovered && !_panelHovered) {
        _removeOverlay();
      }
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          _anchorHovered = true;
          _showOverlay();
        },
        onExit: (_) {
          _anchorHovered = false;
          _scheduleHide();
        },
        child: SizedBox(
          width: 36,
          height: 42,
          child: Icon(
            widget.volume <= 0.01
                ? Icons.volume_off_rounded
                : widget.volume < 0.45
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded,
            color: AppColors.muted,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _VolumePopover extends StatelessWidget {
  const _VolumePopover({required this.volume, required this.onChanged});

  final double volume;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (volume.clamp(0.0, 1.0) * 100).round();
    return SizedBox(
      width: 54,
      height: 166,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Column(
            children: [
              Text(
                '$percent',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Center(
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: SizedBox(
                      width: 112,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: AppColors.divider,
                          thumbColor: AppColors.surface,
                          overlayColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 15,
                          ),
                          trackShape: const _EdgeToEdgeSliderTrackShape(),
                        ),
                        child: Slider(
                          value: volume.clamp(0.0, 1.0),
                          onChanged: onChanged,
                        ),
                      ),
                    ),
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

class _BufferedProgress extends StatelessWidget {
  const _BufferedProgress({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final played = _ratio(controller.position);
    final buffered = _ratio(controller.bufferedPosition);
    return SizedBox(
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: buffered,
              color: AppColors.primary.withValues(alpha: 0.22),
              backgroundColor: AppColors.divider,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.transparent,
              thumbColor: AppColors.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
              trackShape: const _EdgeToEdgeSliderTrackShape(),
            ),
            child: Slider(
              value: played,
              onChanged: controller.currentSong == null
                  ? null
                  : controller.seekByRatio,
            ),
          ),
        ],
      ),
    );
  }

  double _ratio(Duration value) {
    if (controller.duration.inMilliseconds <= 0) return 0;
    return (value.inMilliseconds / controller.duration.inMilliseconds).clamp(
      0,
      1,
    );
  }
}

class _EdgeToEdgeSliderTrackShape extends RoundedRectSliderTrackShape {
  const _EdgeToEdgeSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 0;
    final top = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(offset.dx, top, parentBox.size.width, trackHeight);
  }
}
