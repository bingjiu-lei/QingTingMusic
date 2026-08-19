import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

class SongRow extends StatefulWidget {
  const SongRow({
    super.key,
    required this.song,
    required this.index,
    required this.onPlay,
    this.onLike,
    this.onArtist,
    this.onArtistLink,
    this.onAlbum,
    this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
    this.isCurrent = false,
    this.isPlaying = false,
    this.compact = false,
    this.showAlbum = true,
  });

  final Song song;
  final int index;
  final VoidCallback onPlay;
  final VoidCallback? onLike;
  final VoidCallback? onArtist;
  final ValueChanged<SongArtist>? onArtistLink;
  final VoidCallback? onAlbum;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onRemoveFromPlaylist;
  final bool isCurrent;
  final bool isPlaying;
  final bool compact;
  final bool showAlbum;

  @override
  State<SongRow> createState() => _SongRowState();
}

class _SongRowState extends State<SongRow> with TickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _playbackController;

  @override
  void initState() {
    super.initState();
    _playbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    _syncPlaybackAnimation();
  }

  @override
  void didUpdateWidget(covariant SongRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCurrent != widget.isCurrent ||
        oldWidget.isPlaying != widget.isPlaying) {
      _syncPlaybackAnimation();
    }
  }

  void _syncPlaybackAnimation() {
    if (widget.isCurrent && widget.isPlaying) {
      _playbackController.repeat();
    } else {
      _playbackController.stop();
      _playbackController.value = 0;
    }
  }

  @override
  void dispose() {
    _playbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isCurrent;
    final height = widget.compact ? 58.0 : 66.0;

    final isDark = AppColors.isDark;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onPlay,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
          child: AnimatedScale(
            scale: _hovered ? 1.01 : 1.0,
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary.withValues(
                        alpha: isDark ? 0.20 : 0.10,
                      )
                    : _hovered
                    ? AppColors.primary.withValues(
                        alpha: isDark ? 0.08 : 0.04,
                      )
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: active
                    ? Border.all(
                        color: AppColors.primary.withValues(
                          alpha: isDark ? 0.38 : 0.22,
                        ),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 120),
                    child: _hovered
                        ? IconButton(
                            key: const ValueKey('row-play'),
                            tooltip: active && widget.isPlaying
                                ? '暂停'
                                : '播放这首歌',
                            onPressed: widget.onPlay,
                            constraints: const BoxConstraints.tightFor(
                              width: 34,
                              height: 34,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              active && widget.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          )
                        : active
                        ? AnimatedBuilder(
                            animation: _playbackController,
                            key: const ValueKey('row-eq'),
                            builder: (context, _) => _PlaybackBars(
                              isPlaying: widget.isPlaying,
                              progress: _playbackController.value,
                            ),
                          )
                        : Text(
                            '${widget.index + 1}'.padLeft(2, '0'),
                            key: const ValueKey('row-index'),
                            style: TextStyle(
                              color: AppColors.faint,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                  ),
                ),
              ),
              AlbumArt(
                size: widget.compact ? 38 : 44,
                emphasized: active,
                imageUrl: widget.song.coverUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? AppColors.primaryPressed
                            : AppColors.text,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SongArtistLine(
                      song: widget.song,
                      onArtist: widget.onArtist,
                      onArtistLink: widget.onArtistLink,
                    ),
                  ],
                ),
              ),
              if (widget.showAlbum)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final albumName = widget.song.album.trim();
                      final hasAlbum =
                          albumName.isNotEmpty && albumName != '未知专辑';
                      final tap = hasAlbum ? widget.onAlbum : null;
                      final clickable = tap != null;
                      return MouseRegion(
                        cursor: tap == null
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: tap,
                          child: Text(
                            hasAlbum ? widget.song.album : '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasAlbum
                                  ? clickable
                                      ? AppColors.primaryPressed
                                      : AppColors.muted
                                  : AppColors.faint,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                  if (widget.onLike != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _RowActionButton(
                        icon: widget.song.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        tooltip: widget.song.liked ? '取消收藏' : '收藏',
                        onTap: widget.onLike,
                        iconColor: widget.song.liked
                            ? AppColors.favorite
                            : AppColors.faint,
                        hoverIconColor: widget.song.liked
                            ? AppColors.favorite
                            : AppColors.text,
                        shadowColor: widget.song.liked ? AppColors.favorite : null,
                        size: 30,
                        iconSize: 18,
                      ),
                    ),
                  if (widget.onAddToPlaylist != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: IgnorePointer(
                        ignoring: !_hovered,
                        child: AnimatedOpacity(
                          opacity: _hovered ? 1 : 0,
                          duration: const Duration(milliseconds: 120),
                          child: _RowActionButton(
                            tooltip: '添加到歌单',
                            onTap: widget.onAddToPlaylist,
                            icon: Icons.playlist_add_rounded,
                            iconColor: AppColors.muted,
                            hoverIconColor: AppColors.primary,
                            shadowColor: AppColors.primary,
                            size: 30,
                            iconSize: 18,
                          ),
                        ),
                      ),
                    ),
                  if (widget.onRemoveFromPlaylist != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: IgnorePointer(
                        ignoring: !_hovered,
                        child: AnimatedOpacity(
                          opacity: _hovered ? 1 : 0,
                          duration: const Duration(milliseconds: 120),
                          child: _RowActionButton(
                            tooltip: '从歌单移除',
                            onTap: widget.onRemoveFromPlaylist,
                            icon: Icons.delete_outline_rounded,
                            iconColor: AppColors.muted,
                            hoverIconColor: AppColors.danger,
                            shadowColor: AppColors.danger,
                            size: 30,
                            iconSize: 17,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    formatDuration(widget.song.duration),
                    style: AppTypography.timeCode(12, color: AppColors.muted),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RowActionButton extends StatefulWidget {
  const _RowActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 30.0,
    this.iconSize = 18.0,
    this.iconColor,
    this.hoverIconColor,
    this.shadowColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? hoverIconColor;
  final Color? shadowColor;

  @override
  State<_RowActionButton> createState() => _RowActionButtonState();
}

class _RowActionButtonState extends State<_RowActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final isDark = AppColors.isDark;
    final size = widget.size;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: enabled && _hovered ? 1.12 : 1.0,
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled && _hovered
                    ? AppColors.surfaceHover.withValues(
                        alpha: isDark ? 0.85 : 0.95,
                      )
                    : Colors.transparent,
                boxShadow: enabled && _hovered
                    ? [
                        BoxShadow(
                          color: (widget.shadowColor ?? AppColors.shadow)
                              .withValues(
                            alpha: isDark ? 0.30 : 0.10,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: enabled
                      ? (_hovered
                          ? (widget.hoverIconColor ?? AppColors.text)
                          : (widget.iconColor ?? AppColors.muted))
                      : AppColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaybackBars extends StatelessWidget {
  const _PlaybackBars({required this.isPlaying, required this.progress});

  final bool isPlaying;
  final double progress;

  @override
  Widget build(BuildContext context) {
    const phases = [0.0, 2.1, 4.2];
    const heights = [8.0, 14.0, 10.0];
    return SizedBox(
      key: const ValueKey('row-bars'),
      width: 20,
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (index) {
          final wave =
              (math.sin(progress * math.pi * 2 + phases[index]) + 1) / 2;
          final scale = isPlaying ? 0.42 + wave * 0.58 : 0.42;
          return Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 2),
            child: Transform.scale(
              alignment: Alignment.bottomCenter,
              scaleY: scale,
              child: Container(
                width: 2.5,
                height: heights[index],
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SongArtistLine extends StatelessWidget {
  const SongArtistLine({
    super.key,
    required this.song,
    this.onArtist,
    this.onArtistLink,
    this.fontSize = 12,
  });

  final Song song;
  final VoidCallback? onArtist;
  final ValueChanged<SongArtist>? onArtistLink;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final artists = _visibleArtists(song);
    final fallbackArtist = _fallbackArtistLabel(song.artist);
    if (artists.isEmpty) {
      return Text(
        fallbackArtist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.muted, fontSize: fontSize),
      );
    }
    if (artists.length == 1) {
      final artist = artists.first;
      final onTap = onArtistLink == null
          ? onArtist
          : () => onArtistLink!(artist);
      return MouseRegion(
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Text(
            artist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: onTap == null ? AppColors.muted : AppColors.primaryPressed,
              fontSize: fontSize,
            ),
          ),
        ),
      );
    }
    if (onArtistLink == null) {
      return Text(
        _artistJoin(artists),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.muted, fontSize: fontSize),
      );
    }

    return SizedBox(
      height: 17,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < artists.length; index++) ...[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => onArtistLink!(artists[index]),
                  borderRadius: BorderRadius.circular(4),
                  child: Text(
                    artists[index].name,
                    maxLines: 1,
                    style: TextStyle(
                      color: AppColors.primaryPressed,
                      fontSize: fontSize,
                    ),
                  ),
                ),
              ),
              if (index != artists.length - 1)
                Text(
                  ' / ',
                  style: TextStyle(color: AppColors.muted, fontSize: fontSize),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

List<SongArtist> _visibleArtists(Song song) {
  final source = song.artists.isEmpty
      ? [SongArtist(name: song.artist, id: song.artistId)]
      : song.artists;
  final result = <SongArtist>[];
  final seen = <String>{};
  for (final artist in source) {
    final name = _normalizeArtistName(artist.name);
    if (!_hasVisibleText(name) ||
        _isPlaceholderArtist(name) ||
        !seen.add(name)) {
      continue;
    }
    result.add(SongArtist(name: name, id: artist.id));
  }
  if (result.isNotEmpty) return result;

  final fallbackNames = song.artist
      .split(RegExp(r'\s*/\s*'))
      .map(_normalizeArtistName)
      .where((name) => _hasVisibleText(name) && !_isPlaceholderArtist(name));
  for (final name in fallbackNames) {
    if (seen.add(name)) result.add(SongArtist(name: name));
  }
  return result;
}

String _artistJoin(List<SongArtist> artists) =>
    artists.map((artist) => artist.name).join(' / ');

String _fallbackArtistLabel(String value) {
  final cleaned = _normalizeArtistName(value);
  if (_hasVisibleText(cleaned) && !_isPlaceholderArtist(cleaned)) {
    return cleaned;
  }
  return '群星';
}

String _normalizeArtistName(String value) {
  return value.replaceAll(RegExp(r'^[\s/\\|,，、]+|[\s/\\|,，、]+$'), '').trim();
}

bool _hasVisibleText(String value) {
  return RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(value);
}

bool _isPlaceholderArtist(String value) {
  final text = value.trim().toLowerCase();
  return text == '未知歌手' ||
      text == 'unknown' ||
      text == 'unknown artist' ||
      text == 'null';
}

String formatDuration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
