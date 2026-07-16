import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/playback_quality_controller.dart';
import '../controllers/player_controller.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'playback_progress.dart';
import 'playback_quality_menu.dart';
import 'song_row.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.controller,
    required this.playbackQualityController,
    this.onQueuePressed,
    this.onNowPlayingPressed,
    this.onOpenAlbum,
    this.onOpenArtist,
    this.onLike,
    this.onAddToPlaylist,
  });

  final PlayerController controller;
  final PlaybackQualityController playbackQualityController;
  final VoidCallback? onQueuePressed;
  final VoidCallback? onNowPlayingPressed;
  final ValueChanged<Song>? onOpenAlbum;
  final ValueChanged<Song>? onOpenArtist;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final song = controller.currentSong;
      final duration = controller.duration == Duration.zero && song != null
          ? song.duration
          : controller.duration;
      return Container(
        height: 92,
        decoration: BoxDecoration(
          color: AppColors.playerSurface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.42),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 18,
              top: 0,
              right: 18,
              child: PlaybackProgress(
                position: controller.position,
                bufferedPosition: controller.bufferedPosition,
                duration: duration,
                onSeek: controller.seekByRatio,
                compact: true,
              ),
            ),
            Positioned.fill(
              top: 13,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1080;
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 14 : 22,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _TrackSection(
                            song: song,
                            compact: compact,
                            onNowPlayingPressed: onNowPlayingPressed,
                            onOpenArtist: onOpenArtist,
                            onOpenAlbum: onOpenAlbum,
                            onLike: onLike,
                            onAddToPlaylist: onAddToPlaylist,
                            playbackMode: controller.playbackMode,
                            onCyclePlaybackMode: controller.cyclePlaybackMode,
                            subtitle:
                                controller.errorText ??
                                controller.playbackNotice ??
                                (controller.isPreparing
                                    ? '正在准备播放'
                                    : song?.artist ?? ''),
                            subtitleColor: controller.errorText != null
                                ? AppColors.danger
                                : controller.playbackNotice != null
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: _TransportSection(
                            controller: controller,
                            song: song,
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: _ToolSection(
                            song: song,
                            onOpenAlbum: onOpenAlbum,
                            volume: controller.volume,
                            onVolumeChanged: controller.setVolume,
                            qualityController: playbackQualityController,
                            onQueuePressed: onQueuePressed,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _TrackSection extends StatelessWidget {
  const _TrackSection({
    required this.song,
    required this.compact,
    required this.onNowPlayingPressed,
    required this.onOpenArtist,
    required this.onOpenAlbum,
    required this.onLike,
    required this.onAddToPlaylist,
    required this.playbackMode,
    required this.onCyclePlaybackMode,
    required this.subtitle,
    required this.subtitleColor,
  });

  final Song? song;
  final bool compact;
  final VoidCallback? onNowPlayingPressed;
  final ValueChanged<Song>? onOpenArtist;
  final ValueChanged<Song>? onOpenAlbum;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final PlaybackMode playbackMode;
  final VoidCallback onCyclePlaybackMode;
  final String subtitle;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MouseRegion(
          cursor: song == null || onNowPlayingPressed == null
              ? MouseCursor.defer
              : SystemMouseCursors.click,
          child: Tooltip(
            message: song == null ? '' : '打开播放页',
            child: GestureDetector(
              onTap: song == null ? null : onNowPlayingPressed,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: song == null ? null : AppShadows.card,
                ),
                child: AlbumArt(
                  size: compact ? 52 : 58,
                  emphasized: song != null,
                  imageUrl: song?.coverUrl,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: song == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '让音乐从这里开始',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '选择歌曲或开启私人 FM',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (subtitle == song!.artist)
                      SongArtistLine(
                        song: song!,
                        onArtistLink: onOpenArtist == null
                            ? null
                            : (artist) => onOpenArtist!(
                                song!.copyWith(
                                  artist: artist.name,
                                  artistId: artist.id,
                                  artists: [artist],
                                ),
                              ),
                      )
                    else
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
        ),
        if (song != null) ...[
          _ControlIconButton(
            tooltip: song!.liked ? '取消收藏' : '收藏',
            onPressed: onLike == null ? null : () => onLike!(song!),
            icon: song!.liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            selected: song!.liked,
            selectedColor: AppColors.favorite,
            selectedBackgroundColor: Colors.transparent,
          ),
          _ControlIconButton(
            tooltip: '添加到歌单',
            onPressed: onAddToPlaylist == null
                ? null
                : () => onAddToPlaylist!(song!),
            icon: Icons.playlist_add_rounded,
            size: 38,
          ),
          _ControlIconButton(
            tooltip: playbackMode.label,
            onPressed: onCyclePlaybackMode,
            icon: _playbackModeIcon(playbackMode),
            size: 38,
          ),
        ],
      ],
    );
  }
}

class _TransportSection extends StatelessWidget {
  const _TransportSection({required this.controller, required this.song});

  final PlayerController controller;
  final Song? song;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _ControlIconButton(
        tooltip: '上一首',
        onPressed: song == null ? null : controller.playPrevious,
        icon: Icons.skip_previous_rounded,
        iconSize: 25,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: _PrimaryPlayButton(
          isPlaying: controller.isPlaying,
          preparing: controller.isPreparing,
          enabled: song != null,
          onPressed: controller.togglePlay,
        ),
      ),
      _ControlIconButton(
        tooltip: '下一首',
        onPressed: song == null ? null : () => controller.playNext(),
        icon: Icons.skip_next_rounded,
        iconSize: 25,
      ),
    ],
  );
}

class _ToolSection extends StatelessWidget {
  const _ToolSection({
    required this.song,
    required this.onOpenAlbum,
    required this.volume,
    required this.onVolumeChanged,
    required this.qualityController,
    required this.onQueuePressed,
  });

  final Song? song;
  final ValueChanged<Song>? onOpenAlbum;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final PlaybackQualityController qualityController;
  final VoidCallback? onQueuePressed;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      if (song != null && _hasPlayableAlbum(song!))
        _ControlIconButton(
          tooltip: '打开专辑',
          onPressed: onOpenAlbum == null ? null : () => onOpenAlbum!(song!),
          icon: Icons.album_outlined,
        ),
      PlaybackQualityMenu(controller: qualityController, compact: true),
      const SizedBox(width: 4),
      _HoverVolumeControl(volume: volume, onChanged: onVolumeChanged),
      _ControlIconButton(
        tooltip: '播放队列',
        onPressed: onQueuePressed,
        icon: Icons.queue_music_rounded,
      ),
    ],
  );
}

