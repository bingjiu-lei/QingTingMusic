import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/kugou_api_client.dart';
import '../data/music_repository.dart';
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
    this.repository,
    this.showTechnicalPlaybackNotices = false,
  }) {
    _subscriptions = [
      audioService.playingStream.listen((value) {
        isPlaying = value;
        if (!value) _nearEndTimer?.cancel();
        _schedulePlaybackStateSave();
        notifyListeners();
      }),
      // Progress ticks only update the progress ValueNotifier; they never
      // call notifyListeners, so per-second ticks don't rebuild the whole UI.
      audioService.positionStream.listen((value) {
        position = value;
        _syncProgress();
        _watchNearEnd();
        _schedulePlaybackStateSave();
      }),
      audioService.bufferedPositionStream.listen((value) {
        bufferedPosition = value;
        _syncProgress();
      }),
      audioService.durationStream.listen((value) {
        if (value != null && value != Duration.zero) {
          duration = value;
          _applyDetectedDuration(value);
        }
        _watchNearEnd();
        notifyListeners();
      }),
      audioService.completedStream.listen((_) {
        unawaited(_handleCompletion());
      }),
      audioService.errorStream.listen((message) {
        isPlaying = false;
        _hasOpenSource = false;
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
  final MusicRepository? repository;
  int _climaxRequestEpoch = 0;
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
  double playbackSpeed = 1.0;

  /// High-frequency progress channel: progress bar and lyrics subscribe to
  /// this instead of the whole controller.
  final ValueNotifier<({Duration position, Duration buffered})> progress =
      ValueNotifier((position: Duration.zero, buffered: Duration.zero));
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
  int _playRequestEpoch = 0;

  int get queueIndex {
    final song = currentSong;
    if (song == null) return -1;
    return queue.indexWhere((item) => item.id == song.id);
  }

  void _syncProgress() {
    progress.value = (position: position, buffered: bufferedPosition);
  }

  void _recordRecentSong(Song song) {
    recentSongs.removeWhere((item) => item.id == song.id);
    recentSongs.insert(0, song);
    if (recentSongs.length > RecentSongsService.maxItems) {
      recentSongs.removeLast();
    }
  }

  Future<void> _handleCompletion() async {
    if (_handlingCompletion || isPreparing || currentSong == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (isPreparing) return;
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
      _syncProgress();
      isPlaying = false;
      isPreparing = false;
      _hasOpenSource = false;
      playbackSpeed = snapshot.playbackSpeed.clamp(0.5, 2.0);
      if (playbackSpeed != 1.0) {
        try {
          await audioService.setSpeed(playbackSpeed);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  Future<bool> playSong(
    Song song, {
    List<Song>? fromQueue,
    Duration startPosition = Duration.zero,
    bool preserveShufflePath = false,
  }) async {
    final requestEpoch = ++_playRequestEpoch;
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
      // Stop an in-flight source switch before resolving the new song. The
      // resolver itself remains uncancelable, so requestEpoch below ensures a
      // stale result can never reopen the old song afterward.
      await audioService.cancelPendingOpen();
      if (requestEpoch != _playRequestEpoch) return false;
      errorText = null;
      playbackNotice = null;
      _noticeTimer?.cancel();
      _nearEndTimer?.cancel();
      currentSong = song;
      position = _safeStartPosition(startPosition, song.duration);
      bufferedPosition = Duration.zero;
      _syncProgress();
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
      if (requestEpoch != _playRequestEpoch) return false;
      currentSong = playableSong;
      _showPlaybackNotice(playableSong.playbackNotice);

      final climaxRequestEpoch = ++_climaxRequestEpoch;
      if (playableSong.climaxSegments.isEmpty &&
          playableSong.hash != null &&
          playableSong.hash!.isNotEmpty &&
          repository != null) {
        unawaited(
          repository!.getSongClimax(playableSong.hash!).then((segments) {
            if (climaxRequestEpoch == _climaxRequestEpoch &&
                currentSong?.id == playableSong.id) {
              final validSegments = segments
                  .where(
                    (segment) =>
                        segment.start > Duration.zero &&
                        segment.start < playableSong.duration &&
                        segment.end >= segment.start,
                  )
                  .toList(growable: false);
              if (validSegments.isEmpty) return;
              currentSong = currentSong!.copyWith(
                climaxSegments: validSegments,
              );
              notifyListeners();
            }
          }),
        );
      }

      if (!audioService.isEnabled) {
        isPlaying = true;
        isPreparing = false;
        _hasOpenSource = true;
        _recordRecentSong(playableSong);
        unawaited(_saveRecentSongs());
        _schedulePlaybackStateSave(immediate: true);
        notifyListeners();
        return true;
      }

      notifyListeners();
      try {
        await audioService.open(playableSong);
        if (requestEpoch != _playRequestEpoch) return false;
        _hasOpenSource = true;
        final detectedDuration = audioService.currentDuration;
        if (detectedDuration != null && detectedDuration > Duration.zero) {
          // 高潮标记是异步请求的：请求可能在 open() 等待期间完成。
          // 这里必须从 currentSong 保留已回写的片段，不能再用旧的
          // playableSong 覆盖它，否则底栏和播放详情页都会只闪一下标记。
          final loadedSegments = currentSong?.id == playableSong.id
              ? currentSong!.climaxSegments
              : playableSong.climaxSegments;
          playableSong = playableSong.copyWith(
            duration: detectedDuration,
            climaxSegments: loadedSegments,
          );
          currentSong = playableSong;
          duration = detectedDuration;
          _replaceSongInQueue(playableSong);
        }
        if (playbackSpeed != 1.0) {
          try {
            await audioService.setSpeed(playbackSpeed);
          } catch (_) {}
        }
        if (position > Duration.zero) {
          await audioService.seek(position);
        }
        _songStartedAt = DateTime.now();
      } catch (error, stackTrace) {
        await PlaybackLogService.write('open', error, stackTrace);
        rethrow;
      }
      // Only a song that actually opened counts as recently played.
      _recordRecentSong(playableSong);
      unawaited(_saveRecentSongs());
      _schedulePlaybackStateSave(immediate: true);
      isPreparing = false;
      notifyListeners();
      return true;
    } on AuthenticationRequiredException {
      if (requestEpoch != _playRequestEpoch) return false;
      _handlePlaybackFailure(
        attemptedSong: song,
        previousSong: previousSong,
        previousPosition: previousPosition,
        previousBufferedPosition: previousBufferedPosition,
        previousDuration: previousDuration,
        previousWasPlaying: previousWasPlaying,
        message: '登录后即可播放在线歌曲',
      );
      return false;
    } on KugouApiException catch (error) {
      if (requestEpoch != _playRequestEpoch) return false;
      _handlePlaybackFailure(
        attemptedSong: song,
        previousSong: previousSong,
        previousPosition: previousPosition,
        previousBufferedPosition: previousBufferedPosition,
        previousDuration: previousDuration,
        previousWasPlaying: previousWasPlaying,
        message: error.message,
      );
      return false;
    } catch (error) {
      if (requestEpoch != _playRequestEpoch) return false;
      _handlePlaybackFailure(
        attemptedSong: song,
        previousSong: previousSong,
        previousPosition: previousPosition,
        previousBufferedPosition: previousBufferedPosition,
        previousDuration: previousDuration,
        previousWasPlaying: previousWasPlaying,
        message: '播放失败：$error',
      );
      return false;
    }
  }

  void _applyDetectedDuration(Duration value) {
    final song = currentSong;
    if (song == null || song.duration == value) return;
    final updated = song.copyWith(duration: value);
    currentSong = updated;
    _replaceSongInQueue(updated);
  }

  void _replaceSongInQueue(Song song) {
    final index = queue.indexWhere((item) => item.id == song.id);
    if (index < 0) return;
    final updated = List<Song>.of(queue)..[index] = song;
    queue = List.unmodifiable(updated);
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
      // A superseded request pauses the old source immediately. Resume it if
      // resolving the replacement fails so failure recovery keeps its prior
      // behavior.
      unawaited(audioService.play());
    } else {
      currentSong = attemptedSong;
      position = Duration.zero;
      bufferedPosition = Duration.zero;
      duration = attemptedSong.duration;
      isPlaying = false;
      _hasOpenSource = false;
    }
    _syncProgress();
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

  /// Plays all songs in [songs]. If currently in [PlaybackMode.shuffle], picks
  /// a random song to start immediately instead of starting from songs.first.
  Future<bool> playAll(List<Song> songs) async {
    if (songs.isEmpty) return false;
    Song startSong = songs.first;
    if (playbackMode == PlaybackMode.shuffle) {
      startSong = songs[_random.nextInt(songs.length)];
    }
    return playSong(startSong, fromQueue: songs);
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
      _syncProgress();
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
    _syncProgress();
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

    if (audioService.isCompleted) {
      await playSong(
        song,
        fromQueue: queue.isEmpty ? [song] : queue,
        preserveShufflePath: playbackMode == PlaybackMode.shuffle,
      );
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
    var sourceIndex = currentIndex;
    for (var attempt = 0; attempt < queue.length; attempt++) {
      final targetIndex = _targetIndex(sourceIndex, offset, autoAdvance);
      if (targetIndex == null) {
        await _stopAtQueueEnd();
        return;
      }
      final requestEpoch = _playRequestEpoch + 1;
      final played = await playSong(queue[targetIndex], fromQueue: queue);
      if (requestEpoch != _playRequestEpoch) return;
      if (played) return;
      sourceIndex = targetIndex;
    }
    await _stopAtQueueEnd();
  }

  Future<void> _stopAtQueueEnd() async {
    await audioService.pause();
    _nearEndTimer?.cancel();
    isPlaying = false;
    position = duration;
    _syncProgress();
    _hasOpenSource = false;
    _schedulePlaybackStateSave(immediate: true);
    notifyListeners();
  }

  Future<void> _playShuffleNext() async {
    final current = currentSong;
    if (current == null || queue.length <= 1) return;
    _sanitizeShufflePath();
    if (_shuffleUpcoming.isEmpty) {
      _refillShuffleUpcoming(excluding: current.id);
    }
    if (_shuffleUpcoming.isEmpty) return;
    while (_shuffleUpcoming.isNotEmpty) {
      final targetId = _shuffleUpcoming.removeAt(0);
      final target = _songForId(targetId);
      if (target == null) continue;
      final requestEpoch = _playRequestEpoch + 1;
      // Record the listening path when the user chooses the target, not after
      // its network source finishes opening. A superseded rapid request is
      // still a real navigation step and must remain available to Previous.
      _shuffleHistory.add(current.id);
      final played = await playSong(
        target,
        fromQueue: queue,
        preserveShufflePath: true,
      );
      if (requestEpoch != _playRequestEpoch) return;
      if (!played) {
        if (_shuffleHistory.isNotEmpty && _shuffleHistory.last == current.id) {
          _shuffleHistory.removeLast();
        }
        continue;
      }
      return;
    }
    await _stopAtQueueEnd();
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
    final requestEpoch = _playRequestEpoch + 1;
    final played = await playSong(
      target,
      fromQueue: queue,
      preserveShufflePath: true,
    );
    if (requestEpoch != _playRequestEpoch) return;
    if (!played) _shuffleHistory.add(targetId);
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
    _syncProgress();
    _schedulePlaybackStateSave();
    notifyListeners();
    if (audioService.isCompleted && currentSong != null) {
      await playSong(
        currentSong!,
        fromQueue: queue.isEmpty ? [currentSong!] : queue,
        startPosition: position,
        preserveShufflePath: playbackMode == PlaybackMode.shuffle,
      );
      return;
    }
    await audioService.seek(position);
  }

  Future<void> setVolume(double value) async {
    volume = value.clamp(0.0, 1.0);
    notifyListeners();
    await audioService.setVolume(volume);
  }

  Future<void> setPlaybackSpeed(double value) async {
    final clamped = value.clamp(0.5, 2.0).toDouble();
    if (playbackSpeed == clamped) return;
    playbackSpeed = clamped;
    notifyListeners();
    await audioService.setSpeed(clamped);
    _schedulePlaybackStateSave(immediate: true);
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
          playbackSpeed: playbackSpeed,
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
    progress.dispose();
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
