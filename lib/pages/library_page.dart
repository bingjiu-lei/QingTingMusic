import 'package:flutter/material.dart';

import '../controllers/music_library_controller.dart';
import '../models/music_playlist.dart';
import '../models/search_catalog_item.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/page_header.dart';
import '../widgets/search_catalog_list.dart';
import '../widgets/song_panel.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.controller,
    required this.recentSongs,
    required this.currentSong,
    required this.isPlaying,
    required this.onPlay,
    required this.onLike,
    required this.onOpenArtist,
    required this.onOpenAlbum,
    required this.onOpenPlaylist,
    required this.onOpenCatalog,
    required this.onLogin,
  });

  final MusicLibraryController controller;
  final List<Song> recentSongs;
  final Song? currentSong;
  final bool isPlaying;
  final SongPlayRequest onPlay;
  final ValueChanged<Song> onLike;
  final ValueChanged<Song> onOpenArtist;
  final ValueChanged<Song> onOpenAlbum;
  final ValueChanged<MusicPlaylist> onOpenPlaylist;
  final ValueChanged<SearchCatalogItem> onOpenCatalog;
  final VoidCallback onLogin;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int selectedTab = 0;

  static const tabs = [
    ('歌曲', LibrarySection.songs),
    ('歌单', LibrarySection.playlists),
    ('专辑', LibrarySection.albums),
    ('歌手', LibrarySection.artists),
    ('云盘', LibrarySection.cloud),
    ('最近播放', LibrarySection.recent),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: '我的音乐', subtitle: '收藏与个人音乐内容'),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < tabs.length; index++) ...[
                  _LibraryTab(
                    label: tabs[index].$1,
                    selected: selectedTab == index,
                    onTap: () {
                      setState(() => selectedTab = index);
                      widget.controller.ensureLoaded(tabs[index].$2);
                    },
                  ),
                  if (index != tabs.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _content() {
    final controller = widget.controller;
    final section = tabs[selectedTab].$2;
    final content = switch (section) {
      LibrarySection.songs => _songs(
        '歌曲',
        controller.sortedFavorites,
        '还没有收藏的歌曲',
      ),
      LibrarySection.playlists => _PlaylistGroups(
        created: controller.createdPlaylists,
        collected: controller.collectedPlaylists,
        onOpen: widget.onOpenPlaylist,
      ),
      LibrarySection.albums => _PlaylistGrid(
        playlists: controller.sortedAlbums,
        onOpen: widget.onOpenPlaylist,
        emptyText: '还没有收藏的专辑',
      ),
      LibrarySection.artists => SearchCatalogList(
        items: controller.followedArtists,
        emptyText: '还没有收藏的歌手',
        onSelected: widget.onOpenCatalog,
      ),
      LibrarySection.cloud => _songs(
        '云盘歌曲',
        controller.sortedCloudSongs,
        '云盘中还没有歌曲',
      ),
      LibrarySection.recent => _songs('最近播放', widget.recentSongs, '还没有播放记录'),
    };

    final error = controller.errors[section];
    if (error != null && !controller.hasData(section)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => controller.ensureLoaded(section, refresh: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (controller.isLoading(section) && !controller.hasData(section)) {
      return const _SoftLoading();
    }
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(key: ValueKey(selectedTab), child: content),
        ),
        if (controller.isLoading(section))
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _songs(String title, List<Song> songs, String emptyText) {
    return SongPanel(
      title: title,
      songs: songs,
      currentSong: widget.currentSong,
      isPlaying: widget.isPlaying,
      emptyText: emptyText,
      onPlay: widget.onPlay,
      onLike: widget.onLike,
      onArtist: widget.onOpenArtist,
      onAlbum: widget.onOpenAlbum,
    );
  }
}

class _PlaylistGroups extends StatelessWidget {
  const _PlaylistGroups({
    required this.created,
    required this.collected,
    required this.onOpen,
  });

  final List<MusicPlaylist> created;
  final List<MusicPlaylist> collected;
  final ValueChanged<MusicPlaylist> onOpen;

  @override
  Widget build(BuildContext context) {
    if (created.isEmpty && collected.isEmpty) {
      return Center(
        child: Text('还没有歌单', style: TextStyle(color: AppColors.faint)),
      );
    }
    return CustomScrollView(
      slivers: [
        if (created.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionTitle('创建')),
          _PlaylistSliver(playlists: created, onOpen: onOpen),
          const SliverToBoxAdapter(child: SizedBox(height: 22)),
        ],
        if (collected.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionTitle('收藏')),
          _PlaylistSliver(playlists: collected, onOpen: onOpen),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlaylistSliver extends StatelessWidget {
  const _PlaylistSliver({required this.playlists, required this.onOpen});

  final List<MusicPlaylist> playlists;
  final ValueChanged<MusicPlaylist> onOpen;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 76,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) =>
            _PlaylistTile(playlist: playlists[index], onOpen: onOpen),
        childCount: playlists.length,
      ),
    );
  }
}

class _PlaylistGrid extends StatelessWidget {
  const _PlaylistGrid({
    required this.playlists,
    required this.onOpen,
    this.emptyText = '还没有歌单',
  });

  final List<MusicPlaylist> playlists;
  final ValueChanged<MusicPlaylist> onOpen;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return Center(
        child: Text(emptyText, style: TextStyle(color: AppColors.faint)),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 76,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) =>
          _PlaylistTile(playlist: playlists[index], onOpen: onOpen),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.playlist, required this.onOpen});

  final MusicPlaylist playlist;
  final ValueChanged<MusicPlaylist> onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onOpen(playlist),
        borderRadius: BorderRadius.circular(8),
        hoverColor: AppColors.selected.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 54,
                  height: 54,
                  color: AppColors.surfaceMuted,
                  child: playlist.coverUrl == null
                      ? Icon(
                          playlist.kind == MusicPlaylistKind.album
                              ? Icons.album_rounded
                              : Icons.queue_music_rounded,
                          color: AppColors.muted,
                        )
                      : Image.network(
                          playlist.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.queue_music_rounded,
                            color: AppColors.muted,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${playlist.songCount} 首歌曲',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: AppColors.selected.withValues(alpha: 0.65),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.text : AppColors.muted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 7),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 24 : 0,
                height: 2,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftLoading extends StatelessWidget {
  const _SoftLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) => TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 260 + index * 35),
        tween: Tween(begin: 0, end: 1),
        builder: (_, value, child) => Opacity(opacity: value, child: child),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
