import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import 'song_row.dart';

class SongPanel extends StatelessWidget {
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
  });

  final String title;
  final List<Song> songs;
  final ValueChanged<Song> onPlay;
  final Song? currentSong;
  final bool isPlaying;
  final bool compactRows;
  final String emptyText;
  final ValueChanged<Song>? onLike;
  final ValueChanged<Song>? onArtist;
  final ValueChanged<Song>? onAlbum;

  @override
  Widget build(BuildContext context) {
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
            title,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: songs.isEmpty
                ? Center(
                    child: Text(
                      emptyText,
                      style: TextStyle(color: AppColors.faint, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: songs.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: AppColors.divider,
                    ),
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return SongRow(
                        song: song,
                        index: index,
                        compact: compactRows,
                        isCurrent: currentSong?.id == song.id,
                        isPlaying: isPlaying,
                        onPlay: () => onPlay(song),
                        onLike: onLike == null ? null : () => onLike!(song),
                        onArtist: onArtist == null
                            ? null
                            : () => onArtist!(song),
                        onAlbum: onAlbum == null ? null : () => onAlbum!(song),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
