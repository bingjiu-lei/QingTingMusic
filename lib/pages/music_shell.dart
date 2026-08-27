import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/auth_controller.dart';
import '../controllers/music_library_controller.dart';
import '../controllers/music_search_controller.dart';
import '../controllers/player_controller.dart';
import '../controllers/playback_quality_controller.dart';
import '../controllers/recommendation_controller.dart';
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
import '../services/cover_palette_service.dart';
import '../services/developer_mode_service.dart';
import '../services/kugou_api_client.dart';
import '../services/search_history_service.dart';
import '../services/recent_songs_service.dart';
import '../services/playback_state_service.dart';
import '../services/session_expired_service.dart';
import '../services/windows_media_bridge.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_window_caption.dart';
import '../widgets/app_notice.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/async_operation_overlay.dart';
import '../widgets/login_dialog.dart';
import '../widgets/now_playing_page.dart';
import '../widgets/play_queue_panel.dart';
import '../widgets/player_bar.dart';
import '../widgets/sidebar.dart';
import '../widgets/update_dialog.dart';
import 'library_page.dart';
import 'collection_detail_page.dart';
import 'search_page.dart';
import 'recommendation_page.dart';
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
  late final PlaybackQualityController playbackQualityController;
  late final MusicSearchController searchController;
  late final MusicLibraryController libraryController;
  late final RecommendationController recommendationController;
  late final UpdateController updateController;
  final cacheManagementService = CacheManagementService();

  bool _sidebarExpanded = true;
  final _developerModeService = DeveloperModeService();
  final _preferences = AppPreferencesService();
  final _windowsMediaBridge = WindowsMediaBridge();

  int selectedIndex = 0;
  int librarySelectedTab = 0;
  String? detailTitle;
  String? detailSubtitle;
  String? detailHeaderArtistName;
  String? detailImageUrl;
  List<Song> detailSongs = [];
  List<SearchCatalogItem> detailRelatedItems = [];
  List<SearchCatalogItem> detailSimilarArtists = [];
  bool detailLoading = false;
  CollectionDetailKind detailKind = CollectionDetailKind.playlist;
  MusicPlaylist? detailPlaylist;
  SearchCatalogItem? detailCatalogItem;
  String? detailIdentity;
  String? detailStorageKeyPrefix;
  int _detailStorageEpoch = 0;
  int detailSelectedTab = 0;
  final List<_DetailSnapshot> detailHistory = [];
  bool showQueuePanel = false;
  bool showNowPlayingPage = false;
  bool _showLyricTranslation = true;
  bool _showLyricTransliteration = false;
  bool _desktopLyricsVisible = false;
  bool _desktopLyricsLocked = false;
  double _desktopLyricsFontSize = 28;
  Timer? _desktopLyricsTimer;
  bool _desktopLyricsSyncing = false;
  String? _lastCoverAccentSongId;
  bool _isFmSession = false;
  String? _lastFmSyncSongId;
  PlaybackMode? _playbackModeBeforeFm;
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
  String? _lastShellSongId;
  bool _lastShellPlaying = false;
  StreamSubscription<void>? _sessionExpiredSubscription;
  final Set<String> _favoriteUpdates = <String>{};
  bool _playlistOperationBusy = false;
  bool _playlistOperationIndicatorVisible = false;
  String _playlistOperationMessage = '正在准备歌单…';
  AppNoticeData? _notice;
  Timer? _noticeTimer;
  int _noticeId = 0;

  @override
  void initState() {
    super.initState();
    widget.themeController.addListener(_handleThemeChanged);
    playbackQualityController = PlaybackQualityController()
      ..addListener(_refresh);
    if (widget.useDemoData) {
      repository = demoRepository;
    } else {
      apiClient = KugouApiClient(
        playbackQualityController: playbackQualityController,
      );
      authController = AuthController(apiClient!)
        ..addListener(_handleAuthChanged);
      repository = KugouMusicRepository(apiClient!);
    }
    playerController = PlayerController(
      audioService: AudioPlayerService(enabled: widget.enableAudio),
      resolveSong: repository.resolvePlayback,
      recentSongsService: RecentSongsService(),
      playbackStateService: PlaybackStateService(),
      repository: repository,
    )..addListener(_handlePlayerChanged);
    playerController.progress.addListener(_handlePlayerProgress);
    if (Platform.isWindows && widget.enableWindowControls) {
      unawaited(
        _windowsMediaBridge.initialize(
          onPrevious: playerController.playPrevious,
          onTogglePlay: playerController.togglePlay,
          onNext: playerController.playNext,
          onDesktopLyricsClosed: () async {
            if (mounted) setState(() => _desktopLyricsVisible = false);
          },
          onDesktopLyricsLockChanged: (locked) async {
            if (!mounted) return;
            setState(() => _desktopLyricsLocked = locked);
            await _preferences.write('desktopLyricsLocked', locked);
          },
          onDesktopLyricsFontSizeChanged: (fontSize) async {
            if (!mounted) return;
            final value = fontSize.clamp(20.0, 44.0);
            setState(() => _desktopLyricsFontSize = value);
            await _preferences.write('desktopLyricsFontSize', value);
          },
        ),
      );
    }
    if (Platform.isWindows && widget.enableWindowControls) {
      unawaited(_loadDesktopLyricsPreferences());
    }
    // SearchPage 直接监听 searchController。让搜索输入和联想结果只刷新
    // 搜索页，避免拼音输入期间由外层 Shell 的整页重建干扰 Windows IME。
    searchController = MusicSearchController(
      repository: repository,
      historyService: SearchHistoryService(),
    );
    libraryController = MusicLibraryController(repository)
      ..addListener(_refresh);
    recommendationController = RecommendationController(repository)
      ..addListener(_refresh);
    updateController = UpdateController()..addListener(_refresh);
    _loadWindowPreferences();
    _loadDeveloperMode();
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
    await playbackQualityController.initialize();
    await updateController.initialize(useFallbackVersion: widget.useDemoData);
    unawaited(cacheManagementService.clearDownloadedInstallers());
    await libraryController.initialize();
    final auth = authController;
    if (auth != null) {
      await auth.initialize();
      _activeUserId = auth.isLoggedIn ? auth.session.userId : null;
      if (!auth.isLoggedIn) {
        await _resetAccountScopedData();
        if (mounted && !widget.useDemoData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !(authController?.isLoggedIn ?? false)) {
              unawaited(_showLogin());
            }
          });
        }
        return;
      }
    }
    await libraryController.ensureLoaded(LibrarySection.songs);
    unawaited(libraryController.refreshCachedInBackground());
    unawaited(recommendationController.loadDaily());
    if (!widget.useDemoData && updateController.autoCheck) {
      unawaited(_checkForUpdates(silent: true));
    }
  }

  Future<void> _loadWindowPreferences() async {
    final values = await Future.wait<Object?>([
      _preferences.read('closeToTray'),
      _preferences.read('sidebarExpanded'),
    ]);
    if (!mounted) return;
    final closeToTray = values[0] is bool ? values[0] as bool : false;
    final sidebarExpanded = values[1] is bool ? values[1] as bool : true;
    setState(() {
      _closeToTray = closeToTray;
      _sidebarExpanded = sidebarExpanded;
    });
    await _applyCloseBehavior(closeToTray);
  }

  Future<void> _setSidebarExpanded(bool value) async {
    setState(() => _sidebarExpanded = value);
    await _preferences.write('sidebarExpanded', value);
  }

  Future<void> _loadDesktopLyricsPreferences() async {
    final values = await Future.wait<Object?>([
      _preferences.read('desktopLyricsLocked'),
      _preferences.read('desktopLyricsFontSize'),
    ]);
    final locked = values[0] is bool ? values[0] as bool : false;
    final rawFontSize = values[1];
    final fontSize = rawFontSize is num
        ? rawFontSize.toDouble().clamp(20.0, 44.0)
        : 28.0;
    if (!mounted) return;
    setState(() {
      _desktopLyricsLocked = locked;
      _desktopLyricsFontSize = fontSize;
    });
    try {
      await _windowsMediaBridge.setDesktopLyricsLocked(locked);
      await _windowsMediaBridge.setDesktopLyricsFontSize(fontSize);
    } catch (_) {
      // The native window may not have been created yet; the next explicit
      // desktop-lyrics toggle will push the persisted values again.
    }
  }

  void _handleThemeChanged() {
    if (widget.themeController.coverAccentEnabled) {
      unawaited(_syncCoverAccent(force: true));
    } else {
      _lastCoverAccentSongId = null;
    }
    _scheduleDesktopLyricsSync(immediate: true);
    _refresh();
  }

  Future<void> _syncCoverAccent({bool force = false}) async {
    final theme = widget.themeController;
    if (!theme.coverAccentEnabled) return;
    final song = playerController.currentSong;
    final cover = song?.coverUrl?.trim() ?? '';
    final identity = song == null ? null : '${song.id}|$cover';
    if (!force && identity == _lastCoverAccentSongId) return;
    _lastCoverAccentSongId = identity;
    if (cover.isEmpty) {
      theme.applyCoverAccent(null);
      return;
    }
    final color = await CoverPaletteService.colorFor(cover);
    if (playerController.currentSong?.id != song?.id ||
        !theme.coverAccentEnabled) {
      return;
    }
    theme.applyCoverAccent(color);
  }

  Future<void> _setCloseToTray(bool value) async {
    await _preferences.write('closeToTray', value);
    await _applyCloseBehavior(value);
    if (!mounted) return;
    setState(() => _closeToTray = value);
  }

  Future<void> _loadDeveloperMode() async {
    final enabled = await _developerModeService.loadEnabled();
    if (!mounted) return;
    _setDeveloperMode(enabled);
  }

  void _setDeveloperMode(bool value) {
    playerController.setTechnicalPlaybackNoticesEnabled(value);
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
      await playerController.flushPlaybackState();
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
    final shouldRefreshShell =
        _lastShellSongId != song?.id ||
        _lastShellPlaying != playerController.isPlaying;
    _lastShellSongId = song?.id;
    _lastShellPlaying = playerController.isPlaying;
    if (shouldRefreshShell) {
      unawaited(
        _windowsMediaBridge.updatePlayback(
          isPlaying: playerController.isPlaying,
          title: song?.title ?? '',
          artist: song?.artist ?? '',
        ),
      );
      unawaited(_syncCoverAccent());
    }
    final key = song == null ? null : _lyricCacheKey(song);
    if (song != null && key != null && key != _lastPreloadedLyricKey) {
      _lastPreloadedLyricKey = key;
      unawaited(_loadLyricsCached(song));
    }
    _scheduleDesktopLyricsSync();
    if (_isFmSession &&
        song != null &&
        recommendationController.isFmSong(song)) {
      unawaited(_maintainFmQueue(song));
    }
    if (_isFmSession &&
        playerController.playbackMode != PlaybackMode.sequence) {
      playerController.setPlaybackMode(PlaybackMode.sequence);
    }
    if (shouldRefreshShell) _refresh();
  }

  void _handlePlayerProgress() {
    // Progress is intentionally kept off ChangeNotifier to avoid rebuilding
    // the whole shell every tick. Desktop lyrics still need a lightweight
    // cadence so the highlighted line follows the audio clock.
    _scheduleDesktopLyricsSync();
  }

  Future<void> _maintainFmQueue(Song song) async {
    if (_lastFmSyncSongId == song.id) return;
    _lastFmSyncSongId = song.id;
    final additions = await recommendationController.syncFmPlayback(song);
    if (_isFmSession && additions.isNotEmpty) {
      playerController.appendQueue(additions);
    }
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
      recommendationController.clearAccountState();
      if (!mounted) return;
      setState(() {
        detailTitle = null;
        detailSubtitle = null;
        detailHeaderArtistName = null;
        detailImageUrl = null;
        detailSongs = [];
        detailRelatedItems = [];
        detailSimilarArtists = [];
        detailRelatedLoadingMore = false;
        detailRelatedHasMore = false;
        detailRelatedPage = 1;
        detailLoading = false;
        detailPlaylist = null;
        detailCatalogItem = null;
        detailIdentity = null;
        detailStorageKeyPrefix = null;
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
        unawaited(recommendationController.loadDaily(refresh: true));
      }
    } finally {
      _resettingAccountState = false;
    }
  }

  Future<void> _playSong(Song song, List<Song> sourceQueue) async {
    final previousMode = _playbackModeBeforeFm;
    _isFmSession = false;
    _lastFmSyncSongId = null;
    _playbackModeBeforeFm = null;
    if (previousMode != null) playerController.setPlaybackMode(previousMode);
    await _playFromQueue(song, sourceQueue);
  }

  /// Dedicated path for the "Play All" button – never used for individual song
  /// clicks, so shuffle-mode random pick cannot interfere with user intent.
  Future<void> _playAllSongs(List<Song> songs) async {
    if (songs.isEmpty) return;
    final previousMode = _playbackModeBeforeFm;
    _isFmSession = false;
    _lastFmSyncSongId = null;
    _playbackModeBeforeFm = null;
    if (previousMode != null) playerController.setPlaybackMode(previousMode);
    await playerController.playAll(songs);
  }

  Future<void> _playFmSong(Song song, List<Song> sourceQueue) async {
    _playbackModeBeforeFm ??= playerController.playbackMode;
    _isFmSession = true;
    _lastFmSyncSongId = null;
    playerController.setPlaybackMode(PlaybackMode.sequence);
    await _playFromQueue(song, sourceQueue);
  }

  Future<void> _handleDislikeFm() async {
    final current = playerController.currentSong;
    if (current == null) return;
    final playtimeSeconds = playerController.position.inSeconds;

    final nextSongFuture = recommendationController.dislikeFm(
      current,
      playtimeSeconds: playtimeSeconds,
    );

    await playerController.removeFromQueue(current);

    final nextSong = await nextSongFuture;
    if (nextSong != null) {
      await playerController.playSong(
        nextSong,
        fromQueue: recommendationController.fmSongs,
      );
    }
  }

  Future<void> _playFromQueue(Song song, List<Song> sourceQueue) async {
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

  void _openDailyRecommendations() {
    final songs = recommendationController.dailySongs;
    if (songs.isEmpty) {
      unawaited(recommendationController.loadDaily(refresh: true));
      return;
    }
    setState(() {
      detailTitle = '每日推荐';
      detailSubtitle = '';
      detailHeaderArtistName = null;
      detailImageUrl = songs
          .map((song) => song.coverUrl?.trim() ?? '')
          .firstWhere((url) => url.isNotEmpty, orElse: () => '');
      detailSongs = songs;
      detailRelatedItems = const [];
      detailSimilarArtists = const [];
      detailRelatedLoadingMore = false;
      detailRelatedHasMore = false;
      detailLoading = false;
      detailKind = CollectionDetailKind.playlist;
      detailPlaylist = null;
      detailCatalogItem = null;
      detailIdentity =
          'recommendation:daily:${DateTime.now().toIso8601String().substring(0, 10)}';
      detailStorageKeyPrefix = detailIdentity;
      detailSelectedTab = 0;
      detailHistory.clear();
    });
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

  Future<void> _showCreatePlaylist() async {
    final nameController = TextEditingController();
    var isPrivate = false;
    final result = await showDialog<({String name, bool isPrivate})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => _CreatePlaylistDialog(
          controller: nameController,
          isPrivate: isPrivate,
          onPrivacyChanged: (value) => setDialogState(() => isPrivate = value),
          onCancel: () => Navigator.of(dialogContext).pop(),
          onCreate: () {
            final name = nameController.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(
                dialogContext,
              ).pop((name: name, isPrivate: isPrivate));
            }
          },
        ),
      ),
    );
    nameController.dispose();
    if (result == null || !mounted) return;
    try {
      await libraryController.createPlaylist(
        result.name,
        isPrivate: result.isPrivate,
      );
    } catch (error) {
      if (!mounted) return;
      _showNotice(error.toString(), kind: AppNoticeKind.error);
    }
  }

  Future<void> _confirmDeletePlaylist(MusicPlaylist playlist) async {
    if (playlist.isDefault) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _DeletePlaylistDialog(
        playlistName: playlist.name,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onDelete: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await libraryController.deletePlaylist(playlist);
      if (detailPlaylist?.listId == playlist.listId && mounted) _popDetail();
    } catch (error) {
      if (!mounted) return;
      _showNotice(error.toString(), kind: AppNoticeKind.error);
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
    if (!_favoriteUpdates.add(song.id)) return;
    final previous = libraryController.isFavorite(song);
    final desired = !previous;
    _applyFavoriteState(song, desired);
    try {
      await libraryController.toggleFavorite(song);
      _applyFavoriteState(song, libraryController.isFavorite(song));
    } catch (error) {
      _applyFavoriteState(song, previous);
      if (!mounted) return;
      _showNotice(error.toString(), kind: AppNoticeKind.error);
    } finally {
      _favoriteUpdates.remove(song.id);
    }
  }

  void _applyFavoriteState(Song song, bool liked) {
    detailSongs = detailSongs
        .map((item) => item.id == song.id ? item.copyWith(liked: liked) : item)
        .toList();
    searchController.results = searchController.results
        .map((item) => item.id == song.id ? item.copyWith(liked: liked) : item)
        .toList();
    playerController.updateSongFavorite(song, liked);
    _refresh();
  }

  Future<void> _openCatalog(SearchCatalogItem item) async {
    final identity = 'catalog:${item.category.name}:${item.id}';
    if (detailIdentity == identity) return;
    final storageKeyPrefix = '$identity:${++_detailStorageEpoch}';
    setState(() {
      _pushCurrentDetail();
      detailTitle = item.title;
      detailSubtitle = item.subtitle;
      detailHeaderArtistName = item.category == SearchCategory.album
          ? _navigableArtistName(item.subtitle)
          : null;
      detailImageUrl = item.imageUrl;
      detailSongs = [];
      detailRelatedItems = [];
      detailSimilarArtists = [];
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
      detailStorageKeyPrefix = storageKeyPrefix;
      detailSelectedTab = 0;
    });
    try {
      final results = await Future.wait<Object>([
        repository.getCatalogSongs(item),
        if (item.category == SearchCategory.artist)
          repository.getArtistAlbumsPage(item, page: 1)
        else
          Future<List<SearchCatalogItem>>.value([]),
        if (item.category == SearchCategory.artist)
          repository
              .getSimilarArtists(item)
              .catchError((_) => <SearchCatalogItem>[])
        else
          Future<List<SearchCatalogItem>>.value([]),
      ]);
      if (!mounted) return;
      final songs = (results[0] as List<Song>)
          .map(libraryController.withFavoriteState)
          .toList();
      final finalItem = item.category == SearchCategory.album
          ? await _hydrateAlbumReleaseDate(item, songs)
          : item;
      final artistHeaderImage = item.category == SearchCategory.artist
          ? await _resolveArtistHeaderImage(finalItem, songs)
          : finalItem.imageUrl;
      if (!mounted) return;
      setState(() {
        detailCatalogItem = finalItem;
        detailImageUrl = artistHeaderImage ?? finalItem.imageUrl;
        detailSongs = songs;
        if (item.category == SearchCategory.artist) {
          detailRelatedItems = results[1] as List<SearchCatalogItem>;
          detailSimilarArtists = results[2] as List<SearchCatalogItem>;
          detailRelatedPage = 1;
          detailRelatedHasMore = detailRelatedItems.isNotEmpty;
        }
        detailLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => detailLoading = false);
      _showNotice(error.toString(), kind: AppNoticeKind.error);
    }
  }

  Future<String?> _resolveArtistHeaderImage(
    SearchCatalogItem artist,
    List<Song> songs,
  ) async {
    final knownImage = artist.imageUrl?.trim();
    if (knownImage != null && knownImage.isNotEmpty) return knownImage;
    for (final song in songs.take(3)) {
      try {
        final portraits = await repository.getArtistPortraits(song);
        for (final portrait in portraits) {
          final imageUrl = portrait.trim();
          if (imageUrl.isNotEmpty) return imageUrl;
        }
      } catch (_) {
        // Keep the default avatar when no upstream portrait is available.
      }
    }
    return null;
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
      _showNotice(error.toString(), kind: AppNoticeKind.error);
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
    final storageKeyPrefix = '$identity:${++_detailStorageEpoch}';
    setState(() {
      _pushCurrentDetail();
      detailTitle = playlist.name;
      detailSubtitle = '${playlist.songCount} 首';
      detailHeaderArtistName = null;
      detailImageUrl = playlist.coverUrl;
      detailSongs = [];
      detailRelatedItems = [];
      detailSimilarArtists = [];
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
      detailStorageKeyPrefix = storageKeyPrefix;
      detailSelectedTab = 0;
    });
    try {
      final songs = await libraryController.loadPlaylist(playlist);
      if (!mounted) return;
      final baseCatalogItem = detailCatalogItem;
      final updatedCatalogItem =
          playlist.kind == MusicPlaylistKind.album && baseCatalogItem != null
          ? await _hydrateAlbumReleaseDate(baseCatalogItem, songs)
          : baseCatalogItem;
      if (!mounted) return;
      setState(() {
        if (updatedCatalogItem != null) {
          detailCatalogItem = updatedCatalogItem;
        }
        detailSongs = songs.map(libraryController.withFavoriteState).toList();
        if (songs.isNotEmpty) {
          detailSubtitle = '${songs.length} 首';
          if (!playlist.hasCustomCover &&
              (playlist.kind == MusicPlaylistKind.createdPlaylist ||
                  playlist.kind == MusicPlaylistKind.favoriteSongs)) {
            final firstCover = songs.first.coverUrl;
            if (firstCover != null && firstCover.isNotEmpty) {
              detailImageUrl = firstCover;
            }
          }
        }
        detailLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => detailLoading = false);
      _showNotice(error.toString(), kind: AppNoticeKind.error);
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
        subtitle: '',
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

  Future<void> _setDesktopLyricsVisible(bool visible) async {
    if (_desktopLyricsVisible == visible) return;
    setState(() => _desktopLyricsVisible = visible);
    try {
      await _windowsMediaBridge.setDesktopLyricsLocked(_desktopLyricsLocked);
      await _windowsMediaBridge.setDesktopLyricsFontSize(
        _desktopLyricsFontSize,
      );
      await _windowsMediaBridge
          .setDesktopLyricsVisible(visible)
          .timeout(const Duration(milliseconds: 800));
      if (visible) _scheduleDesktopLyricsSync(immediate: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _desktopLyricsVisible = false);
    }
  }

  void _scheduleDesktopLyricsSync({bool immediate = false}) {
    if (!_desktopLyricsVisible) return;
    if (immediate) _desktopLyricsTimer?.cancel();
    if (_desktopLyricsTimer?.isActive ?? false) return;
    _desktopLyricsTimer = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 50),
      () => unawaited(_syncDesktopLyrics()),
    );
  }

  Future<void> _syncDesktopLyrics() async {
    if (!_desktopLyricsVisible) return;
    if (_desktopLyricsSyncing) return;
    _desktopLyricsSyncing = true;
    try {
      await _performDesktopLyricsSync();
    } finally {
      _desktopLyricsSyncing = false;
      if (_desktopLyricsVisible) {
        _scheduleDesktopLyricsSync();
      }
    }
  }

  Future<void> _performDesktopLyricsSync() async {
    if (!_desktopLyricsVisible) return;
    final song = playerController.currentSong;
    if (song == null) {
      await _windowsMediaBridge.updateDesktopLyrics(
        text: '晴听音乐',
        secondary: '选择一首歌开始播放',
        progress: 0,
        dark: true,
        accent: AppColors.primary.toARGB32(),
      );
      return;
    }
    List<LyricLine> lines;
    try {
      lines = await _loadLyricsCached(song);
    } catch (_) {
      lines = const [];
    }
    if (!_desktopLyricsVisible || playerController.currentSong?.id != song.id) {
      return;
    }
    final position = playerController.position;
    var activeIndex = -1;
    for (var index = 0; index < lines.length; index++) {
      if (lines[index].time <= position) {
        activeIndex = index;
      } else {
        break;
      }
    }
    final active = activeIndex >= 0 ? lines[activeIndex] : null;
    final secondary = <String>[
      if (_showLyricTranslation &&
          (active?.translation ?? '').trim().isNotEmpty)
        active!.translation!.trim(),
      if (_showLyricTransliteration &&
          (active?.transliteration ?? '').trim().isNotEmpty)
        active!.transliteration!.trim(),
    ];
    if (secondary.isEmpty && activeIndex + 1 < lines.length) {
      secondary.add(lines[activeIndex + 1].text);
    }

    final timing = active == null
        ? const LyricProgressFrame(progress: 0, velocity: 0)
        : resolveLyricProgress(active, position);

    await _windowsMediaBridge.updateDesktopLyrics(
      text: active?.text ?? (lines.isEmpty ? song.title : '…'),
      secondary: secondary.join('  ·  '),
      progress: timing.progress,
      velocity: playerController.isPlaying ? timing.velocity : 0,
      dark: true,
      accent: AppColors.primary.toARGB32(),
    );
  }

  Future<void> _showAddToPlaylist(Song song) async {
    if (_playlistOperationBusy) return;
    setState(() {
      _playlistOperationBusy = true;
      _playlistOperationIndicatorVisible = true;
      _playlistOperationMessage = '正在准备歌单…';
    });
    try {
      if (authController != null && !authController!.isLoggedIn) {
        await _showLogin();
        if (authController != null && !authController!.isLoggedIn) return;
      }
      await libraryController.ensureLoaded(LibrarySection.playlists);
      if (!mounted) return;
      final editable = libraryController.editablePlaylists;
      final containingIds = libraryController.getPlaylistIdsContainingSongSync(
        song,
        editable,
      );
      final containingIdsFuture = containingIds.isEmpty && editable.isNotEmpty
          ? libraryController.getPlaylistIdsContainingSong(song, editable)
          : null;
      setState(() {
        _playlistOperationIndicatorVisible = containingIdsFuture != null;
        _playlistOperationMessage = '正在检查歌单状态…';
      });
      if (!mounted) return;
      final selectedPlaylist = await showDialog<MusicPlaylist>(
        context: context,
        builder: (_) => AddToPlaylistDialog(
          song: song,
          playlists: editable,
          containingPlaylistIds: containingIds,
          containingPlaylistIdsFuture: containingIdsFuture,
          onContainingStateLoaded: _hidePlaylistOperationIndicator,
        ),
      );
      if (selectedPlaylist != null && mounted) {
        setState(() {
          _playlistOperationIndicatorVisible = true;
          _playlistOperationMessage = '正在添加到「${selectedPlaylist.name}」…';
        });
        await _addToPlaylist(selectedPlaylist, song);
      }
    } catch (error) {
      if (!mounted) return;
      _showNotice(error.toString(), kind: AppNoticeKind.error);
    } finally {
      if (mounted) {
        setState(() {
          _playlistOperationBusy = false;
          _playlistOperationIndicatorVisible = false;
        });
      }
    }
  }

  void _showNotice(String message, {AppNoticeKind kind = AppNoticeKind.info}) {
    if (!mounted || message.trim().isEmpty) return;
    _noticeTimer?.cancel();
    final notice = AppNoticeData(
      id: ++_noticeId,
      message: message.trim(),
      kind: kind,
    );
    setState(() => _notice = notice);
    _noticeTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted || _notice?.id != notice.id) return;
      setState(() => _notice = null);
    });
  }

  void _hidePlaylistOperationIndicator() {
    if (!mounted ||
        !_playlistOperationBusy ||
        _playlistOperationMessage != '正在检查歌单状态…') {
      return;
    }
    setState(() => _playlistOperationIndicatorVisible = false);
  }

  Future<void> _addToPlaylist(MusicPlaylist playlist, Song song) async {
    try {
      await libraryController.addToPlaylist(playlist, song);
      if (!mounted) return;
      _showNotice('已添加到 ${playlist.name}', kind: AppNoticeKind.success);
    } catch (error) {
      if (!mounted) return;
      _showNotice(error.toString(), kind: AppNoticeKind.error);
    }
  }

  Future<void> _removeFromDetailPlaylist(Song song) async {
    final playlist = detailPlaylist;
    if (playlist == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _RemoveSongFromPlaylistDialog(
        songTitle: song.title,
        playlistName: playlist.name,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onRemove: () => Navigator.of(dialogContext).pop(true),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await libraryController.removeFromPlaylist(playlist, song);
      setState(() {
        detailSongs = detailSongs.where((item) => item.id != song.id).toList();
      });
      if (mounted) {
        _showNotice(
          '已从 ${playlist.name} 移除 ${song.title}',
          kind: AppNoticeKind.success,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showNotice(error.toString(), kind: AppNoticeKind.error);
    }
  }

  Future<void> _openAlbumFromSong(Song song) async {
    final albumId = song.albumId;
    if (albumId != null && albumId > 0) {
      final id = albumId.toString();
      await _openCatalog(
        SearchCatalogItem(
          id: id,
          title: song.album,
          subtitle: song.artist,
          category: SearchCategory.album,
          imageUrl: song.coverUrl,
          listId: id,
        ),
      );
      return;
    }

    final matches = await repository.searchCatalog(
      song.album,
      SearchCategory.album,
    );
    final normalizedAlbum = song.album.trim().toLowerCase();
    SearchCatalogItem? exactMatch;
    for (final candidate in matches) {
      if (candidate.title.trim().toLowerCase() == normalizedAlbum) {
        exactMatch = candidate;
        break;
      }
    }
    if (exactMatch != null) await _openCatalog(exactMatch);
  }

  Future<void> _toggleCatalogCollection(SearchCatalogItem item) async {
    try {
      final wasCollected = libraryController.isCatalogCollected(item);
      await libraryController.toggleCatalogCollection(item);
      if (!mounted) return;
      _showNotice(wasCollected ? '已取消收藏' : '已收藏', kind: AppNoticeKind.success);
    } catch (error) {
      if (!mounted) return;
      _showNotice(error.toString(), kind: AppNoticeKind.error);
    }
  }

  SearchCatalogItem _catalogFromPlaylist(MusicPlaylist playlist) {
    final isAlbum = playlist.kind == MusicPlaylistKind.album;
    final isCollectedPlaylist =
        playlist.kind == MusicPlaylistKind.collectedPlaylist;
    final catalogId = isAlbum
        ? playlist.sourceAlbumId
        : isCollectedPlaylist
        ? playlist.sourcePlaylistId
        : playlist.id;
    final catalogListId = isAlbum
        ? catalogId
        : isCollectedPlaylist
        ? playlist.sourcePlaylistListId
        : playlist.listId;
    return SearchCatalogItem(
      id: catalogId,
      title: playlist.name,
      subtitle: '${playlist.songCount} 首',
      category: isAlbum ? SearchCategory.album : SearchCategory.playlist,
      imageUrl: playlist.coverUrl,
      listId: catalogListId,
      // user/playlist 的 list_create_userid 是用户侧收藏记录的创建者，
      // 不是专辑歌手。专辑由歌曲元数据或搜索结果补全该字段。
      ownerId: isAlbum ? null : playlist.ownerId,
      releaseDate: playlist.releaseDate,
    );
  }

  Future<SearchCatalogItem> _hydrateAlbumReleaseDate(
    SearchCatalogItem item,
    List<Song> songs,
  ) async {
    var releaseDate = item.releaseDate;
    final albumIds = <String>{
      for (final song in songs)
        if (song.albumId != null && song.albumId! > 0) song.albumId.toString(),
    };
    final sourceAlbumId = albumIds.isNotEmpty
        ? albumIds.first
        : (item.listId?.trim().isNotEmpty == true ? item.listId! : item.id);
    final songArtistId = songs
        .map((song) => song.artistId)
        .firstWhere(
          (artistId) => artistId != null && artistId > 0,
          orElse: () => null,
        )
        ?.toString();
    var ownerId = item.ownerId ?? songArtistId;

    if (releaseDate?.trim().isNotEmpty != true) {
      for (final albumId in albumIds) {
        releaseDate = await repository.getAlbumReleaseDate(albumId);
        if (releaseDate?.trim().isNotEmpty == true) break;
      }
    }

    SearchCatalogItem? matched;
    if (releaseDate?.trim().isNotEmpty != true || ownerId?.isNotEmpty != true) {
      try {
        final matches = await repository.searchCatalog(
          item.title,
          SearchCategory.album,
        );
        if (matches.isNotEmpty) {
          matched = matches.firstWhere(
            (candidate) =>
                candidate.id == sourceAlbumId ||
                (candidate.title == item.title &&
                    (item.subtitle.isEmpty ||
                        candidate.subtitle == item.subtitle)),
            orElse: () => matches.first,
          );
          releaseDate ??= matched.releaseDate;
          ownerId ??= matched.ownerId;
          if (releaseDate?.trim().isEmpty != false && matched.id.isNotEmpty) {
            releaseDate = await repository.getAlbumReleaseDate(matched.id);
          }
        }
      } catch (_) {
        // 元数据回补失败不影响专辑歌曲正常打开。
      }
    }
    return SearchCatalogItem(
      id: sourceAlbumId,
      title: item.title,
      subtitle: item.subtitle,
      category: item.category,
      imageUrl: item.imageUrl ?? matched?.imageUrl,
      listId: sourceAlbumId,
      ownerId: ownerId,
      releaseDate: releaseDate,
    );
  }

  Future<void> _openArtistFromNowPlaying(Song song) async {
    setState(() => showNowPlayingPage = false);
    await _openArtistFromSong(song);
  }

  void _pushCurrentDetail() {
    if (detailTitle == null) return;
    detailHistory.add(
      _DetailSnapshot(
        identity: detailIdentity,
        title: detailTitle!,
        subtitle: detailSubtitle,
        headerArtistName: detailHeaderArtistName,
        imageUrl: detailImageUrl,
        songs: detailSongs,
        relatedItems: detailRelatedItems,
        similarArtists: detailSimilarArtists,
        relatedPage: detailRelatedPage,
        relatedHasMore: detailRelatedHasMore,
        relatedLoadingMore: detailRelatedLoadingMore,
        isLoading: detailLoading,
        kind: detailKind,
        playlist: detailPlaylist,
        catalogItem: detailCatalogItem,
        storageKeyPrefix: detailStorageKeyPrefix,
        selectedTab: detailSelectedTab,
      ),
    );
  }

  void _popDetail() {
    if (detailHistory.isEmpty) {
      setState(() {
        detailTitle = null;
        detailHeaderArtistName = null;
        detailPlaylist = null;
        detailCatalogItem = null;
        detailIdentity = null;
        detailStorageKeyPrefix = null;
        detailSelectedTab = 0;
        detailSimilarArtists = [];
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
      detailHeaderArtistName = previous.headerArtistName;
      detailImageUrl = previous.imageUrl;
      detailSongs = previous.songs;
      detailRelatedItems = previous.relatedItems;
      detailSimilarArtists = previous.similarArtists;
      detailRelatedPage = previous.relatedPage;
      detailRelatedHasMore = previous.relatedHasMore;
      detailRelatedLoadingMore = previous.relatedLoadingMore;
      detailLoading = previous.isLoading;
      detailKind = previous.kind;
      detailPlaylist = previous.playlist;
      detailCatalogItem = previous.catalogItem;
      detailStorageKeyPrefix = previous.storageKeyPrefix;
      detailSelectedTab = previous.selectedTab;
    });
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _desktopLyricsTimer?.cancel();
    _sessionExpiredSubscription?.cancel();
    widget.themeController.removeListener(_handleThemeChanged);
    if (Platform.isWindows && widget.enableWindowControls) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    playerController.progress.removeListener(_handlePlayerProgress);
    playerController
      ..removeListener(_handlePlayerChanged)
      ..dispose();
    playbackQualityController
      ..removeListener(_refresh)
      ..dispose();
    searchController
      ..removeListener(_refresh)
      ..dispose();
    libraryController
      ..removeListener(_refresh)
      ..dispose();
    recommendationController
      ..removeListener(_refresh)
      ..dispose();
    updateController
      ..removeListener(_refresh)
      ..dispose();
    authController
      ?..removeListener(_handleAuthChanged)
      ..dispose();
    unawaited(_windowsMediaBridge.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final autoCompact = constraints.maxWidth < 1050;
          final compactSidebar = autoCompact || !_sidebarExpanded;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.page,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.sidebar, AppColors.page],
              ),
            ),
            child: AsyncOperationOverlay(
              active:
                  _playlistOperationBusy && _playlistOperationIndicatorVisible,
              message: _playlistOperationMessage,
              top: 72,
              child: Stack(
                children: [
                  Column(
                    children: [
                      AppWindowCaption(
                        enabled: widget.enableWindowControls,
                        transparentOverlay: true,
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
                                  detailHeaderArtistName = null;
                                  detailPlaylist = null;
                                  detailCatalogItem = null;
                                  detailIdentity = null;
                                  detailStorageKeyPrefix = null;
                                  detailSelectedTab = 0;
                                  detailHistory.clear();
                                  showNowPlayingPage = false;
                                });
                              },
                              loginLabel:
                                  authController?.session.displayName ?? '演示模式',
                              avatarUrl:
                                  authController?.session.avatarUrl ?? '',
                              isLoggedIn: authController?.isLoggedIn ?? false,
                              vipTooltip: _vipTooltip,
                              onLogin: _handleAccountEntry,
                              isDark: widget.themeController.isDark,
                              onToggleTheme: widget.themeController.toggle,
                            ),
                            SidebarDividerHandle(
                              compact: compactSidebar,
                              onToggle: () {
                                setState(() {
                                  _sidebarExpanded = compactSidebar;
                                });
                                unawaited(
                                  _preferences.write(
                                    'sidebarExpanded',
                                    _sidebarExpanded,
                                  ),
                                );
                              },
                            ),
                            Expanded(child: _selectedPage()),
                          ],
                        ),
                      ),
                      PlayerBar(
                        controller: playerController,
                        playbackQualityController: playbackQualityController,
                        desktopLyricsVisible: _desktopLyricsVisible,
                        onDesktopLyricsChanged: (value) {
                          unawaited(_setDesktopLyricsVisible(value));
                        },
                        onNowPlayingPressed:
                            playerController.currentSong == null
                            ? null
                            : () => setState(() => showNowPlayingPage = true),
                        onOpenAlbum: _openAlbumFromSong,
                        onOpenArtist: _openArtistFromSong,
                        onLike: _toggleFavorite,
                        onAddToPlaylist: _showAddToPlaylist,
                        isFm: _isFmSession,
                        onDislikeFm: _handleDislikeFm,
                        onQueuePressed: () {
                          setState(() => showQueuePanel = !showQueuePanel);
                        },
                      ),
                    ],
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !showQueuePanel,
                      child: AnimatedOpacity(
                        opacity: showQueuePanel ? 1 : 0,
                        duration: AppMotion.normal,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => showQueuePanel = false),
                          child: ColoredBox(
                            color: AppColors.scrim,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: AnimatedSwitcher(
                                duration: AppMotion.slow,
                                reverseDuration: AppMotion.normal,
                                switchInCurve: AppMotion.curve,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.08, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                child: showQueuePanel
                                    ? GestureDetector(
                                        key: const ValueKey('queue-panel'),
                                        onTap: () {},
                                        child: PlayQueuePanel(
                                          controller: playerController,
                                          onClose: () => setState(
                                            () => showQueuePanel = false,
                                          ),
                                        ),
                                      )
                                    : const SizedBox(
                                        key: ValueKey('queue-panel-hidden'),
                                      ),
                              ),
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
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.032),
                                end: Offset.zero,
                              ).animate(curved),
                              child: child,
                            ),
                          );
                        },
                        child: showNowPlayingPage
                            ? RepaintBoundary(
                                key: const ValueKey('now-playing-page'),
                                child: NowPlayingPage(
                                  controller: playerController,
                                  playbackQualityController:
                                      playbackQualityController,
                                  onClose: () => setState(
                                    () => showNowPlayingPage = false,
                                  ),
                                  loadLyrics: _loadLyricsCached,
                                  onLike: _toggleFavorite,
                                  onAddToPlaylist: _showAddToPlaylist,
                                  onOpenArtist: _openArtistFromNowPlaying,
                                  isFm: _isFmSession,
                                  onDislikeFm: _handleDislikeFm,
                                  desktopLyricsVisible: _desktopLyricsVisible,
                                  onDesktopLyricsChanged: (value) {
                                    unawaited(_setDesktopLyricsVisible(value));
                                  },
                                  showTranslation: _showLyricTranslation,
                                  showTransliteration:
                                      _showLyricTransliteration,
                                  onTranslationChanged: (value) {
                                    setState(
                                      () => _showLyricTranslation = value,
                                    );
                                    _scheduleDesktopLyricsSync(immediate: true);
                                  },
                                  onTransliterationChanged: (value) {
                                    setState(
                                      () => _showLyricTransliteration = value,
                                    );
                                    _scheduleDesktopLyricsSync(immediate: true);
                                  },
                                  loadArtistPortraits:
                                      repository.getArtistPortraits,
                                ),
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
                          transparentOverlay: true,
                        ),
                      ),
                    ),
                  AppNoticeHost(notice: _notice),
                ],
              ),
            ),
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
      final collectionItem = detailCatalogItem;
      return CollectionDetailPage(
        key: ValueKey(detailIdentity ?? '$detailKind:$detailTitle'),
        kind: detailKind,
        title: detailTitle!,
        subtitle: detailSubtitle ?? '',
        imageUrl: detailImageUrl,
        releaseDate:
            detailCatalogItem?.releaseDate ?? detailPlaylist?.releaseDate,
        songs: detailSongs,
        relatedItems: detailRelatedItems,
        similarArtists: detailSimilarArtists,
        relatedItemsLoadingMore: detailRelatedLoadingMore,
        relatedItemsCanLoadMore: detailRelatedHasMore,
        onLoadMoreRelatedItems: _loadMoreArtistAlbums,
        isLoading: detailLoading,
        currentSong: playerController.currentSong,
        isPlaying: playerController.isPlaying,
        selectedTab: detailSelectedTab,
        onTabChanged: (index) => setState(() => detailSelectedTab = index),
        storageKeyPrefix:
            detailStorageKeyPrefix ??
            detailIdentity ??
            '$detailKind:$detailTitle',
        openedFromArtist:
            detailKind == CollectionDetailKind.album &&
            detailHistory.isNotEmpty &&
            detailHistory.last.kind == CollectionDetailKind.artist,
        onBack: _popDetail,
        onOpenHeaderArtist:
            detailKind == CollectionDetailKind.album &&
                detailHeaderArtistName != null
            ? () => _openArtistByName(detailHeaderArtistName!)
            : null,
        onPlay: _playSong,
        onPlayAll: _playAllSongs,
        onLike: _toggleFavorite,
        onAddToPlaylist: _showAddToPlaylist,
        onRemoveFromPlaylist:
            detailPlaylist?.kind == MusicPlaylistKind.createdPlaylist
            ? _removeFromDetailPlaylist
            : null,
        onDeletePlaylist:
            detailPlaylist?.kind == MusicPlaylistKind.createdPlaylist &&
                detailPlaylist?.isDefault != true
            ? () => _confirmDeletePlaylist(detailPlaylist!)
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
        onPlayAll: _playAllSongs,
        onLike: _toggleFavorite,
        onAddToPlaylist: _showAddToPlaylist,
        onOpenArtist: _openArtistFromSong,
        onOpenAlbum: _openAlbumFromSong,
        onOpenPlaylist: _openPlaylist,
        onOpenCatalog: _openCatalog,
        onLogin: _showLogin,
        onCreatePlaylist: _showCreatePlaylist,
        selectedTab: librarySelectedTab,
        onTabChanged: (index) => setState(() => librarySelectedTab = index),
      ),
      1 => SearchPage(
        controller: searchController,
        currentSong: playerController.currentSong,
        isPlaying: playerController.isPlaying,
        onPlay: _playSong,
        onPlayAll: _playAllSongs,
        onLogin: _showLogin,
        onOpenCatalog: _openCatalog,
        onLike: _toggleFavorite,
        onAddToPlaylist: _showAddToPlaylist,
        onOpenArtist: _openArtistFromSong,
        onOpenAlbum: _openAlbumFromSong,
      ),
      2 => RecommendationPage(
        controller: recommendationController,
        currentSong: playerController.currentSong,
        onPlay: _playSong,
        onPlayFm: _playFmSong,
        onOpenDaily: _openDailyRecommendations,
      ),
      _ => SettingsPage(
        themeController: widget.themeController,
        updateController: updateController,
        playbackQualityController: playbackQualityController,
        onCheckUpdates: () => _checkForUpdates(),
        closeToTray: _closeToTray,
        onCloseToTrayChanged: _setCloseToTray,
        sidebarExpanded: _sidebarExpanded,
        onSidebarExpandedChanged: _setSidebarExpanded,
        onEndpointChanged: () {
          libraryController.invalidateLoadedState();
          searchController.invalidateCachedResults();
          unawaited(libraryController.ensureLoaded(LibrarySection.songs));
        },
        onDeveloperModeChanged: _setDeveloperMode,
        onNotice: (message) => _showNotice(message),
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

class _CreatePlaylistDialog extends StatelessWidget {
  const _CreatePlaylistDialog({
    required this.controller,
    required this.isPrivate,
    required this.onPrivacyChanged,
    required this.onCancel,
    required this.onCreate,
  });

  final TextEditingController controller;
  final bool isPrivate;
  final ValueChanged<bool> onPrivacyChanged;
  final VoidCallback onCancel;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => AppDialog(
    icon: Icons.playlist_add_rounded,
    title: '新建歌单',
    subtitle: '给这组音乐一个名字',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDialogTextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          hintText: '输入歌单名称',
          onSubmitted: (_) => onCreate(),
        ),
        const SizedBox(height: 12),
        AppDialogSwitchTile(
          icon: isPrivate ? Icons.lock_rounded : Icons.public_rounded,
          title: '设为私密歌单',
          subtitle: isPrivate ? '仅自己可见' : '公开歌单',
          value: isPrivate,
          onChanged: onPrivacyChanged,
        ),
      ],
    ),
    actions: [
      AppDialogButton.ghost(label: '取消', onPressed: onCancel),
      const SizedBox(width: 8),
      AppDialogButton.primary(label: '创建', onPressed: onCreate),
    ],
  );
}

