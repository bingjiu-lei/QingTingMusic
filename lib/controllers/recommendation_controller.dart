import 'package:flutter/foundation.dart';

import '../data/music_repository.dart';
import 'dart:async';

import '../models/artist_directory.dart';
import '../models/rank_chart_item.dart';
import '../models/song.dart';
import '../services/app_preferences_service.dart';
import '../services/kugou_api_client.dart';

class RecommendationController extends ChangeNotifier {
  RecommendationController(
    this.repository, {
    AppPreferencesService? preferences,
  }) : _preferences = preferences ?? AppPreferencesService();

  final MusicRepository repository;
  final AppPreferencesService _preferences;

  static const String _prefSelectedRankId = 'selected_rank_id';
  static const int _defaultRankId = 8888; // TOP500

  int selectedTab = 0;
  int artistType = 0;
  int artistSexType = 0;
  String artistLetter = '全部';
  ArtistDirectory? artistDirectory;
  bool loadingArtists = false;
  String? artistError;
  int _artistRequestVersion = 0;

  void selectTab(int tab) {
    if (selectedTab == tab) return;
    selectedTab = tab;
    notifyListeners();
    if (tab == 1 && artistDirectory == null) loadArtists();
  }

  void selectArtistType(int value) {
    if (artistType == value) return;
    artistType = value;
    artistLetter = '全部';
    loadArtists();
  }

  void selectArtistSexType(int value) {
    if (artistSexType == value) return;
    artistSexType = value;
    artistLetter = '全部';
    loadArtists();
  }

  void selectArtistLetter(String letter) {
    if (artistLetter == letter) return;
    artistLetter = letter;
    notifyListeners();
  }

  final Map<String, ArtistDirectory> _artistCache = {};

  String get _currentCacheKey => '$artistType:$artistSexType';

  void invalidateArtistDirectory() {
    _artistRequestVersion++;
    _artistCache.clear();
    artistDirectory = null;
    artistError = null;
    loadingArtists = false;
    if (selectedTab == 1) {
      loadArtists(refresh: true);
    } else {
      notifyListeners();
    }
  }

  Future<void> loadArtists({bool refresh = false}) async {
    final cacheKey = _currentCacheKey;
    if (!refresh && _artistCache.containsKey(cacheKey)) {
      artistDirectory = _artistCache[cacheKey];
      artistError = null;
      loadingArtists = false;
      notifyListeners();
      return;
    }
    final request = ++_artistRequestVersion;
    loadingArtists = true;
    artistError = null;
    notifyListeners();
    try {
      final result = await repository.getArtistDirectory(
        type: artistType,
        sexType: artistSexType,
      );
      if (request != _artistRequestVersion) return;
      _artistCache[cacheKey] = result;
      artistDirectory = result;
      if (result.groups.isEmpty) artistError = '暂时没有找到歌手';
    } catch (_) {
      if (request != _artistRequestVersion) return;
      artistError = '歌手列表加载失败，请稍后重试';
    } finally {
      if (request == _artistRequestVersion) {
        loadingArtists = false;
        notifyListeners();
      }
    }
  }

  List<RankChartItem> allRanks = const [];
  RankChartItem? activeRank;
  List<Song> activeRankSongs = const [];
  bool loadingActiveRank = false;
  String? activeRankError;
  int _activeRankRequestVersion = 0;

  List<RankChartItem> get featuredRanks => allRanks;
  bool get loadingRanks => loadingActiveRank;
  String? get ranksError => activeRankError;

