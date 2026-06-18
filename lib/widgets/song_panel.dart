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
  });

  final String title;
  final List<Song> songs;
  final ValueChanged<Song> onPlay;
  final Song? currentSong;
  final bool isPlaying;
  final bool compactRows;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: songs.isEmpty
                ? Center(
                    child: Text(
                      emptyText,
                      style: const TextStyle(
                        color: AppColors.faint,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: songs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return SongRow(
                        song: song,
                        index: index,
                        compact: compactRows,
                        isCurrent: currentSong?.id == song.id,
                        isPlaying: isPlaying,
                        onPlay: () => onPlay(song),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
