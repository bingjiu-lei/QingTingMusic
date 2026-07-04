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

class _SongRowState extends State<SongRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isCurrent;
    final height = widget.compact ? 58.0 : 66.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onPlay,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.selected.withValues(
                    alpha: AppColors.isDark ? 0.78 : 1,
                  )
                : _hovered
                ? AppColors.surfaceHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: _hovered
                    ? IconButton(
                        tooltip: active && widget.isPlaying ? '暂停' : '播放',
                        padding: EdgeInsets.zero,
                        onPressed: widget.onPlay,
                        icon: Icon(
                          active && widget.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: active ? AppColors.primary : AppColors.muted,
                          size: 21,
                        ),
                      )
                    : Center(
                        child: Text(
                          '${widget.index + 1}'.padLeft(2, '0'),
                          style: TextStyle(
                            color: active ? AppColors.primary : AppColors.faint,
                            fontSize: 11,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
              ),
              AlbumArt(
                size: widget.compact ? 38 : 44,
                emphasized: active,
                imageUrl: widget.song.coverUrl,
              ),
              SizedBox(width: 12),
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
                        color: active ? AppColors.primary : AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 3),
                    _ArtistLine(
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
                            ? MouseCursor.defer
                            : SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: tap,
                          child: Text(
                            albumName.isEmpty ? '未知专辑' : widget.song.album,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: clickable
                                  ? AppColors.primaryPressed
                                  : AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (widget.onLike != null)
                SizedBox(
                  width: 38,
                  child: IconButton(
                    tooltip: widget.song.liked ? '取消收藏' : '收藏',
                    onPressed: widget.onLike,
                    icon: Icon(
                      widget.song.liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: widget.song.liked
                          ? AppColors.primary
                          : AppColors.faint,
                      size: 19,
                    ),
                  ),
                ),
              if (widget.onAddToPlaylist != null)
                SizedBox(
                  width: 34,
                  child: IgnorePointer(
                    ignoring: !_hovered,
                    child: AnimatedOpacity(
                      opacity: _hovered ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: IconButton(
                        tooltip: '添加到歌单',
                        onPressed: widget.onAddToPlaylist,
                        icon: Icon(
                          Icons.playlist_add_rounded,
                          color: AppColors.muted,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.onRemoveFromPlaylist != null)
                SizedBox(
                  width: 34,
                  child: IgnorePointer(
                    ignoring: !_hovered,
                    child: AnimatedOpacity(
                      opacity: _hovered ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: IconButton(
                        tooltip: '从歌单移除',
                        onPressed: widget.onRemoveFromPlaylist,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.muted,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(width: 8),
              Text(
                formatDuration(widget.song.duration),
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistLine extends StatelessWidget {
  const _ArtistLine({required this.song, this.onArtist, this.onArtistLink});

  final Song song;
  final VoidCallback? onArtist;
  final ValueChanged<SongArtist>? onArtistLink;

  @override
  Widget build(BuildContext context) {
    final artists = _visibleArtists(song);
    final fallbackArtist = _fallbackArtistLabel(song.artist);
    if (artists.isEmpty) {
      return Text(
        fallbackArtist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.muted, fontSize: 12),
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
              fontSize: 12,
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
        style: TextStyle(color: AppColors.muted, fontSize: 12),
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
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (index != artists.length - 1)
                Text(
                  ' / ',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
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
