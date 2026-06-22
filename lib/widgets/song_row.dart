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
    this.onAlbum,
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
  final VoidCallback? onAlbum;
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
              ? AppColors.surfaceMuted
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
                    MouseRegion(
                      cursor: widget.onArtist == null
                          ? MouseCursor.defer
                          : SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: widget.onArtist,
                        child: Text(
                          widget.song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.onArtist == null
                                ? AppColors.muted
                                : AppColors.primaryPressed,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showAlbum)
                Expanded(
                  child: MouseRegion(
                    cursor: widget.onAlbum == null
                        ? MouseCursor.defer
                        : SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: widget.onAlbum,
                      child: Text(
                        widget.song.album,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.onAlbum == null
                              ? AppColors.muted
                              : AppColors.primaryPressed,
                          fontSize: 12,
                        ),
                      ),
                    ),
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

String formatDuration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
