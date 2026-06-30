import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import 'list_scroll_actions.dart';
import 'song_row.dart';

typedef SongPlayRequest = void Function(Song song, List<Song> queue);

class SongPanel extends StatefulWidget {
  const SongPanel({
    super.key,
    required this.title,
    required this.songs,
    required this.onPlay,
    this.currentSong,
    this.isPlaying = false,
    this.compactRows = false,
    this.emptyText = '暂无歌曲',
    this.onLike,
    this.onArtist,
    this.onAlbum,
    this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
    this.showAlbum = true,
  });

  final String title;
  final List<Song> songs;
  final SongPlayRequest onPlay;
  final Song? currentSong;
  final bool isPlaying;
  final bool compactRows;
  final String emptyText;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onArtist;
  final ValueChanged<Song>? onAlbum;
  final ValueChanged<Song>? onAddToPlaylist;
  final ValueChanged<Song>? onRemoveFromPlaylist;
  final bool showAlbum;

  @override
  State<SongPanel> createState() => _SongPanelState();
}

class _SongPanelState extends State<SongPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int? get _currentIndex {
    final current = widget.currentSong;
    if (current == null) return null;
    for (var i = 0; i < widget.songs.length; i++) {
      if (widget.songs[i].id == current.id) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final itemExtent = widget.compactRows ? 59.0 : 67.0;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: widget.songs.isEmpty
                ? Center(
                    child: Text(
                      widget.emptyText,
                      style: TextStyle(color: AppColors.faint, fontSize: 13),
                    ),
                  )
                : Stack(
                    children: [
                      ListView.separated(
                        key: widget.key is PageStorageKey ? widget.key : null,
                        controller: _scrollController,
                        itemCount: widget.songs.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          thickness: 0.5,
                          color: AppColors.divider,
                        ),
                        itemBuilder: (context, index) {
                          final song = widget.songs[index];
                          return SongRow(
                            song: song,
                            index: index,
                            compact: widget.compactRows,
                            isCurrent: widget.currentSong?.id == song.id,
                            isPlaying: widget.isPlaying,
                            onPlay: () => widget.onPlay(song, widget.songs),
                            onLike: widget.onLike == null
                                ? null
                                : () => widget.onLike!(song),
                            onArtist: widget.onArtist == null
                                ? null
                                : () => widget.onArtist!(song),
                            onArtistLink: widget.onArtist == null
                                ? null
                                : (artist) => widget.onArtist!(
                                    song.copyWith(
                                      artist: artist.name,
                                      artistId: artist.id,
                                      artists: [artist],
                                    ),
                                  ),
                            onAlbum: widget.onAlbum == null
                                ? null
                                : () => widget.onAlbum!(song),
                            onAddToPlaylist: widget.onAddToPlaylist == null
                                ? null
                                : () => widget.onAddToPlaylist!(song),
                            onRemoveFromPlaylist:
                                widget.onRemoveFromPlaylist == null
                                ? null
                                : () => widget.onRemoveFromPlaylist!(song),
                            showAlbum: widget.showAlbum,
                          );
                        },
                      ),
                      ListScrollActions(
                        controller: _scrollController,
                        currentIndex: _currentIndex,
                        itemExtent: itemExtent,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