class _RemoveSongFromPlaylistDialog extends StatelessWidget {
  const _RemoveSongFromPlaylistDialog({
    required this.songTitle,
    required this.playlistName,
    required this.onCancel,
    required this.onRemove,
  });

  final String songTitle;
  final String playlistName;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => AppConfirmDialog(
    icon: Icons.delete_outline_rounded,
    isDanger: true,
    title: '从歌单移除',
    content: '确定要将“$songTitle”从歌单“$playlistName”中移除吗？',
    cancelLabel: '取消',
    confirmLabel: '确认移除',
    onCancel: onCancel,
    onConfirm: onRemove,
  );
}

class _DeletePlaylistDialog extends StatelessWidget {
  const _DeletePlaylistDialog({
    required this.playlistName,
    required this.onCancel,
    required this.onDelete,
  });

  final String playlistName;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => AppConfirmDialog(
    icon: Icons.delete_forever_rounded,
    isDanger: true,
    title: '删除歌单',
    content: '“$playlistName”将从你的音乐库移除，此操作无法恢复',
    cancelLabel: '取消',
    confirmLabel: '确认删除',
    onCancel: onCancel,
    onConfirm: onDelete,
  );
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
    required this.headerArtistName,
    required this.imageUrl,
    required this.songs,
    required this.relatedItems,
    required this.similarArtists,
    required this.relatedPage,
    required this.relatedHasMore,
    required this.relatedLoadingMore,
    required this.isLoading,
    required this.kind,
    required this.playlist,
    required this.catalogItem,
    required this.storageKeyPrefix,
    required this.selectedTab,
  });

  final String? identity;
  final String title;
  final String? subtitle;
  final String? headerArtistName;
  final String? imageUrl;
  final List<Song> songs;
  final List<SearchCatalogItem> relatedItems;
  final List<SearchCatalogItem> similarArtists;
  final int relatedPage;
  final bool relatedHasMore;
  final bool relatedLoadingMore;
  final bool isLoading;
  final CollectionDetailKind kind;
  final MusicPlaylist? playlist;
  final SearchCatalogItem? catalogItem;
  final String? storageKeyPrefix;
  final int selectedTab;
}
