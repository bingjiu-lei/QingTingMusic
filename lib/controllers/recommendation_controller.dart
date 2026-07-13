import 'package:flutter/foundation.dart';

import '../data/music_repository.dart';
import '../models/song.dart';
import '../services/kugou_api_client.dart';

class RecommendationController extends ChangeNotifier {
  RecommendationController(this.repository);

  final MusicRepository repository;

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

  Future<Song?> nextFm(Song? current, {bool dislike = false}) async {
    if (current != null) {
      fmSongs = fmSongs.where((song) => song.id != current.id).toList();
      notifyListeners();
    }
    if (fmSongs.isNotEmpty) return fmSongs.first;
    return startFm(contextSong: current, action: dislike ? 'garbage' : 'play');
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
