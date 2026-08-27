import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/playback_quality_controller.dart';
import '../controllers/player_controller.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'app_icon_button.dart';
import 'heart_off_icon.dart';
import 'preparing_dots.dart';
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
    required this.desktopLyricsVisible,
    required this.onDesktopLyricsChanged,
    this.isFm = false,
    this.onDislikeFm,
  });

  final PlayerController controller;
  final PlaybackQualityController playbackQualityController;
  final VoidCallback? onQueuePressed;
  final VoidCallback? onNowPlayingPressed;
  final ValueChanged<Song>? onOpenAlbum;
  final ValueChanged<Song>? onOpenArtist;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onAddToPlaylist;
  final bool desktopLyricsVisible;
  final ValueChanged<bool> onDesktopLyricsChanged;
  final bool isFm;
  final VoidCallback? onDislikeFm;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([controller, controller.progress]),
    builder: (context, _) {
      final song = controller.currentSong;
      final duration = controller.duration == Duration.zero && song != null
          ? song.duration
          : controller.duration;
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppGlass.blurChrome,
            sigmaY: AppGlass.blurChrome,
          ),
          child: Container(
            height: 92,
            decoration: BoxDecoration(
              color: AppGlass.surfaceStrong,
              border: Border(top: BorderSide(color: AppGlass.border)),
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
                    climaxSegments: song?.climaxSegments ?? const [],
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
                                onCyclePlaybackMode:
                                    controller.cyclePlaybackMode,
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
                                isFm: isFm,
                                onDislikeFm: onDislikeFm,
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: _ToolSection(
                                controller: controller,
                                song: song,
                                onOpenAlbum: onOpenAlbum,
                                volume: controller.volume,
                                onVolumeChanged: controller.setVolume,
                                qualityController: playbackQualityController,
                                desktopLyricsVisible: desktopLyricsVisible,
                                onDesktopLyricsChanged: onDesktopLyricsChanged,
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
          ),
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
  const _TransportSection({
    required this.controller,
    required this.song,
    this.isFm = false,
    this.onDislikeFm,
  });

  final PlayerController controller;
  final Song? song;
  final bool isFm;
  final VoidCallback? onDislikeFm;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (isFm)
        _ControlIconButton(
          tooltip: '不喜欢',
          onPressed: song == null || onDislikeFm == null ? null : onDislikeFm,
          child: const HeartOffIcon(size: 20, strokeWidth: 1.7),
        )
      else
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
    required this.controller,
    required this.song,
    required this.onOpenAlbum,
    required this.volume,
    required this.onVolumeChanged,
    required this.qualityController,
    required this.desktopLyricsVisible,
    required this.onDesktopLyricsChanged,
    required this.onQueuePressed,
  });

  final PlayerController controller;
  final Song? song;
  final ValueChanged<Song>? onOpenAlbum;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final PlaybackQualityController qualityController;
  final bool desktopLyricsVisible;
  final ValueChanged<bool> onDesktopLyricsChanged;
  final VoidCallback? onQueuePressed;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      if (song != null)
        _ControlIconButton(
          tooltip: _hasPlayableAlbum(song!) ? '打开专辑' : '暂无专辑',
          onPressed: _hasPlayableAlbum(song!) && onOpenAlbum != null
              ? () => onOpenAlbum!(song!)
              : null,
          icon: Icons.album_outlined,
        ),
      PlaybackQualityMenu(
        controller: qualityController,
        playerController: controller,
        compact: true,
      ),
      const SizedBox(width: 4),
      _ControlIconButton(
        tooltip: desktopLyricsVisible ? '关闭桌面歌词' : '打开桌面歌词',
        onPressed: () => onDesktopLyricsChanged(!desktopLyricsVisible),
        icon: null,
        selected: desktopLyricsVisible,
        child: Text(
          '词',
          style: TextStyle(
            color: desktopLyricsVisible ? AppColors.primary : AppColors.muted,
            fontSize: 15,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
  PlaybackMode.sequence => Icons.playlist_play_rounded,
  PlaybackMode.repeatAll => Icons.repeat_rounded,
  PlaybackMode.repeatOne => Icons.repeat_one_rounded,
  PlaybackMode.shuffle => Icons.shuffle_rounded,
};

class _PrimaryPlayButton extends StatefulWidget {
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
  State<_PrimaryPlayButton> createState() => _PrimaryPlayButtonState();
}

class _PrimaryPlayButtonState extends State<_PrimaryPlayButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final preparing = widget.preparing;
    final isPlaying = widget.isPlaying;
    final isDark = AppColors.isDark;

    return Semantics(
      button: true,
      label: isPlaying ? '暂停' : '播放',
      child: Tooltip(
        message: preparing
            ? '正在准备'
            : isPlaying
            ? '暂停'
            : '播放',
        child: MouseRegion(
          cursor: enabled && !preparing
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: GestureDetector(
            onTapDown: enabled && !preparing
                ? (_) => setState(() => _pressed = true)
                : null,
            onTapUp: enabled && !preparing
                ? (_) => setState(() => _pressed = false)
                : null,
            onTapCancel: () => setState(() => _pressed = false),
            onTap: enabled && !preparing ? widget.onPressed : null,
            child: AnimatedScale(
              scale: _pressed ? 0.94 : (_hovered && enabled ? 1.08 : 1.0),
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              child: AnimatedContainer(
                duration: AppMotion.fast,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled ? AppColors.primary : AppColors.surfaceMuted,
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                              alpha: isDark
                                  ? (_hovered ? 0.48 : 0.32)
                                  : (_hovered ? 0.35 : 0.22),
                            ),
                            blurRadius: _hovered ? 14 : 8,
                            offset: Offset(0, _hovered ? 3 : 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: preparing
                      ? const PreparingDots()
                      : Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: enabled ? Colors.white : AppColors.faint,
                          size: 25,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.iconSize = 21,
    this.selected = false,
    this.size = 42,
    this.selectedColor,
    this.selectedBackgroundColor,
    this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double iconSize;
  final bool selected;
  final double size;
  final Color? selectedColor;
  final Color? selectedBackgroundColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AppIconButton.ghost(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      iconSize: iconSize,
      selected: selected,
      size: size,
      selectedColor: selectedColor,
      selectedBackgroundColor: selectedBackgroundColor,
      iconColor: AppColors.muted,
      hoverIconColor: selected
          ? (selectedColor ?? AppColors.primary)
          : AppColors.primary,
      shadowColor: selected
          ? (selectedColor ?? AppColors.primary)
          : AppColors.primary,
      child: child,
    );
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
  Timer? _showTimer;
  Timer? _hideTimer;
  bool _anchorHovered = false;
  bool _popoverHovered = false;
  double _lastAudibleVolume = 0.78;

  @override
  void initState() {
    super.initState();
    if (widget.volume > 0.01) _lastAudibleVolume = widget.volume;
  }

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
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _scheduleShow() {
    _hideTimer?.cancel();
    if (_overlayEntry != null) return;
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted || (!_anchorHovered && !_popoverHovered)) return;
      _showPopover();
    });
  }

  void _scheduleHide() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (!_anchorHovered && !_popoverHovered) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  void _showPopover() {
    _overlayEntry?.remove();
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        width: 64,
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0, -8),
          child: MouseRegion(
            onEnter: (_) {
              _popoverHovered = true;
              _scheduleShow();
            },
            onExit: (_) {
              _popoverHovered = false;
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
    Overlay.of(context, rootOverlay: true).insert(entry);
    _overlayEntry = entry;
  }

  void _toggleMute() {
    if (widget.volume <= 0.01) {
      widget.onChanged(_lastAudibleVolume.clamp(0.08, 1.0));
    } else {
      _lastAudibleVolume = widget.volume;
      widget.onChanged(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
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
        child: AppIconButton.ghost(
          tooltip: widget.volume <= 0.01 ? '恢复音量' : '静音',
          onPressed: _toggleMute,
          icon: widget.volume <= 0.01
              ? Icons.volume_off_rounded
              : widget.volume < 0.45
              ? Icons.volume_down_rounded
              : Icons.volume_up_rounded,
          size: 42,
          iconSize: 21,
          iconColor: AppColors.muted,
          hoverIconColor: AppColors.primary,
          shadowColor: AppColors.primary,
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
    return Container(
      width: 64,
      height: 168,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.popover,
      ),
      child: Column(
        children: [
          Text(
            '$percent',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: volume.clamp(0.0, 1.0),
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Icon(
            volume <= 0.01 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: AppColors.muted,
            size: 19,
          ),
        ],
      ),
    );
  }
}
