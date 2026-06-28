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
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onPlay,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: 8),
          color: active
              ? AppColors.selected
              : _hovered
              ? AppColors.primary.withValues(
                  alpha: AppColors.isDark ? 0.08 : 0.04,
                )
              : Colors.transparent,
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
    final artists =
        (song.artists.isEmpty
                ? [SongArtist(name: song.artist, id: song.artistId)]
                : song.artists)
            .where((artist) => _hasVisibleText(artist.name))
            .toList();
    final fallbackArtist = _hasVisibleText(song.artist) ? song.artist : '未知歌手';
    if (artists.isEmpty) {
      return Text(
        fallbackArtist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      );
    }
    if (artists.length <= 1 || onArtistLink == null) {
      return MouseRegion(
        cursor: onArtist == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onArtist,
          child: Text(
            fallbackArtist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: onArtist == null
                  ? AppColors.muted
                  : AppColors.primaryPressed,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 17,
      child: ClipRect(
        child: Row(
          children: [
            for (var index = 0; index < artists.length; index++) ...[
              Flexible(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => onArtistLink!(artists[index]),
                    child: Text(
                      artists[index].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primaryPressed,
                        fontSize: 12,
                      ),
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

bool _hasVisibleText(String value) {
  return RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(value);
}

String formatDuration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
