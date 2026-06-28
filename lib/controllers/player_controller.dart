import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/kugou_api_client.dart';
import '../services/recent_songs_service.dart';
import '../services/playback_log_service.dart';

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
  }) {
    _subscriptions = [
      audioService.playingStream.listen((value) {
        isPlaying = value;
        if (!value) _nearEndTimer?.cancel();
        notifyListeners();
      }),
      audioService.positionStream.listen((value) {
        position = value;
        _watchNearEnd();
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
    ];
  }

  final AudioPlayerService audioService;
  final Future<Song> Function(Song song)? resolveSong;
  final RecentSongsService? recentSongsService;
  late final List<StreamSubscription<Object?>> _subscriptions;

  List<Song> queue = const [];
  PlaybackMode playbackMode = PlaybackMode.sequence;
  Song? currentSong;
  bool isPlaying = false;
  bool isPreparing = false;
  Duration position = Duration.zero;
  Duration bufferedPosition = Duration.zero;
  Duration duration = Duration.zero;
  String? errorText;
  String? playbackNotice;
  final List<Song> recentSongs = [];
  bool _handlingCompletion = false;
  Timer? _noticeTimer;
  Timer? _nearEndTimer;
  DateTime? _songStartedAt;
  final Random _random = Random();

  int get queueIndex {
    final song = currentSong;
    if (song == null) return -1;
    return queue.indexWhere((item) => item.id == song.id);
  }

  Future<void> _handleCompletion() async {
    if (_handlingCompletion || isPreparing || currentSong == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (isPreparing || duration <= Duration.zero) return;
    final remaining = duration - position;
    final playedLongEnough =
        DateTime.now().difference(_songStartedAt ?? DateTime.now()) >
        const Duration(milliseconds: 700);
    if (!playedLongEnough && remaining > const Duration(seconds: 2)) return;
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
    notifyListeners();
  }

  Future<void> playSong(Song song, {List<Song>? fromQueue}) async {
    if (fromQueue != null && fromQueue.isNotEmpty) {
      queue = List.unmodifiable(fromQueue);
    } else if (!queue.any((item) => item.id == song.id)) {
      queue = [song];
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
      position = Duration.zero;
      bufferedPosition = Duration.zero;
      duration = song.duration;
      isPreparing = true;
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
        unawaited(_saveRecentSongs());
        notifyListeners();
        return;
      }

      notifyListeners();
      try {
        await audioService.open(playableSong);
        _songStartedAt = DateTime.now();
      } catch (error, stackTrace) {
        await PlaybackLogService.write('open', error, stackTrace);
        rethrow;
      }
      unawaited(_saveRecentSongs());
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
    } else {
      currentSong = attemptedSong;
      position = Duration.zero;
      bufferedPosition = Duration.zero;
      duration = attemptedSong.duration;
      isPlaying = false;
    }
    notifyListeners();
  }

  void cyclePlaybackMode() {
    final values = PlaybackMode.values;
    final nextIndex = (values.indexOf(playbackMode) + 1) % values.length;
    playbackMode = values[nextIndex];
    notifyListeners();
  }

  void replaceQueue(List<Song> songs, {Song? current}) {
    queue = List.unmodifiable(_dedupeSongs(songs));
    if (current != null && !queue.any((item) => item.id == current.id)) {
      queue = List.unmodifiable([current, ...queue]);
    }
    notifyListeners();
  }

  Future<void> playQueueSong(Song song) async {
    await playSong(song, fromQueue: queue.isEmpty ? [song] : queue);
  }

  Future<void> removeFromQueue(Song song) async {
    final wasCurrent = currentSong?.id == song.id;
    final nextQueue = queue.where((item) => item.id != song.id).toList();
    queue = List.unmodifiable(nextQueue);
    notifyListeners();
    if (!wasCurrent) return;
    if (queue.isEmpty) {
      await audioService.pause();
      currentSong = null;
      isPlaying = false;
      position = Duration.zero;
      bufferedPosition = Duration.zero;
      duration = Duration.zero;
      notifyListeners();
      return;
    }
    await playSong(queue.first, fromQueue: queue);
  }

  void clearQueue() {
    final song = currentSong;
    queue = song == null ? const [] : List.unmodifiable([song]);
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
        notifyListeners();
      }
      return;
    }

    if (song.audioUrl.isNotEmpty) {
      unawaited(audioService.play());
      return;
    }

    await playSong(song);
    if (!audioService.isEnabled) {
      isPlaying = true;
      notifyListeners();
    }
  }

  Future<void> playPrevious() async => _playOffset(-1);

  Future<void> playNext({bool autoAdvance = false}) async {
    if (autoAdvance && playbackMode == PlaybackMode.repeatOne) {
      final song = currentSong;
      if (song != null) await playSong(song, fromQueue: queue);
      return;
    }
    await _playOffset(1, autoAdvance: autoAdvance);
  }

  Future<void> _playOffset(int offset, {bool autoAdvance = false}) async {
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
      notifyListeners();
      return;
    }
    await playSong(queue[targetIndex], fromQueue: queue);
  }

  int? _targetIndex(int currentIndex, int offset, bool autoAdvance) {
    if (queue.length == 1) {
      return playbackMode == PlaybackMode.repeatAll ||
              playbackMode == PlaybackMode.repeatOne
          ? 0
          : null;
    }
    if (playbackMode == PlaybackMode.shuffle && offset > 0) {
      var next = _random.nextInt(queue.length);
      if (next == currentIndex) next = (next + 1) % queue.length;
      return next;
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
    position = target;
    notifyListeners();
    await audioService.seek(target);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _noticeTimer?.cancel();
    _nearEndTimer?.cancel();
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
