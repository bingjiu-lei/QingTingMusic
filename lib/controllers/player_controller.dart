import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/kugou_api_client.dart';
import '../services/recent_songs_service.dart';
import '../services/playback_log_service.dart';
import '../services/playback_state_service.dart';

enum PlaybackMode {
  sequence('顺序播放'),
  repeatAll('列表循环'),
  repeatOne('单曲循环'),
  shuffle('随机播放');

  const PlaybackMode(this.label);

  final String label;
}

class PlayerController extends ChangeNotifier {
  PlayerController({
    required this.audioService,
    this.resolveSong,
    this.recentSongsService,
    this.playbackStateService,
    this.showTechnicalPlaybackNotices = false,
  }) {
    _subscriptions = [
      audioService.playingStream.listen((value) {
        isPlaying = value;
        if (!value) _nearEndTimer?.cancel();
        _schedulePlaybackStateSave();
        notifyListeners();
      }),
      audioService.positionStream.listen((value) {
        position = value;
        _watchNearEnd();
        _schedulePlaybackStateSave();
        notifyListeners();
      }),
      audioService.bufferedPositionStream.listen((value) {
        bufferedPosition = value;
        notifyListeners();
      }),
      audioService.durationStream.listen((value) {
        if (value != null && value != Duration.zero) duration = value;
        _watchNearEnd();
        notifyListeners();
      }),
      audioService.completedStream.listen((_) {
        unawaited(_handleCompletion());
      }),
      audioService.errorStream.listen((message) {
        isPlaying = false;
        errorText = message.isEmpty ? '播放失败，请稍后重试。' : message;
        notifyListeners();
      }),
      audioService.technicalNoticeStream.listen((message) {
        if (!showTechnicalPlaybackNotices) return;
        _showPlaybackNotice(message);
        notifyListeners();
      }),
    ];
  }

  final AudioPlayerService audioService;
  final Future<Song> Function(Song song)? resolveSong;
  final RecentSongsService? recentSongsService;
  final PlaybackStateService? playbackStateService;
  late final List<StreamSubscription<Object?>> _subscriptions;

  List<Song> queue = const [];
  PlaybackMode playbackMode = PlaybackMode.sequence;
  Song? currentSong;
  bool isPlaying = false;
  bool isPreparing = false;
  Duration position = Duration.zero;
  Duration bufferedPosition = Duration.zero;
  Duration duration = Duration.zero;
  double volume = 0.78;
  String? errorText;
  String? playbackNotice;
  final List<Song> recentSongs = [];
  bool _handlingCompletion = false;
  bool showTechnicalPlaybackNotices;
  Timer? _noticeTimer;
  Timer? _nearEndTimer;
  Timer? _savePlaybackTimer;
  DateTime? _songStartedAt;
  final Random _random = Random();
  final List<String> _shuffleHistory = [];
  final List<String> _shuffleUpcoming = [];
  bool _hasOpenSource = false;

  int get queueIndex {
    final song = currentSong;
    if (song == null) return -1;
    return queue.indexWhere((item) => item.id == song.id);
  }

