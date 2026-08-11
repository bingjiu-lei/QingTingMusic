import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/music_library_controller.dart';
import '../models/music_playlist.dart';
import '../models/search_catalog_item.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
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
    required this.onAddToPlaylist,
    required this.onOpenArtist,
    required this.onOpenAlbum,
    required this.onOpenPlaylist,
    required this.onOpenCatalog,
    required this.onLogin,
    required this.onCreatePlaylist,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final MusicLibraryController controller;
  final List<Song> recentSongs;
  final Song? currentSong;
  final bool isPlaying;
  final SongPlayRequest onPlay;
  final ValueChanged<Song> onLike;
  final ValueChanged<Song> onAddToPlaylist;
  final ValueChanged<Song> onOpenArtist;
  final ValueChanged<Song> onOpenAlbum;
  final ValueChanged<MusicPlaylist> onOpenPlaylist;
  final ValueChanged<SearchCatalogItem> onOpenCatalog;
  final VoidCallback onLogin;
  final VoidCallback onCreatePlaylist;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _filterFocusNode = FocusNode();
  String _filterText = '';
  bool _filterExpanded = false;
  bool _reversed = false;

  @override
  void dispose() {
    _filterController.dispose();
    _filterFocusNode.dispose();
    super.dispose();
  }
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
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: '我的音乐', subtitle: '收藏与个人音乐内容'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: GlassTabBar(
                    tabs: [for (final tab in tabs) tab.$1],
                    selectedIndex: widget.selectedTab,
                    onChanged: (index) {
                      widget.onTabChanged(index);
                      widget.controller.ensureLoaded(tabs[index].$2);
                    },
                  ),
                ),
              ),
              if (_currentSectionSongs != null) ...[
                const SizedBox(width: 12),
                SongHeaderActions(
                  songs: _currentSectionSongs!,
                  onPlayAll: _currentSectionSongs!.isEmpty
                      ? null
                      : () => widget.onPlay(
                            _currentSectionSongs!.first,
                            _currentSectionSongs!,
                          ),
                  filterController: _filterController,
                  filterFocusNode: _filterFocusNode,
                  filterExpanded: _filterExpanded,
                  hasFilter: _filterText.trim().isNotEmpty,
                  onExpandFilter: () {
                    setState(() => _filterExpanded = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _filterFocusNode.requestFocus();
                    });
                  },
                  onChangedFilter: (val) => setState(() => _filterText = val),
                  onClearFilter: () {
                    _filterController.clear();
                    setState(() {
                      _filterText = '';
                      _filterExpanded = false;
                    });
                    _filterFocusNode.unfocus();
                  },
                  reversed: _reversed,
                  onToggleSort: () => setState(() => _reversed = !_reversed),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: ClipRect(child: _content())),
        ],
      ),
    );
  }

  List<Song>? get _currentSectionSongs {
    final section = tabs[widget.selectedTab].$2;
    return switch (section) {
      LibrarySection.songs => widget.controller.sortedFavorites,
      LibrarySection.cloud => widget.controller.sortedCloudSongs,
      LibrarySection.recent => widget.recentSongs,
      _ => null,
    };
  }

  Widget _content() {
    final controller = widget.controller;
    final section = tabs[widget.selectedTab].$2;
    final content = switch (section) {
      LibrarySection.songs => _songs(
        '歌曲',
        controller.sortedFavorites,
        '还没有收藏的歌曲',
        storageKey: const PageStorageKey('library-songs-scroll'),
      ),
      LibrarySection.playlists => _PlaylistGroups(
        created: controller.createdPlaylists,
        collected: controller.collectedPlaylists,
        onOpen: widget.onOpenPlaylist,
        onCreate: widget.onCreatePlaylist,
        storageKey: const PageStorageKey('library-playlists-scroll'),
      ),
      LibrarySection.albums => _PlaylistGrid(
        playlists: controller.sortedAlbums,
        onOpen: widget.onOpenPlaylist,
        emptyText: '还没有收藏的专辑',
        storageKey: const PageStorageKey('library-albums-scroll'),
      ),
      LibrarySection.artists => SearchCatalogList(
        items: controller.followedArtists,
        emptyText: '还没有收藏的歌手',
        onSelected: widget.onOpenCatalog,
        storageKey: const PageStorageKey('library-artists-scroll'),
      ),
      LibrarySection.cloud => _songs(
        '云盘歌曲',
        controller.sortedCloudSongs,
        '云盘中还没有歌曲',
        storageKey: const PageStorageKey('library-cloud-scroll'),
      ),
      LibrarySection.recent => _songs(
        '最近播放',
        widget.recentSongs,
        '还没有播放记录',
        storageKey: const PageStorageKey('library-recent-scroll'),
      ),
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
          child: KeyedSubtree(
            key: ValueKey(widget.selectedTab),
            child: content,
          ),
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

  Widget _songs(
    String title,
    List<Song> songs,
    String emptyText, {
    PageStorageKey<String>? storageKey,
  }) {
    return SongPanel(
      key: storageKey,
      filterText: _filterText,
      reversed: _reversed,
      title: title,
      songs: songs,
      currentSong: widget.currentSong,
      isPlaying: widget.isPlaying,
      compactRows: true,
      emptyText: emptyText,
      onPlay: widget.onPlay,
      onLike: widget.onLike,
      onAddToPlaylist: widget.onAddToPlaylist,
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
    required this.onCreate,
    required this.storageKey,
  });

  final List<MusicPlaylist> created;
  final List<MusicPlaylist> collected;
  final ValueChanged<MusicPlaylist> onOpen;
  final VoidCallback onCreate;
  final PageStorageKey<String> storageKey;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: storageKey,
      clipBehavior: Clip.none,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          sliver: SliverToBoxAdapter(
            child: _PlaylistSectionTitle('创建', onCreate: onCreate),
          ),
        ),
        if (created.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            sliver: _PlaylistSliver(playlists: created, onOpen: onOpen),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 22)),
        ] else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '创建一个歌单，整理你想留下的音乐',
                  style: TextStyle(color: AppColors.faint),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
        if (collected.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            sliver: const SliverToBoxAdapter(child: _SectionTitle('收藏')),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            sliver: _PlaylistSliver(playlists: collected, onOpen: onOpen),
          ),
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
      child: Row(
        children: [
          Text(
            text,
            style: AppTypography.style(17, 700, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

class _PlaylistSectionTitle extends StatefulWidget {
  const _PlaylistSectionTitle(this.text, {required this.onCreate});

  final String text;
  final VoidCallback onCreate;

  @override
  State<_PlaylistSectionTitle> createState() => _PlaylistSectionTitleState();
}

class _PlaylistSectionTitleState extends State<_PlaylistSectionTitle> {
  Timer? _hideTimer;
  var _visible = false;

  void _show() {
    _hideTimer?.cancel();
    if (!_visible) setState(() => _visible = true);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _show(),
    onExit: (_) => _scheduleHide(),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            widget.text,
            style: AppTypography.style(17, 700, color: AppColors.text),
          ),
          const SizedBox(width: 8),
          IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: AppMotion.fast,
              child: Tooltip(
                message: '新建歌单',
                child: IconButton(
                  onPressed: widget.onCreate,
                  mouseCursor: SystemMouseCursors.click,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    fixedSize: const Size(32, 32),
                    foregroundColor: AppColors.muted,
                    backgroundColor: AppColors.surfaceMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
        mainAxisExtent: 80,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
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
    required this.storageKey,
    this.emptyText = '还没有歌单',
  });

  final List<MusicPlaylist> playlists;
  final ValueChanged<MusicPlaylist> onOpen;
  final PageStorageKey<String> storageKey;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return Center(
        child: Text(emptyText, style: TextStyle(color: AppColors.faint)),
      );
    }
    return GridView.builder(
      key: storageKey,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 80,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) =>
          _PlaylistTile(playlist: playlists[index], onOpen: onOpen),
    );
  }
}

class _PlaylistTile extends StatefulWidget {
  const _PlaylistTile({required this.playlist, required this.onOpen});

  final MusicPlaylist playlist;
  final ValueChanged<MusicPlaylist> onOpen;

  @override
  State<_PlaylistTile> createState() => _PlaylistTileState();
}

class _PlaylistTileState extends State<_PlaylistTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final isDark = AppColors.isDark;

    final hasOverflow = playlist.name.characters.length > 10;
    final child = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () => widget.onOpen(playlist),
        child: AnimatedScale(
          scale: _pressed
              ? 0.96
              : _hovered
              ? 1.02
              : 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.primary.withValues(alpha: isDark ? 0.10 : 0.05)
                  : AppGlass.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _hovered
                    ? AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.18)
                    : AppGlass.border,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(
                          alpha: isDark ? 0.12 : 0.06,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : AppColors.isDark
                  ? null
                  : AppShadows.soft,
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: AnimatedScale(
                    scale: _hovered ? 1.05 : 1.0,
                    duration: AppMotion.fast,
                    curve: AppMotion.curve,
                    child: Container(
                      width: 52,
                      height: 52,
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
                              cacheWidth: (52 * pixelRatio).round(),
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.queue_music_rounded,
                                color: AppColors.muted,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                          color: _hovered
                              ? AppColors.primaryPressed
                              : AppColors.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${playlist.songCount} 首',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!hasOverflow) return child;

    return Tooltip(
      message: playlist.name,
      waitDuration: const Duration(milliseconds: 650),
      child: child,
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
            color: AppGlass.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppGlass.border),
          ),
        ),
      ),
    );
  }
}