  Future<void> initActiveRank({bool refresh = false}) async {
    if (activeRank != null && !refresh && activeRankSongs.isNotEmpty) return;
    final request = ++_activeRankRequestVersion;
    loadingActiveRank = true;
    activeRankError = null;
    notifyListeners();

    try {
      if (allRanks.isEmpty || refresh) {
        allRanks = await repository.getAllRanks();
      }

      int targetRankId = _defaultRankId;
      final stored = await _preferences.read(_prefSelectedRankId);
      if (stored is int) {
        targetRankId = stored;
      } else if (stored is String) {
        targetRankId = int.tryParse(stored) ?? _defaultRankId;
      }

      RankChartItem? matched;
      for (final r in allRanks) {
        if (r.rankId == targetRankId) {
          matched = r;
          break;
        }
      }
      if (matched == null && allRanks.isNotEmpty) {
        matched = allRanks.first;
      }
      activeRank = matched;

      if (matched != null) {
        final songs = await repository.getRankSongs(
          matched.rankId,
          pageSize: 50,
        );
        if (request != _activeRankRequestVersion) return;
        activeRankSongs = songs;
      } else {
        activeRankSongs = const [];
      }
    } catch (_) {
      if (request != _activeRankRequestVersion) return;
      activeRankError = '榜单歌曲加载失败，请稍后重试';
    } finally {
      if (request == _activeRankRequestVersion) {
        loadingActiveRank = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectRank(RankChartItem rank) async {
    activeRank = rank;
    await _preferences.write(_prefSelectedRankId, rank.rankId);
    final request = ++_activeRankRequestVersion;
    loadingActiveRank = true;
    activeRankError = null;
    notifyListeners();

    try {
      final songs = await repository.getRankSongs(rank.rankId, pageSize: 50);
      if (request != _activeRankRequestVersion) return;
      activeRankSongs = songs;
    } catch (_) {
      if (request != _activeRankRequestVersion) return;
      activeRankError = '榜单歌曲加载失败，请稍后重试';
    } finally {
      if (request == _activeRankRequestVersion) {
        loadingActiveRank = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadFeaturedRanks({bool refresh = false}) =>
      initActiveRank(refresh: refresh);

  Future<List<Song>> getRankSongs(int rankId) =>
      repository.getRankSongs(rankId);

  List<Song> dailySongs = const [];
  List<Song> fmSongs = const [];
  bool loadingDaily = false;
  bool loadingFm = false;
  String? dailyError;
  String? fmError;
  String fmMode = 'normal';
  int fmSongPoolId = 0;
  int _fmRequestVersion = 0;

  Future<void> loadDaily({bool refresh = false}) async {
    unawaited(initActiveRank(refresh: refresh));
    if (loadingDaily || (!refresh && dailySongs.isNotEmpty)) return;
    loadingDaily = true;
    dailyError = null;
    notifyListeners();
    try {
      dailySongs = await repository.getDailyRecommendations();
      if (dailySongs.isEmpty) dailyError = '今天的推荐暂时还没准备好';
    } on AuthenticationRequiredException {
      dailyError = '登录后即可获取每日推荐';
    } catch (_) {
      dailyError = '获取每日推荐失败，请稍后重试';
    } finally {
      loadingDaily = false;
      notifyListeners();
    }
  }

  Future<Song?> startFm({Song? contextSong, String action = 'play'}) async {
    if (loadingFm) return null;
    final requestVersion = ++_fmRequestVersion;
    loadingFm = true;
    fmError = null;
    notifyListeners();
    try {
      final next = await repository.getPersonalFmSongs(
        action: action,
        contextSong: contextSong,
        mode: fmMode,
        songPoolId: fmSongPoolId,
        remainSongCount: fmSongs.length,
      );
      if (requestVersion != _fmRequestVersion) return null;
      final known = <String>{...fmSongs.map(_songKey)};
      final additions = next
          .where((song) => known.add(_songKey(song)))
          .toList();
      if (fmSongs.isEmpty || action == 'garbage') {
        fmSongs = additions;
      } else {
        fmSongs = [...fmSongs, ...additions];
      }
      if (fmSongs.isEmpty) fmError = '暂时没有可播放的私人 FM';
      return fmSongs.isEmpty ? null : fmSongs.first;
    } on AuthenticationRequiredException {
      fmError = '登录后即可开启私人 FM';
      return null;
    } catch (_) {
      fmError = '私人 FM 暂时不可用，请稍后重试';
      return null;
    } finally {
      if (requestVersion == _fmRequestVersion) {
        loadingFm = false;
        notifyListeners();
      }
    }
  }

  Future<Song?> dislikeFm(Song current, {int playtimeSeconds = 0}) async {
    fmSongs = fmSongs.where((song) => song.id != current.id).toList();
    final requestVersion = ++_fmRequestVersion;
    loadingFm = true;
    fmError = null;
    notifyListeners();
    try {
      final next = await repository.getPersonalFmSongs(
        action: 'garbage',
        contextSong: current,
        playtimeSeconds: playtimeSeconds,
        mode: fmMode,
        songPoolId: fmSongPoolId,
        remainSongCount: fmSongs.length,
      );
      if (requestVersion != _fmRequestVersion) return null;
      final known = <String>{...fmSongs.map(_songKey)};
      final additions = next
          .where((song) => known.add(_songKey(song)))
          .toList();
      fmSongs = [...fmSongs, ...additions];
      if (fmSongs.isEmpty) fmError = '暂时没有可播放的私人 FM';
      return fmSongs.isEmpty ? null : fmSongs.first;
    } on AuthenticationRequiredException {
      fmError = '登录后即可开启私人 FM';
      return fmSongs.isEmpty ? null : fmSongs.first;
    } catch (_) {
      fmError = '私人 FM 暂时不可用，请稍后重试';
      return fmSongs.isEmpty ? null : fmSongs.first;
    } finally {
      if (requestVersion == _fmRequestVersion) {
        loadingFm = false;
        notifyListeners();
      }
    }
  }

  Future<Song?> nextFm(Song? current, {bool dislike = false}) async {
    if (current != null) {
      if (dislike) {
        return dislikeFm(current);
      }
      fmSongs = fmSongs.where((song) => song.id != current.id).toList();
      notifyListeners();
    }
    if (fmSongs.isNotEmpty) return fmSongs.first;
    return startFm(contextSong: current, action: 'play');
  }

  Future<Song?> restartFm() async {
    _fmRequestVersion++;
    fmSongs = const [];
    fmError = null;
    loadingFm = false;
    notifyListeners();
    return startFm();
  }

  bool isFmSong(Song song) => fmSongs.any((item) => item.id == song.id);

  Future<List<Song>> syncFmPlayback(Song current) async {
    final index = fmSongs.indexWhere((song) => song.id == current.id);
    if (index < 0) return const [];
    if (index > 0) {
      fmSongs = fmSongs.sublist(index);
      notifyListeners();
    }
    if (fmSongs.length > 2 || loadingFm) return const [];

    final requestVersion = ++_fmRequestVersion;
    loadingFm = true;
    notifyListeners();
    try {
      final next = await repository.getPersonalFmSongs(
        contextSong: current,
        mode: fmMode,
        songPoolId: fmSongPoolId,
        remainSongCount: 0,
      );
      if (requestVersion != _fmRequestVersion) return const [];
      final known = <String>{...fmSongs.map(_songKey)};
      final additions = next
          .where((song) => known.add(_songKey(song)))
          .toList();
      fmSongs = [...fmSongs, ...additions];
      return additions;
    } catch (_) {
      return const [];
    } finally {
      if (requestVersion == _fmRequestVersion) {
        loadingFm = false;
        notifyListeners();
      }
    }
  }

  Future<Song?> selectFmProfile({
    required String mode,
    required int songPoolId,
  }) async {
    if (fmMode == mode && fmSongPoolId == songPoolId) return null;
    _fmRequestVersion++;
    fmMode = mode;
    fmSongPoolId = songPoolId;
    fmSongs = const [];
    fmError = null;
    notifyListeners();
    return startFm();
  }

  void clearAccountState() {
    _fmRequestVersion++;
    dailySongs = const [];
    fmSongs = const [];
    dailyError = null;
    fmError = null;
    fmMode = 'normal';
    fmSongPoolId = 0;
    loadingDaily = false;
    loadingFm = false;
    notifyListeners();
  }

  String _songKey(Song song) =>
      song.hash?.isNotEmpty == true ? song.hash! : song.id;
}