bool _hasPlayableAlbum(Song song) {
  final album = song.album.trim();
  return album.isNotEmpty && album != '未知专辑';
}

IconData _playbackModeIcon(PlaybackMode mode) => switch (mode) {
  PlaybackMode.sequence => Icons.format_list_numbered_rounded,
  PlaybackMode.repeatAll => Icons.repeat_rounded,
  PlaybackMode.repeatOne => Icons.repeat_one_rounded,
  PlaybackMode.shuffle => Icons.shuffle_rounded,
};

class _PrimaryPlayButton extends StatelessWidget {
  const _PrimaryPlayButton({
    required this.isPlaying,
    required this.preparing,
    required this.enabled,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool preparing;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: isPlaying ? '暂停' : '播放',
    child: Tooltip(
      message: preparing
          ? '正在准备'
          : isPlaying
          ? '暂停'
          : '播放',
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? AppColors.selected : AppColors.surfaceMuted,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: !enabled || preparing ? null : onPressed,
            customBorder: const CircleBorder(),
            mouseCursor: enabled && !preparing
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Center(
              child: preparing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: enabled ? AppColors.primary : AppColors.faint,
                      size: 27,
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.iconSize = 21,
    this.selected = false,
    this.size = 42,
    this.selectedColor,
    this.selectedBackgroundColor,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final double iconSize;
  final bool selected;
  final double size;
  final Color? selectedColor;
  final Color? selectedBackgroundColor;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    mouseCursor: onPressed == null
        ? SystemMouseCursors.basic
        : SystemMouseCursors.click,
    icon: Icon(icon, size: iconSize),
    style: IconButton.styleFrom(
      minimumSize: Size(size, size),
      fixedSize: Size(size, size),
      foregroundColor: selected
          ? selectedColor ?? AppColors.primary
          : AppColors.muted,
      disabledForegroundColor: AppColors.faint.withValues(alpha: 0.42),
      backgroundColor: selected
          ? selectedBackgroundColor ?? AppColors.selected
          : Colors.transparent,
      hoverColor: AppColors.selected,
      highlightColor: AppColors.surfacePressed,
      shape: const CircleBorder(),
    ),
  );
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
  Timer? _showTimer;
  Timer? _hideTimer;
  bool _anchorHovered = false;
  bool _panelHovered = false;
  double _lastAudibleVolume = 0.78;

  @override
  void didUpdateWidget(covariant _HoverVolumeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.volume > 0.01) _lastAudibleVolume = widget.volume;
    if (oldWidget.volume != widget.volume) _overlayEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_overlayEntry != null) {
      _overlayEntry?.markNeedsBuild();
      return;
    }
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 210,
        height: 54,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topRight,
          followerAnchor: Alignment.bottomRight,
          offset: const Offset(0, -8),
          child: Material(
            type: MaterialType.transparency,
            child: MouseRegion(
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
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _scheduleShow() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 160), () {
      if (_anchorHovered || _panelHovered) _showOverlay();
    });
  }

  void _scheduleHide() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 320), () {
      if (!_anchorHovered && !_panelHovered) _removeOverlay();
    });
  }

  void _removeOverlay() {
    _showTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleMute() {
    _removeOverlay();
    if (widget.volume <= 0.01) {
      widget.onChanged(_lastAudibleVolume.clamp(0.08, 1.0));
    } else {
      _lastAudibleVolume = widget.volume;
      widget.onChanged(0);
    }
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _layerLink,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        _anchorHovered = true;
        _scheduleShow();
      },
      onExit: (_) {
        _anchorHovered = false;
        _scheduleHide();
      },
      child: Tooltip(
        message: widget.volume <= 0.01 ? '恢复音量' : '静音',
        child: IconButton(
          onPressed: _toggleMute,
          icon: Icon(
            widget.volume <= 0.01
                ? Icons.volume_off_rounded
                : widget.volume < 0.45
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded,
          ),
          style: IconButton.styleFrom(
            minimumSize: const Size(42, 42),
            fixedSize: const Size(42, 42),
            foregroundColor: AppColors.muted,
            hoverColor: AppColors.selected,
            shape: const CircleBorder(),
          ),
        ),
      ),
    ),
  );
}

class _VolumePopover extends StatelessWidget {
  const _VolumePopover({required this.volume, required this.onChanged});

  final double volume;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (volume.clamp(0.0, 1.0) * 100).round();
    return Container(
      width: 210,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.popover,
      ),
      child: Row(
        children: [
          Icon(
            volume <= 0.01 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: AppColors.muted,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(value: volume.clamp(0.0, 1.0), onChanged: onChanged),
          ),
          const SizedBox(width: 6),
          Text(
            '$percent%',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
