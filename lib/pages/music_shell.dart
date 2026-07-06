import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/auth_controller.dart';
import '../controllers/music_library_controller.dart';
import '../controllers/music_search_controller.dart';
import '../controllers/player_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/update_controller.dart';
import '../data/demo_music_repository.dart';
import '../data/kugou_music_repository.dart';
import '../data/music_repository.dart';
import '../models/song.dart';
import '../models/lyric.dart';
import '../models/music_playlist.dart';
import '../models/search_catalog_item.dart';
import '../models/app_update.dart';
import '../services/audio_player_service.dart';
import '../services/app_preferences_service.dart';
import '../services/cache_management_service.dart';
import '../services/kugou_api_client.dart';
import '../services/search_history_service.dart';
import '../services/recent_songs_service.dart';
import '../services/playback_state_service.dart';
import '../services/session_expired_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_window_caption.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/login_dialog.dart';
import '../widgets/now_playing_page.dart';
import '../widgets/play_queue_panel.dart';
import '../widgets/player_bar.dart';
import '../widgets/sidebar.dart';
import '../widgets/update_dialog.dart';
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

class _MusicShellState extends State<MusicShell>
    with WindowListener, TrayListener {
  final demoRepository = DemoMusicRepository();
  late final MusicRepository repository;
  KugouApiClient? apiClient;
  AuthController? authController;
  late final PlayerController playerController;
  late final MusicSearchController searchController;
  late final MusicLibraryController libraryController;
  late final UpdateController updateController;
  final cacheManagementService = CacheManagementService();
  final _preferences = AppPreferencesService();

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
  SearchCatalogItem? detailCatalogItem;
  String? detailIdentity;
  int detailSelectedTab = 0;
  final List<_DetailSnapshot> detailHistory = [];
  bool showQueuePanel = false;
  bool showNowPlayingPage = false;
  String? _activeUserId;
  bool _resettingAccountState = false;
  bool _showingUpdateDialog = false;
  bool _showingAuthExpiredDialog = false;
  bool _quittingFromTray = false;
  bool _closingWindow = false;
  bool _closeToTray = true;
  bool detailRelatedLoadingMore = false;
  bool detailRelatedHasMore = false;
  int detailRelatedPage = 1;
  final Map<String, List<LyricLine>> _lyricsCache = {};
  final Map<String, Future<List<LyricLine>>> _lyricsRequests = {};
  String? _lastPreloadedLyricKey;
  StreamSubscription<void>? _sessionExpiredSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.useDemoData) {
      repository = demoRepository;
    } else {
      apiClient = KugouApiClient();
      authController = AuthController(apiClient!)
        ..addListener(_handleAuthChanged);
      repository = KugouMusicRepository(apiClient!);
    }
    playerController = PlayerController(
      audioService: AudioPlayerService(enabled: widget.enableAudio),
      resolveSong: repository.resolvePlayback,
      recentSongsService: RecentSongsService(),
      playbackStateService: PlaybackStateService(),
    )..addListener(_handlePlayerChanged);
    searchController = MusicSearchController(
      repository: repository,
      historyService: SearchHistoryService(),
    )..addListener(_refresh);
    libraryController = MusicLibraryController(repository)
      ..addListener(_refresh);
    updateController = UpdateController()..addListener(_refresh);
    _loadWindowPreferences();
    searchController.initialize();
    playerController.initialize();
    _sessionExpiredSubscription = SessionExpiredService.stream.listen((_) {
      if (mounted) unawaited(_showAuthExpiredDialog());
    });
    if (Platform.isWindows && widget.enableWindowControls) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      unawaited(_setupWindowBehavior());
    }
    _initializeData();
  }

  Future<void> _initializeData() async {
    await updateController.initialize(useFallbackVersion: widget.useDemoData);
    unawaited(cacheManagementService.clearDownloadedInstallers());
    await libraryController.initialize();
    final auth = authController;
    if (auth != null) {
      await auth.initialize();
      _activeUserId = auth.isLoggedIn ? auth.session.userId : null;
      if (!auth.isLoggedIn) {
        await _resetAccountScopedData();
        return;
      }
    }
    await libraryController.ensureLoaded(LibrarySection.songs);
    unawaited(libraryController.refreshCachedInBackground());
    if (!widget.useDemoData && updateController.autoCheck) {
      unawaited(_checkForUpdates(silent: true));
    }
  }

  Future<void> _loadWindowPreferences() async {
    final value = await _preferences.read('closeToTray');
    if (!mounted) return;
    final closeToTray = value is bool ? value : false;
    setState(() => _closeToTray = closeToTray);
    await _applyCloseBehavior(closeToTray);
  }

  Future<void> _setCloseToTray(bool value) async {
    await _preferences.write('closeToTray', value);
    await _applyCloseBehavior(value);
    if (!mounted) return;
    setState(() => _closeToTray = value);
  }

  Future<void> _checkForUpdates({bool silent = false}) async {
    final result = await updateController.check(silent: silent);
    if (!mounted) return;
    if (silent && result.status != UpdateCheckStatus.available) return;
    await _showUpdateDialog();
  }

  Future<void> _showUpdateDialog() async {
    if (_showingUpdateDialog || !mounted) return;
    _showingUpdateDialog = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => UpdateDialog(controller: updateController),
      );
    } finally {
      _showingUpdateDialog = false;
    }
  }

  Future<void> _setupWindowBehavior() async {
    if (!Platform.isWindows) return;
    try {
      await _applyCloseBehavior(_closeToTray);
      await trayManager.setIcon(_trayIconPath(), iconSize: 16);
      await trayManager.setToolTip('晴听音乐');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: '显示窗口'),
            MenuItem.separator(),
            MenuItem(key: 'toggle-play', label: '播放/暂停'),
            MenuItem(key: 'previous', label: '上一首'),
            MenuItem(key: 'next', label: '下一首'),
            MenuItem.separator(),
            MenuItem(key: 'quit', label: '退出晴听音乐'),
          ],
        ),
      );
    } catch (_) {
      // Tray support is best-effort; the app should keep running without it.
    }
  }

  Future<void> _applyCloseBehavior(bool closeToTray) async {
    if (!Platform.isWindows || !widget.enableWindowControls) return;
    await windowManager.setPreventClose(closeToTray);
  }

  String _trayIconPath() {
    final executableDir = File(Platform.resolvedExecutable).parent;
    final bundled = File(
      '${executableDir.path}\\data\\flutter_assets\\windows\\runner\\resources\\app_icon.ico',
    );
    if (bundled.existsSync()) return bundled.path;
    return File('windows/runner/resources/app_icon.ico').absolute.path;
  }

  Future<void> _showWindow() async {
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    if (!await windowManager.isVisible()) {
      await windowManager.show();
    }
    await windowManager.focus();
  }

  @override
  void onWindowClose() {
    unawaited(_handleWindowClose());
  }

  Future<void> _handleWindowClose() async {
    if (!Platform.isWindows || !widget.enableWindowControls) return;
    if (!_closeToTray || _quittingFromTray) return;
    if (_closingWindow) return;
    _closingWindow = true;
    await windowManager.hide();
    _closingWindow = false;
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayIconRightMouseUp() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(_showWindow());
        break;
      case 'toggle-play':
        unawaited(playerController.togglePlay());
        break;
      case 'previous':
        unawaited(playerController.playPrevious());
        break;
      case 'next':
        unawaited(playerController.playNext());
        break;
      case 'quit':
        unawaited(_quitFromTray());
        break;
    }
  }

  Future<void> _quitFromTray() async {
    if (_closingWindow) return;
    _closingWindow = true;
    _quittingFromTray = true;
    await _destroyWindowAndTray();
  }

  Future<void> _destroyWindowAndTray() async {
    try {
      unawaited(playerController.flushPlaybackState());
      await windowManager.setPreventClose(false);
      unawaited(trayManager.destroy());
      await windowManager.close();
    } finally {
      _closingWindow = false;
    }
  }

  Future<void> _showAuthExpiredDialog() async {
    final auth = authController;
    if (_showingAuthExpiredDialog || auth == null) return;
    _showingAuthExpiredDialog = true;
    try {
      if (!mounted) return;
      final shouldLogin = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: const Text('登录已过期'),
          content: const Text('当前登录信息已失效，为了账号安全，请重新登录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('稍后再说'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('重新登录'),
            ),
          ],
        ),
      );
      if (!mounted || shouldLogin != true) return;
      await auth.logout();
      await _showLogin();
    } finally {
      _showingAuthExpiredDialog = false;
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _handlePlayerChanged() {
    final song = playerController.currentSong;
    final key = song == null ? null : _lyricCacheKey(song);
    if (song != null && key != null && key != _lastPreloadedLyricKey) {
      _lastPreloadedLyricKey = key;
      unawaited(_loadLyricsCached(song));
    }
    _refresh();
  }

  void _handleAuthChanged() {
    final auth = authController;
    final nextUserId = auth != null && auth.isLoggedIn
        ? auth.session.userId
        : null;
    final shouldReset =
        (_activeUserId != null && nextUserId == null) ||
        (_activeUserId != null &&
            nextUserId != null &&
            _activeUserId != nextUserId);
    _activeUserId = nextUserId;
    if (shouldReset) {
      unawaited(_resetAccountScopedData(reloadAfterLogin: nextUserId != null));
    }
    _refresh();
  }

  Future<void> _resetAccountScopedData({bool reloadAfterLogin = false}) async {
    if (_resettingAccountState) return;
    _resettingAccountState = true;
    try {
      await cacheManagementService.clearCache();
      await playerController.clearAccountState();
      searchController.clearAccountState();
      libraryController.clearAccountState();
      if (!mounted) return;
      setState(() {
        detailTitle = null;
        detailSubtitle = null;
        detailImageUrl = null;
        detailSongs = [];
        detailRelatedItems = [];
        detailRelatedLoadingMore = false;
        detailRelatedHasMore = false;
        detailRelatedPage = 1;
        detailLoading = false;
        detailPlaylist = null;
        detailCatalogItem = null;
        detailIdentity = null;
        detailSelectedTab = 0;
        detailHistory.clear();
        showNowPlayingPage = false;
      });
      if (reloadAfterLogin) {
        await libraryController.ensureLoaded(
          LibrarySection.songs,
          refresh: true,
        );
        unawaited(libraryController.refreshCachedInBackground());
      }
    } finally {
      _resettingAccountState = false;
    }
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
      detailRelatedLoadingMore = false;
      detailRelatedHasMore = false;
      detailRelatedPage = 1;
      detailLoading = true;
      detailKind = item.category == SearchCategory.artist
          ? CollectionDetailKind.artist
          : item.category == SearchCategory.playlist
          ? CollectionDetailKind.playlist
          : CollectionDetailKind.album;
      detailPlaylist = null;
      detailCatalogItem = item;
      detailIdentity = identity;
      detailSelectedTab = 0;
    });
    try {
      final results = await Future.wait<Object>([
        repository.getCatalogSongs(item),
        if (item.category == SearchCategory.artist)
          repository.getArtistAlbumsPage(item, page: 1)
        else
          Future<List<SearchCatalogItem>>.value([]),
      ]);
      if (!mounted) return;
      setState(() {
        detailSongs = (results[0] as List<Song>)
            .map(libraryController.withFavoriteState)
            .toList();
        detailRelatedItems = results[1] as List<SearchCatalogItem>;
        detailRelatedPage = 1;
        detailRelatedHasMore =
            item.category == SearchCategory.artist &&
            detailRelatedItems.isNotEmpty;
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

  Future<void> _loadMoreArtistAlbums() async {
    final item = detailCatalogItem;
    if (item == null ||
        item.category != SearchCategory.artist ||
        detailRelatedLoadingMore ||
        !detailRelatedHasMore) {
      return;
    }
    setState(() => detailRelatedLoadingMore = true);
    try {
      final nextPage = detailRelatedPage + 1;
      final more = await repository.getArtistAlbumsPage(item, page: nextPage);
      if (!mounted) return;
      setState(() {
        final beforeCount = detailRelatedItems.length;
        final merged = _mergeCatalogItems(detailRelatedItems, more);
        detailRelatedPage = nextPage;
        detailRelatedHasMore = more.isNotEmpty && merged.length > beforeCount;
        detailRelatedItems = merged;
        detailRelatedLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        detailRelatedHasMore = false;
        detailRelatedLoadingMore = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  List<SearchCatalogItem> _mergeCatalogItems(
    List<SearchCatalogItem> current,
    List<SearchCatalogItem> incoming,
  ) {
    final merged = <SearchCatalogItem>[];
    final seen = <String>{};
    for (final item in [...current, ...incoming]) {
      final key = item.id.isNotEmpty ? item.id : item.title;
      if (seen.add(key)) merged.add(item);
    }
    return merged;
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
      detailRelatedLoadingMore = false;
      detailRelatedHasMore = false;
      detailRelatedPage = 1;
      detailLoading = true;
      detailKind = playlist.kind == MusicPlaylistKind.album
          ? CollectionDetailKind.album
          : CollectionDetailKind.playlist;
      detailPlaylist = playlist;
      detailCatalogItem =
          playlist.kind == MusicPlaylistKind.collectedPlaylist ||
              playlist.kind == MusicPlaylistKind.album
          ? _catalogFromPlaylist(playlist)
          : null;
      detailIdentity = identity;
      detailSelectedTab = 0;
    });
    try {
      final songs = await libraryController.loadPlaylist(playlist);
      if (!mounted) return;
      setState(() {
        detailSongs = songs.map(libraryController.withFavoriteState).toList();
        if (songs.isNotEmpty) {
          detailSubtitle = '${songs.length} 首歌曲';
        }
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
    await _openArtistByName(artistName, artistId: song.artistId);
  }

  Future<void> _openArtistByName(String artistName, {int? artistId}) async {
    final cleanName = _navigableArtistName(artistName);
    if (cleanName == null) return;
    var id = artistId?.toString() ?? '';
    String? image;
    if (id.isEmpty) {
      final matches = await repository.searchCatalog(
        cleanName,
        SearchCategory.artist,
      );
      if (matches.isNotEmpty) {
        id = matches.first.id;
        image = matches.first.imageUrl;
      }
    } else {
      final matches = await repository.searchCatalog(
        cleanName,
        SearchCategory.artist,
      );
      if (matches.isNotEmpty) image = matches.first.imageUrl;
    }
    if (id.isEmpty) return;
    await _openCatalog(
      SearchCatalogItem(
        id: id,
        title: cleanName,
        subtitle: '歌手',
        category: SearchCategory.artist,
        imageUrl: image,
      ),
    );
  }

  Future<List<LyricLine>> _loadLyricsCached(Song song) {
    final key = _lyricCacheKey(song);
    final cached = _lyricsCache[key];
    if (cached != null) return Future.value(cached);
    final pending = _lyricsRequests[key];
    if (pending != null) return pending;
    final request = repository
        .getLyrics(song)
        .then((lines) {
          _lyricsCache[key] = lines;
          _lyricsRequests.remove(key);
          return lines;
        })
        .catchError((Object error) {
          _lyricsRequests.remove(key);
          throw error;
        });
    _lyricsRequests[key] = request;
    return request;
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
        listId: id,
      ),
    );
  }

  Future<void> _toggleCatalogCollection(SearchCatalogItem item) async {
    try {
      final wasCollected = libraryController.isCatalogCollected(item);
      await libraryController.toggleCatalogCollection(item);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(wasCollected ? '已取消收藏' : '已收藏')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  SearchCatalogItem _catalogFromPlaylist(MusicPlaylist playlist) {
    return SearchCatalogItem(
      id: playlist.id,
      title: playlist.name,
      subtitle: '${playlist.songCount} 首歌曲',
      category: playlist.kind == MusicPlaylistKind.album
          ? SearchCategory.album
          : SearchCategory.playlist,
      imageUrl: playlist.coverUrl,
      listId: playlist.listId,
    );
  }

  Future<void> _openAlbumFromNowPlaying(Song song) async {
    setState(() => showNowPlayingPage = false);
    await _openAlbumFromSong(song);
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
        relatedPage: detailRelatedPage,
        relatedHasMore: detailRelatedHasMore,
        relatedLoadingMore: detailRelatedLoadingMore,
        isLoading: detailLoading,
        kind: detailKind,
        playlist: detailPlaylist,
        catalogItem: detailCatalogItem,
        selectedTab: detailSelectedTab,
      ),
    );
  }

  void _popDetail() {
    if (detailHistory.isEmpty) {
      setState(() {
        detailTitle = null;
        detailPlaylist = null;
        detailCatalogItem = null;
        detailIdentity = null;
        detailSelectedTab = 0;
        detailRelatedLoadingMore = false;
        detailRelatedHasMore = false;
        detailRelatedPage = 1;
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
      detailRelatedPage = previous.relatedPage;
      detailRelatedHasMore = previous.relatedHasMore;
      detailRelatedLoadingMore = previous.relatedLoadingMore;
      detailLoading = previous.isLoading;
      detailKind = previous.kind;
      detailPlaylist = previous.playlist;
      detailCatalogItem = previous.catalogItem;
      detailSelectedTab = previous.selectedTab;
    });
  }

  @override
  void dispose() {
    _sessionExpiredSubscription?.cancel();
    if (Platform.isWindows && widget.enableWindowControls) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    playerController
      ..removeListener(_handlePlayerChanged)
      ..dispose();
    searchController
      ..removeListener(_refresh)
      ..dispose();
    libraryController
      ..removeListener(_refresh)
      ..dispose();
    updateController
      ..removeListener(_refresh)
      ..dispose();
    authController
      ?..removeListener(_handleAuthChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compactSidebar = constraints.maxWidth < 1050;
          final sidebarWidth = compactSidebar ? 76.0 : 214.0;
          return Stack(
            children: [
              Column(
                children: [
                  AppWindowCaption(
                    enabled: widget.enableWindowControls,
                    sidebarWidth: sidebarWidth,
                  ),
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
                              detailCatalogItem = null;
                              detailIdentity = null;
                              detailSelectedTab = 0;
                              detailHistory.clear();
                              showNowPlayingPage = false;
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
                    onNowPlayingPressed: playerController.currentSong == null
                        ? null
                        : () => setState(() => showNowPlayingPage = true),
                    onOpenAlbum: _openAlbumFromSong,
                    onOpenArtist: _openArtistFromSong,
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
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !showNowPlayingPage,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    reverseDuration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.985,
                            end: 1,
                          ).animate(curved),
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.045),
                              end: Offset.zero,
                            ).animate(curved),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: showNowPlayingPage
                        ? NowPlayingPage(
                            key: const ValueKey('now-playing-page'),
                            controller: playerController,
                            onClose: () =>
                                setState(() => showNowPlayingPage = false),
                            loadLyrics: _loadLyricsCached,
                            onLike: _toggleFavorite,
                            onAddToPlaylist: _showAddToPlaylist,
                            onOpenAlbum: _openAlbumFromNowPlaying,
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('now-playing-empty'),
                          ),
                  ),
                ),
              ),
              if (showNowPlayingPage)
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !widget.enableWindowControls,
                    child: AppWindowCaption(
                      enabled: widget.enableWindowControls,
                      backgroundColor: Colors.transparent,
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
      final isCollected = detailCatalogItem == null
          ? false
          : libraryController.isCatalogCollected(detailCatalogItem!);
      final collectionItem = detailCatalogItem?.category == SearchCategory.album
          ? null
          : detailCatalogItem;
      return CollectionDetailPage(
        key: ValueKey(detailIdentity ?? '$detailKind:$detailTitle'),
        kind: detailKind,
        title: detailTitle!,
        subtitle: detailSubtitle ?? '',
        imageUrl: detailImageUrl,
        songs: detailSongs,
        relatedItems: detailRelatedItems,
        relatedItemsLoadingMore: detailRelatedLoadingMore,
        relatedItemsCanLoadMore: detailRelatedHasMore,
        onLoadMoreRelatedItems: _loadMoreArtistAlbums,
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
        onOpenHeaderArtist:
            detailKind == CollectionDetailKind.album &&
                (detailSubtitle ?? '').trim().isNotEmpty
            ? () => _openArtistByName(detailSubtitle!.trim())
            : null,
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
        collectionItem: collectionItem,
        isCollected: isCollected,
        onToggleCollection: collectionItem == null
            ? null
            : () => _toggleCatalogCollection(collectionItem),
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
        updateController: updateController,
        onCheckUpdates: () => _checkForUpdates(),
        closeToTray: _closeToTray,
        onCloseToTrayChanged: _setCloseToTray,
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

String _lyricCacheKey(Song song) {
  final hash = song.hash?.trim();
  if (hash != null && hash.isNotEmpty) return 'hash:$hash';
  return 'id:${song.id}';
}

class _DetailSnapshot {
  const _DetailSnapshot({
    required this.identity,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.songs,
    required this.relatedItems,
    required this.relatedPage,
    required this.relatedHasMore,
    required this.relatedLoadingMore,
    required this.isLoading,
    required this.kind,
    required this.playlist,
    required this.catalogItem,
    required this.selectedTab,
  });

  final String? identity;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final List<Song> songs;
  final List<SearchCatalogItem> relatedItems;
  final int relatedPage;
  final bool relatedHasMore;
  final bool relatedLoadingMore;
  final bool isLoading;
  final CollectionDetailKind kind;
  final MusicPlaylist? playlist;
  final SearchCatalogItem? catalogItem;
  final int selectedTab;
}
