import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/page_header.dart';
import '../widgets/song_panel.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.allSongs,
    required this.recentSongs,
    required this.currentSong,
    required this.isPlaying,
    required this.onPlay,
  });

  final List<Song> allSongs;
  final List<Song> recentSongs;
  final Song? currentSong;
  final bool isPlaying;
  final ValueChanged<Song> onPlay;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final favorites = widget.allSongs.where((song) => song.liked).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: '我的音乐', subtitle: '收藏和最近听过的歌曲'),
          const SizedBox(height: 22),
          Row(
            children: [
              _LibraryTab(
                label: '我的收藏',
                count: favorites.length,
                selected: selectedTab == 0,
                onTap: () => setState(() => selectedTab = 0),
              ),
              const SizedBox(width: 24),
              _LibraryTab(
                label: '最近播放',
                count: widget.recentSongs.length,
                selected: selectedTab == 1,
                onTap: () => setState(() => selectedTab = 1),
              ),
              const SizedBox(width: 24),
              _LibraryTab(
                label: '我的歌单',
                selected: selectedTab == 2,
                onTap: () => setState(() => selectedTab = 2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _tabContent(favorites)),
        ],
      ),
    );
  }

  Widget _tabContent(List<Song> favorites) {
    return switch (selectedTab) {
      0 => SongPanel(
        title: '收藏歌曲',
        songs: favorites,
        currentSong: widget.currentSong,
        isPlaying: widget.isPlaying,
        emptyText: '收藏的歌曲会出现在这里',
        onPlay: widget.onPlay,
      ),
      1 => SongPanel(
        title: '最近播放',
        songs: widget.recentSongs,
        currentSong: widget.currentSong,
        isPlaying: widget.isPlaying,
        emptyText: '还没有播放记录',
        onPlay: widget.onPlay,
      ),
      _ => const _PlaylistEmptyState(),
    };
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.text : AppColors.muted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: AppColors.faint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 7),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: selected ? 24 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistEmptyState extends StatelessWidget {
  const _PlaylistEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_add_rounded, color: AppColors.faint, size: 34),
            SizedBox(height: 10),
            Text(
              '还没有创建歌单',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