  Future<void> _handleCompletion() async {
    if (_handlingCompletion || isPreparing || currentSong == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (isPreparing || duration <= Duration.zero) return;
    final playedLongEnough =
        DateTime.now().difference(_songStartedAt ?? DateTime.now()) >
        const Duration(milliseconds: 700);
    if (!playedLongEnough) return;
    _handlingCompletion = true;
    try {
      await playNext(autoAdvance: true);
    } finally {
      _handlingCompletion = false;
    }
  }

  Future<void> initialize() async {
    final saved = await recentSongsService?.load() ?? const [];
    recentSongs
      ..clear()
      ..addAll(saved);
    final snapshot = await playbackStateService?.load();
    if (snapshot != null) {
      queue = List.unmodifiable(_dedupeSongs(snapshot.queue));
      currentSong = snapshot.currentSong;
      playbackMode = snapshot.playbackMode;
      _shuffleHistory
        ..clear()
        ..addAll(snapshot.shuffleHistory);
      _shuffleUpcoming
        ..clear()
        ..addAll(snapshot.shuffleUpcoming);
      _sanitizeShufflePath();
      position = snapshot.position;
      duration = snapshot.currentSong?.duration ?? Duration.zero;
      bufferedPosition = Duration.zero;
      isPlaying = false;
      isPreparing = false;
      _hasOpenSource = false;
    }
    notifyListeners();
  }

  Future<void> playSong(
    Song song, {
    List<Song>? fromQueue,
    Duration startPosition = Duration.zero,
    bool preserveShufflePath = false,
  }) async {
    if (fromQueue != null && fromQueue.isNotEmpty) {
      queue = List.unmodifiable(_dedupeSongs(fromQueue));
    } else if (!queue.any((item) => item.id == song.id)) {
      queue = List.unmodifiable([song]);
    }
    if (playbackMode == PlaybackMode.shuffle && !preserveShufflePath) {
      _startShufflePath(anchorId: song.id);
    }

    final previousSong = currentSong;
    final previousPosition = position;
    final previousBufferedPosition = bufferedPosition;
    final previousDuration = duration;
    final previousWasPlaying = isPlaying || audioService.isPlaying;

    try {
      errorText = null;
      playbackNotice = null;
      _noticeTimer?.cancel();
      _nearEndTimer?.cancel();
      currentSong = song;
      position = _safeStartPosition(startPosition, song.duration);
      bufferedPosition = Duration.zero;
      duration = song.duration;
      isPreparing = true;
      _hasOpenSource = false;
      notifyListeners();
      Song playableSong;
      try {
        playableSong = await (resolveSong?.call(song) ?? Future.value(song));
      } catch (error, stackTrace) {
        await PlaybackLogService.write('resolve', error, stackTrace);
        rethrow;
      }
      currentSong = playableSong;
      _showPlaybackNotice(playableSong.playbackNotice);
      recentSongs.removeWhere((item) => item.id == playableSong.id);
      recentSongs.insert(0, playableSong);
      if (recentSongs.length > RecentSongsService.maxItems) {
        recentSongs.removeLast();
      }

      if (!audioService.isEnabled) {
        isPlaying = true;
        isPreparing = false;
        _hasOpenSource = true;
        unawaited(_saveRecentSongs());
        _schedulePlaybackStateSave(immediate: true);
        notifyListeners();
        return;
      }

      notifyListeners();
      try {
        await audioService.open(playableSong);
        _hasOpenSource = true;
        if (position > Duration.zero) {
          await audioService.seek(position);
        }
        _songStartedAt = DateTime.now();
      } catch (error, stackTrace) {
        await PlaybackLogService.write('open', error, stackTrace);
        rethrow;
      }
      unawaited(_saveRecentSongs());
      _schedulePlaybackStateSave(immediate: true);
      isPreparing = false;
      notifyListeners();
    } on AuthenticationRequiredException {
      _handlePlaybackFailure(
        attemptedSong: song,
        previousSong: previousSong,
        previousPosition: previousPosition,
        previousBufferedPosition: previousBufferedPosition,
        previousDuration: previousDuration,
        previousWasPlaying: previousWasPlaying,
        message: '登录后即可播放在线歌曲',
      );
    } on KugouApiException catch (error) {
      _handlePlaybackFailure(
        attemptedSong: song,
        previousSong: previousSong,
        previousPosition: previousPosition,
        previousBufferedPosition: previousBufferedPosition,
        previousDuration: previousDuration,
        previousWasPlaying: previousWasPlaying,
        message: error.message,
      );
    } catch (error) {
      _handlePlaybackFailure(
        attemptedSong: song,
        previousSong: previousSong,
        previousPosition: previousPosition,
        previousBufferedPosition: previousBufferedPosition,
        previousDuration: previousDuration,
        previousWasPlaying: previousWasPlaying,
        message: '播放失败：$error',
      );
    }
  }

  void _handlePlaybackFailure({
    required Song attemptedSong,
    required Song? previousSong,
    required Duration previousPosition,
    required Duration previousBufferedPosition,
    required Duration previousDuration,
    required bool previousWasPlaying,
    required String message,
  }) {
    isPreparing = false;
    errorText = '${attemptedSong.title}：$message';
    if (previousSong != null && previousWasPlaying) {
      currentSong = previousSong;
      position = previousPosition;
      bufferedPosition = previousBufferedPosition;
      duration = previousDuration;
      isPlaying = true;
      _hasOpenSource = true;
    } else {
      currentSong = attemptedSong;
      position = Duration.zero;
      bufferedPosition = Duration.zero;
      duration = attemptedSong.duration;
      isPlaying = false;
      _hasOpenSource = false;
    }
    _schedulePlaybackStateSave();
    notifyListeners();
  }

  void cyclePlaybackMode() {
    final values = PlaybackMode.values;
    final nextIndex = (values.indexOf(playbackMode) + 1) % values.length;
    playbackMode = values[nextIndex];
    if (playbackMode == PlaybackMode.shuffle) {
      _startShufflePath(anchorId: currentSong?.id);
    } else {
      _clearShufflePath();
    }
    _schedulePlaybackStateSave(immediate: true);
    notifyListeners();
  }

  void setPlaybackMode(PlaybackMode mode) {
    if (playbackMode == mode) return;
    playbackMode = mode;
    if (mode == PlaybackMode.shuffle) {
      _startShufflePath(anchorId: currentSong?.id);
    } else {
      _clearShufflePath();
    }
    _schedulePlaybackStateSave(immediate: true);
    notifyListeners();
  }

  void setTechnicalPlaybackNoticesEnabled(bool value) {
    if (showTechnicalPlaybackNotices == value) return;
    showTechnicalPlaybackNotices = value;
    if (!value &&
        (playbackNotice == '已使用本地缓存' || playbackNotice == '本地缓存不可用，已切换在线播放')) {
      playbackNotice = null;
      _noticeTimer?.cancel();
      notifyListeners();
    }
  }

  void replaceQueue(List<Song> songs, {Song? current}) {
    queue = List.unmodifiable(_dedupeSongs(songs));
    if (current != null && !queue.any((item) => item.id == current.id)) {
      queue = List.unmodifiable([current, ...queue]);
    }
    if (playbackMode == PlaybackMode.shuffle) {
      _startShufflePath(anchorId: currentSong?.id ?? current?.id);
    }
    _schedulePlaybackStateSave();
    notifyListeners();
  }

  void appendQueue(List<Song> songs) {
    if (songs.isEmpty) return;
    queue = List.unmodifiable(_dedupeSongs([...queue, ...songs]));
    if (playbackMode == PlaybackMode.shuffle) {
      _startShufflePath(anchorId: currentSong?.id);
    }
    _schedulePlaybackStateSave();
    notifyListeners();
  }

  Future<void> playQueueSong(Song song) async {
    if (playbackMode == PlaybackMode.shuffle && currentSong?.id != song.id) {
      _recordManualShuffleSelection(song.id);
      await playSong(
        song,
        fromQueue: queue.isEmpty ? [song] : queue,
        preserveShufflePath: true,
      );
      return;
    }
    await playSong(song, fromQueue: queue.isEmpty ? [song] : queue);
  }

  Future<void> removeFromQueue(Song song) async {
    final wasCurrent = currentSong?.id == song.id;
    final nextQueue = queue.where((item) => item.id != song.id).toList();
    queue = List.unmodifiable(nextQueue);
    _sanitizeShufflePath();
    _schedulePlaybackStateSave();
    notifyListeners();
    if (!wasCurrent) return;
    if (queue.isEmpty) {
      await audioService.pause();
      currentSong = null;
      isPlaying = false;
      position = Duration.zero;
      bufferedPosition = Duration.zero;
      duration = Duration.zero;
      _hasOpenSource = false;
      _schedulePlaybackStateSave(immediate: true);
      notifyListeners();
      return;
    }
    if (playbackMode == PlaybackMode.shuffle) {
      await _playShuffleNext();
      return;
    }
    await playSong(queue.first, fromQueue: queue);
  }

  void clearQueue() {
    final song = currentSong;
    queue = song == null ? const [] : List.unmodifiable([song]);
    _startShufflePath(anchorId: song?.id);
    _schedulePlaybackStateSave(immediate: true);
    notifyListeners();
  }

  Future<void> clearAccountState() async {
    _noticeTimer?.cancel();
    _nearEndTimer?.cancel();
    await audioService.pause();
    queue = const [];
    _clearShufflePath();
    currentSong = null;
    isPlaying = false;
    isPreparing = false;
    position = Duration.zero;
    bufferedPosition = Duration.zero;
    duration = Duration.zero;
    errorText = null;
    playbackNotice = null;
    recentSongs.clear();
    _hasOpenSource = false;
    unawaited(_saveRecentSongs());
    await playbackStateService?.clear();
    notifyListeners();
  }

  void _watchNearEnd() {
    final song = currentSong;
    if (!isPlaying ||
        isPreparing ||
        song == null ||
        duration <= Duration.zero) {
      _nearEndTimer?.cancel();
      return;
    }

    final remaining = duration - position;
    if (remaining > const Duration(milliseconds: 1500)) {
      _nearEndTimer?.cancel();
      return;
    }

    if (_nearEndTimer?.isActive ?? false) return;
    final songId = song.id;
    _nearEndTimer = Timer(const Duration(milliseconds: 1700), () {
      if (currentSong?.id != songId ||
          !isPlaying ||
          isPreparing ||
          duration <= Duration.zero) {
        return;
      }
      final latestRemaining = duration - position;
      if (latestRemaining <= const Duration(milliseconds: 1500)) {
        unawaited(_handleCompletion());
      }
    });
  }

  Future<void> _saveRecentSongs() async {
    try {
      await recentSongsService?.save(recentSongs);
    } catch (error, stackTrace) {
      await PlaybackLogService.write('recent-songs', error, stackTrace);
    }
  }

  void _showPlaybackNotice(String? message) {
    _noticeTimer?.cancel();
    playbackNotice = message == null || message.isEmpty ? null : message;
    if (playbackNotice == null) return;
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      playbackNotice = null;
      notifyListeners();
    });
  }

  Future<void> togglePlay() async {
    final song = currentSong;
    if (song == null) return;

    if (isPlaying) {
      await audioService.pause();
      if (!audioService.isEnabled) {
        isPlaying = false;
        _schedulePlaybackStateSave(immediate: true);
        notifyListeners();
      }
      return;
    }

    if (song.audioUrl.isNotEmpty && _hasOpenSource) {
      unawaited(audioService.play());
      return;
    }

    await playSong(
      song,
      fromQueue: queue.isEmpty ? [song] : queue,
      startPosition: position,
      preserveShufflePath: playbackMode == PlaybackMode.shuffle,
    );
    if (!audioService.isEnabled) {
      isPlaying = true;
      notifyListeners();
    }
  }

  Future<void> playPrevious() async {
    if (playbackMode == PlaybackMode.shuffle) {
      await _playShufflePrevious();
      return;
    }
    await _playOffset(-1);
  }

  Future<void> playNext({bool autoAdvance = false}) async {
    if (autoAdvance && playbackMode == PlaybackMode.repeatOne) {
      final song = currentSong;
      if (song != null) await playSong(song, fromQueue: queue);
      return;
    }
    await _playOffset(1, autoAdvance: autoAdvance);
  }

  Future<void> _playOffset(int offset, {bool autoAdvance = false}) async {
    if (playbackMode == PlaybackMode.shuffle && offset > 0) {
      await _playShuffleNext();
      return;
    }
    final song = currentSong;
    if (song == null || queue.isEmpty) return;
    final currentIndex = queue.indexWhere((item) => item.id == song.id);
    if (currentIndex < 0) return;
    final targetIndex = _targetIndex(currentIndex, offset, autoAdvance);
    if (targetIndex == null) {
      await audioService.pause();
      _nearEndTimer?.cancel();
      isPlaying = false;
      position = duration;
      _hasOpenSource = false;
      _schedulePlaybackStateSave(immediate: true);
      notifyListeners();
      return;
    }
    await playSong(queue[targetIndex], fromQueue: queue);
  }

  Future<void> _playShuffleNext() async {
    final current = currentSong;
    if (current == null || queue.length <= 1) return;
    _sanitizeShufflePath();
    if (_shuffleUpcoming.isEmpty) {
      _refillShuffleUpcoming(excluding: current.id);
    }
    if (_shuffleUpcoming.isEmpty) return;
    final targetId = _shuffleUpcoming.removeAt(0);
    final target = _songForId(targetId);
    if (target == null) {
      _sanitizeShufflePath();
      await _playShuffleNext();
      return;
    }
    _shuffleHistory.add(current.id);
    await playSong(target, fromQueue: queue, preserveShufflePath: true);
  }

  Future<void> _playShufflePrevious() async {
    final current = currentSong;
    if (current == null || _shuffleHistory.isEmpty) return;
    _sanitizeShufflePath();
    if (_shuffleHistory.isEmpty) return;
    final targetId = _shuffleHistory.removeLast();
    final target = _songForId(targetId);
    if (target == null) {
      await _playShufflePrevious();
      return;
    }
    _shuffleUpcoming
      ..remove(targetId)
      ..remove(current.id)
      ..insert(0, current.id);
    await playSong(target, fromQueue: queue, preserveShufflePath: true);
  }

  int? _targetIndex(int currentIndex, int offset, bool autoAdvance) {
    if (queue.length == 1) {
      return playbackMode == PlaybackMode.repeatAll ||
              playbackMode == PlaybackMode.repeatOne
          ? 0
          : null;
    }
    final raw = currentIndex + offset;
    if (raw >= 0 && raw < queue.length) return raw;
    if (playbackMode == PlaybackMode.repeatAll || !autoAdvance) {
      return (raw + queue.length) % queue.length;
    }
    return null;
  }

  Future<void> seekByRatio(double ratio) async {
    final safeRatio = ratio.clamp(0.0, 1.0);
    final target = duration * safeRatio;
    await seek(target);
  }

  Future<void> seek(Duration target) async {
    final safeTarget = duration > Duration.zero && target > duration
        ? duration
        : target;
    position = safeTarget < Duration.zero ? Duration.zero : safeTarget;
    _schedulePlaybackStateSave();
    notifyListeners();
    await audioService.seek(position);
  }

  Future<void> setVolume(double value) async {
    volume = value.clamp(0.0, 1.0);
    notifyListeners();
    await audioService.setVolume(volume);
  }

  void _schedulePlaybackStateSave({bool immediate = false}) {
    if (playbackStateService == null) return;
    if (!immediate && (_savePlaybackTimer?.isActive ?? false)) return;
    if (immediate) _savePlaybackTimer?.cancel();
    final delay = immediate ? Duration.zero : const Duration(seconds: 2);
    _savePlaybackTimer = Timer(delay, () {
      unawaited(_savePlaybackState());
    });
  }

  Future<void> flushPlaybackState() async {
    _savePlaybackTimer?.cancel();
    await _savePlaybackState();
  }

  Future<void> _savePlaybackState() async {
    try {
      await playbackStateService?.save(
        PlaybackSnapshot(
          queue: queue,
          currentSong: currentSong,
          position: position,
          playbackMode: playbackMode,
          shuffleHistory: List.unmodifiable(_shuffleHistory),
          shuffleUpcoming: List.unmodifiable(_shuffleUpcoming),
        ),
      );
    } catch (error, stackTrace) {
      await PlaybackLogService.write('playback-state', error, stackTrace);
    }
  }

  void updateSongFavorite(Song song, bool liked) {
    bool sameSong(Song item) =>
        item.id == song.id || (song.hash != null && item.hash == song.hash);
    if (currentSong != null && sameSong(currentSong!)) {
      currentSong = currentSong!.copyWith(liked: liked);
    }
    queue = List.unmodifiable([
      for (final item in queue)
        sameSong(item) ? item.copyWith(liked: liked) : item,
    ]);
    for (var index = 0; index < recentSongs.length; index++) {
      if (sameSong(recentSongs[index])) {
        recentSongs[index] = recentSongs[index].copyWith(liked: liked);
      }
    }
    notifyListeners();
  }

  void _startShufflePath({String? anchorId}) {
    _clearShufflePath();
    if (playbackMode != PlaybackMode.shuffle || queue.length <= 1) return;
    _refillShuffleUpcoming(excluding: anchorId);
  }

  void _recordManualShuffleSelection(String targetId) {
    final current = currentSong;
    if (current != null && current.id != targetId) {
      _shuffleHistory.add(current.id);
    }
    _shuffleUpcoming
      ..clear()
      ..addAll(queue.map((song) => song.id).where((id) => id != targetId));
    _shuffleUpcoming.shuffle(_random);
  }

  void _refillShuffleUpcoming({String? excluding}) {
    _shuffleUpcoming
      ..clear()
      ..addAll(queue.map((song) => song.id).where((id) => id != excluding));
    _shuffleUpcoming.shuffle(_random);
  }

  void _sanitizeShufflePath() {
    final validIds = queue.map((song) => song.id).toSet();
    _shuffleHistory.removeWhere((id) => !validIds.contains(id));
    _shuffleUpcoming.removeWhere((id) => !validIds.contains(id));
    final currentId = currentSong?.id;
    if (currentId != null) _shuffleUpcoming.remove(currentId);
  }

  void _clearShufflePath() {
    _shuffleHistory.clear();
    _shuffleUpcoming.clear();
  }

  Song? _songForId(String id) {
    for (final song in queue) {
      if (song.id == id) return song;
    }
    return null;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _noticeTimer?.cancel();
    _nearEndTimer?.cancel();
    _savePlaybackTimer?.cancel();
    unawaited(_savePlaybackState());
    audioService.dispose();
    super.dispose();
  }
}

List<Song> _dedupeSongs(List<Song> songs) {
  final seen = <String>{};
  return [
    for (final song in songs)
      if (seen.add(song.id)) song,
  ];
}

Duration _safeStartPosition(Duration value, Duration duration) {
  if (value <= Duration.zero) return Duration.zero;
  if (duration <= Duration.zero) return value;
  final latestSafe = duration - const Duration(seconds: 2);
  if (latestSafe <= Duration.zero) return Duration.zero;
  return value > latestSafe ? latestSafe : value;
}
