import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../controllers/music_library_controller.dart';
import '../controllers/music_search_controller.dart';
import '../controllers/player_controller.dart';
import '../controllers/theme_controller.dart';
import '../data/demo_music_repository.dart';
import '../data/kugou_music_repository.dart';
import '../data/music_repository.dart';
import '../models/song.dart';
import '../models/music_playlist.dart';
import '../models/search_catalog_item.dart';
import '../services/audio_player_service.dart';
import '../services/kugou_api_client.dart';
import '../services/search_history_service.dart';
import '../services/recent_songs_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_window_caption.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/login_dialog.dart';
import '../widgets/play_queue_panel.dart';
import '../widgets/player_bar.dart';
import '../widgets/sidebar.dart';
import 'library_page.dart';
import 'collection_detail_page.dart';
import 'search_page.dart';
import 'settings_page.dart';

class MusicShell extends StatefulWidget {
  const MusicShell({
    super.key,
    required this.enableAudio,
    required this.enableWindowControls,
    required this.useDemoData,
    required this.themeController,
  });

  final bool enableAudio;
  final bool enableWindowControls;
  final bool useDemoData;
  final ThemeController themeController;

  @override
  State<MusicShell> createState() => _MusicShellState();
}

class _MusicShellState extends State<MusicShell> {
  final demoRepository = DemoMusicRepository();
  late final MusicRepository repository;
  KugouApiClient? apiClient;
  AuthController? authController;
  late final PlayerController playerController;
  late final MusicSearchController searchController;
  late final MusicLibraryController libraryController;

  int selectedIndex = 0;
  int librarySelectedTab = 0;
  String? detailTitle;
  String? detailSubtitle;
  String? detailImageUrl;
  List<Song> detailSongs = [];
  List<SearchCatalogItem> detailRelatedItems = [];
  bool detailLoading = false;
  CollectionDetailKind detailKind = CollectionDetailKind.playlist;
  MusicPlaylist? detailPlaylist;
  String? detailIdentity;
  int detailSelectedTab = 0;
  final List<_DetailSnapshot> detailHistory = [];
  bool showQueuePanel = false;

  @override
  void initState() {
    super.initState();
    if (widget.useDemoData) {
      repository = demoRepository;
    } else {
      apiClient = KugouApiClient();
      authController = AuthController(apiClient!)..addListener(_refresh);
      repository = KugouMusicRepository(apiClient!);
    }
    playerController = PlayerController(
      audioService: AudioPlayerService(enabled: widget.enableAudio),
      resolveSong: repository.resolvePlayback,
      recentSongsService: RecentSongsService(),
    )..addListener(_refresh);
    searchController = MusicSearchController(
      repository: repository,
      historyService: SearchHistoryService(),
    )..addListener(_refresh);
    libraryController = MusicLibraryController(repository)
      ..addListener(_refresh);
    searchController.initialize();
    playerController.initialize();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await libraryController.initialize();
    final auth = authController;
    if (auth != null) {
      await auth.initialize();
      if (!auth.isLoggedIn) return;
    }
    await libraryController.ensureLoaded(LibrarySection.songs);
    unawaited(libraryController.refreshCachedInBackground());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _playSong(Song song, List<Song> sourceQueue) async {
    if (playerController.currentSong?.id == song.id &&
        playerController.isPlaying) {
      await playerController.togglePlay();
      return;
    }
    final queue = sourceQueue.any((item) => item.id == song.id)
        ? sourceQueue
        : [song];
    await playerController.playSong(song, fromQueue: queue);
  }

  Future<void> _showLogin() async {
    final controller = authController;
    if (controller == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => LoginDialog(controller: controller),
    );
    if (controller.isLoggedIn) {
      await libraryController.ensureLoaded(LibrarySection.songs, refresh: true);
    }
  }

  Future<void> _handleAccountEntry() async {
    final auth = authController;
    if (auth == null || !auth.isLoggedIn) {
      await _showLogin();
      return;
    }
    if (auth.vipClaimState != VipClaimState.claimed &&
        auth.vipClaimState != VipClaimState.checking) {
      await auth.ensureDailyVip();
      return;
    }
    await _showLogin();
  }

  Future<void> _toggleFavorite(Song song) async {
    try {
      await libraryController.toggleFavorite(song);
      detailSongs = detailSongs
          .map(
            (item) => item.id == song.id
                ? item.copyWith(liked: libraryController.isFavorite(item))
                : item,
          )
          .toList();
      searchController.results = searchController.results
          .map(
            (item) => item.id == song.id
                ? item.copyWith(liked: libraryController.isFavorite(item))
                : item,
          )
          .toList();
      playerController.updateSongFavorite(
        song,
        libraryController.isFavorite(song),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openCatalog(SearchCatalogItem item) async {
    final identity = 'catalog:${item.category.name}:${item.id}';
    if (detailIdentity == identity) return;
    setState(() {
      _pushCurrentDetail();
      detailTitle = item.title;
      detailSubtitle = item.subtitle;
      detailImageUrl = item.imageUrl;
      detailSongs = [];
      detailRelatedItems = [];
      detailLoading = true;
      detailKind = item.category == SearchCategory.artist
          ? CollectionDetailKind.artist
          : CollectionDetailKind.album;
      detailPlaylist = null;
      detailIdentity = identity;
      detailSelectedTab = 0;
    });
    try {
      final results = await Future.wait<Object>([
        repository.getCatalogSongs(item),
        if (item.category == SearchCategory.artist)
          repository.getArtistAlbums(item)
        else
          Future<List<SearchCatalogItem>>.value([]),
      ]);
      if (!mounted) return;
      setState(() {
        detailSongs = (results[0] as List<Song>)
            .map(libraryController.withFavoriteState)
            .toList();
        detailRelatedItems = results[1] as List<SearchCatalogItem>;
        detailLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => detailLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openPlaylist(MusicPlaylist playlist) async {
    final identity = 'playlist:${playlist.kind.name}:${playlist.id}';
    if (detailIdentity == identity) return;
    setState(() {
      _pushCurrentDetail();
      detailTitle = playlist.name;
      detailSubtitle = '${playlist.songCount} 首歌曲';
      detailImageUrl = playlist.coverUrl;
      detailSongs = [];
      detailRelatedItems = [];
      detailLoading = true;
      detailKind = playlist.kind == MusicPlaylistKind.album
          ? CollectionDetailKind.album
          : CollectionDetailKind.playlist;
      detailPlaylist = playlist;
      detailIdentity = identity;
      detailSelectedTab = 0;
    });
    try {
      final songs = await libraryController.loadPlaylist(playlist);
      if (!mounted) return;
      setState(() {
        detailSongs = songs.map(libraryController.withFavoriteState).toList();
        detailLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => detailLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openArtistFromSong(Song song) async {
    final artistName = _navigableArtistName(song.artist);
    if (artistName == null) return;
    var id = song.artistId?.toString() ?? '';
    String? image = song.coverUrl;
    if (id.isEmpty) {
      final matches = await repository.searchCatalog(
        artistName,
        SearchCategory.artist,
      );
      if (matches.isNotEmpty) {
        id = matches.first.id;
        image = matches.first.imageUrl;
      }
    }
    if (id.isEmpty) return;
    await _openCatalog(
      SearchCatalogItem(
        id: id,
        title: artistName,
        subtitle: '歌手',
        category: SearchCategory.artist,
        imageUrl: image,
      ),
    );
  }

  Future<void> _showAddToPlaylist(Song song) async {
    try {
      if (authController != null && !authController!.isLoggedIn) {
        await _showLogin();
        if (authController != null && !authController!.isLoggedIn) return;
      }
      await libraryController.ensureLoaded(LibrarySection.playlists);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AddToPlaylistDialog(
          song: song,
          playlists: libraryController.editablePlaylists,
          onSelected: (playlist) {
            unawaited(_addToPlaylist(playlist, song));
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _addToPlaylist(MusicPlaylist playlist, Song song) async {
    try {
      await libraryController.addToPlaylist(playlist, song);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加到 ${playlist.name}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _removeFromDetailPlaylist(Song song) async {
    final playlist = detailPlaylist;
    if (playlist == null) return;
    try {
      await libraryController.removeFromPlaylist(playlist, song);
      setState(() {
        detailSongs = detailSongs.where((item) => item.id != song.id).toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openAlbumFromSong(Song song) async {
    var id = song.albumId?.toString() ?? '';
    String? image = song.coverUrl;
    if (id.isEmpty) {
      final matches = await repository.searchCatalog(
        song.album,
        SearchCategory.album,
      );
      if (matches.isNotEmpty) {
        id = matches.first.id;
        image = matches.first.imageUrl;
      }
    }
    if (id.isEmpty) return;
    await _openCatalog(
      SearchCatalogItem(
        id: id,
        title: song.album,
        subtitle: song.artist,
        category: SearchCategory.album,
        imageUrl: image,
      ),
    );
  }

  void _pushCurrentDetail() {
    if (detailTitle == null) return;
    detailHistory.add(
      _DetailSnapshot(
        identity: detailIdentity,
        title: detailTitle!,
        subtitle: detailSubtitle,
        imageUrl: detailImageUrl,
        songs: detailSongs,
        relatedItems: detailRelatedItems,
        isLoading: detailLoading,
        kind: detailKind,
        playlist: detailPlaylist,
        selectedTab: detailSelectedTab,
      ),
    );
  }

  void _popDetail() {
    if (detailHistory.isEmpty) {
      setState(() {
        detailTitle = null;
        detailPlaylist = null;
        detailIdentity = null;
        detailSelectedTab = 0;
      });
      return;
    }
    final previous = detailHistory.removeLast();
    setState(() {
      detailIdentity = previous.identity;
      detailTitle = previous.title;
      detailSubtitle = previous.subtitle;
      detailImageUrl = previous.imageUrl;
      detailSongs = previous.songs;
      detailRelatedItems = previous.relatedItems;
      detailLoading = previous.isLoading;
      detailKind = previous.kind;
      detailPlaylist = previous.playlist;
      detailSelectedTab = previous.selectedTab;
    });
  }

  @override
  void dispose() {
    playerController
      ..removeListener(_refresh)
      ..dispose();
    searchController
      ..removeListener(_refresh)
      ..dispose();
    libraryController
      ..removeListener(_refresh)
      ..dispose();
    authController
      ?..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compactSidebar = constraints.maxWidth < 1050;
          return Stack(
            children: [
              Column(
                children: [
                  AppWindowCaption(enabled: widget.enableWindowControls),
                  Expanded(
                    child: Row(
                      children: [
                        AppSidebar(
                          compact: compactSidebar,
                          selectedIndex: selectedIndex,
                          onChanged: (index) {
                            setState(() {
                              selectedIndex = index;
                              detailTitle = null;
                              detailPlaylist = null;
                              detailIdentity = null;
                              detailSelectedTab = 0;
                              detailHistory.clear();
                            });
                          },
                          loginLabel:
                              authController?.session.displayName ?? '演示模式',
                          isLoggedIn: authController?.isLoggedIn ?? false,
                          vipTooltip: _vipTooltip,
                          onLogin: _handleAccountEntry,
                          isDark: widget.themeController.isDark,
                          onToggleTheme: widget.themeController.toggle,
                        ),
                        VerticalDivider(width: 1),
                        Expanded(
                          child: ColoredBox(
                            color: AppColors.page,
                            child: _selectedPage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PlayerBar(
                    controller: playerController,
                    onLike: _toggleFavorite,
                    onAddToPlaylist: _showAddToPlaylist,
                    onQueuePressed: () {
                      setState(() => showQueuePanel = !showQueuePanel);
                    },
                  ),
                ],
              ),
              if (showQueuePanel)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => showQueuePanel = false),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.18),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {},
                          child: PlayQueuePanel(
                            controller: playerController,
                            onClose: () =>
                                setState(() => showQueuePanel = false),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _selectedPage() {
    if (detailTitle != null) {
      return CollectionDetailPage(
        key: ValueKey(detailIdentity ?? '$detailKind:$detailTitle'),
        kind: detailKind,
        title: detailTitle!,
        subtitle: detailSubtitle ?? '',
        imageUrl: detailImageUrl,
        songs: detailSongs,
        relatedItems: detailRelatedItems,
        isLoading: detailLoading,
        currentSong: playerController.currentSong,
        isPlaying: playerController.isPlaying,
        selectedTab: detailSelectedTab,
        onTabChanged: (index) => setState(() => detailSelectedTab = index),
        storageKeyPrefix: detailIdentity ?? '$detailKind:$detailTitle',
        openedFromArtist:
            detailKind == CollectionDetailKind.album &&
            detailHistory.isNotEmpty &&
            detailHistory.last.kind == CollectionDetailKind.artist,
        onBack: _popDetail,
        onPlay: _playSong,
        onLike: _toggleFavorite,
        onAddToPlaylist: _showAddToPlaylist,
        onRemoveFromPlaylist:
            detailPlaylist?.kind == MusicPlaylistKind.createdPlaylist
            ? _removeFromDetailPlaylist
            : null,
        onOpenArtist: _openArtistFromSong,
        onOpenAlbum: _openAlbumFromSong,
        onOpenCatalog: _openCatalog,
      );
    }
    return switch (selectedIndex) {
      0 => LibraryPage(
        controller: libraryController,
        recentSongs: playerController.recentSongs,
        currentSong: playerController.currentSong,
        isPlaying: playerController.isPlaying,
        onPlay: _playSong,
        onLike: _toggleFavorite,
        onAddToPlaylist: _showAddToPlaylist,
        onOpenArtist: _openArtistFromSong,
        onOpenAlbum: _openAlbumFromSong,
        onOpenPlaylist: _openPlaylist,
        onOpenCatalog: _openCatalog,
        onLogin: _showLogin,
        selectedTab: librarySelectedTab,
        onTabChanged: (index) => setState(() => librarySelectedTab = index),
      ),
      1 => SearchPage(
        controller: searchController,
        currentSong: playerController.currentSong,
        isPlaying: playerController.isPlaying,
        onPlay: _playSong,
        onLogin: _showLogin,
        onOpenCatalog: _openCatalog,
        onLike: _toggleFavorite,
        onAddToPlaylist: _showAddToPlaylist,
        onOpenArtist: _openArtistFromSong,
        onOpenAlbum: _openAlbumFromSong,
      ),
      _ => SettingsPage(
        onEndpointChanged: () {
          libraryController.invalidateLoadedState();
          searchController.invalidateCachedResults();
          unawaited(libraryController.ensureLoaded(LibrarySection.songs));
        },
      ),
    };
  }

  String get _vipTooltip {
    final auth = authController;
    if (auth == null || !auth.isLoggedIn) return '登录后自动领取每日 VIP';
    return switch (auth.vipClaimState) {
      VipClaimState.checking => '正在检查今日 VIP',
      VipClaimState.claimed => auth.vipClaimMessage ?? '今日 VIP 已领取',
      VipClaimState.failed => auth.vipClaimMessage ?? 'VIP 状态稍后重试',
      VipClaimState.idle => auth.vipClaimMessage ?? '今日 VIP 未领取',
    };
  }
}

String? _navigableArtistName(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'^[\s/\\|,，、]+|[\s/\\|,，、]+$'), '')
      .trim();
  if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(cleaned)) return null;
  final lower = cleaned.toLowerCase();
  if (lower == '未知歌手' ||
      lower == 'unknown' ||
      lower == 'unknown artist' ||
      lower == 'null' ||
      cleaned == '群星') {
    return null;
  }
  return cleaned;
}

class _DetailSnapshot {
  const _DetailSnapshot({
    required this.identity,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.songs,
    required this.relatedItems,
    required this.isLoading,
    required this.kind,
    required this.playlist,
    required this.selectedTab,
  });

  final String? identity;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final List<Song> songs;
  final List<SearchCatalogItem> relatedItems;
  final bool isLoading;
  final CollectionDetailKind kind;
  final MusicPlaylist? playlist;
  final int selectedTab;
}
