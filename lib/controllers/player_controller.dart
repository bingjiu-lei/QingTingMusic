import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/kugou_api_client.dart';
import '../services/recent_songs_service.dart';
import '../services/playback_log_service.dart';

class PlayerController extends ChangeNotifier {
  PlayerController({
    required this.audioService,
    this.resolveSong,
    this.recentSongsService,
  }) {
    _subscriptions = [
      audioService.playingStream.listen((value) {
        isPlaying = value;
        notifyListeners();
      }),
      audioService.positionStream.listen((value) {
        position = value;
        notifyListeners();
      }),
      audioService.bufferedPositionStream.listen((value) {
        bufferedPosition = value;
        notifyListeners();
      }),
      audioService.durationStream.listen((value) {
        if (value != null && value != Duration.zero) duration = value;
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
  Song? currentSong;
  bool isPlaying = false;
  bool isPreparing = false;
  Duration position = Duration.zero;
  Duration bufferedPosition = Duration.zero;
  Duration duration = Duration.zero;
  String? errorText;
  final List<Song> recentSongs = [];
  bool _handlingCompletion = false;

  Future<void> _handleCompletion() async {
    if (_handlingCompletion || isPreparing || currentSong == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (isPreparing || duration <= Duration.zero) return;
    final remaining = duration - position;
    if (remaining > const Duration(seconds: 2)) return;
    _handlingCompletion = true;
    try {
      await playNext();
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

  Future<void> _saveRecentSongs() async {
    try {
      await recentSongsService?.save(recentSongs);
    } catch (error, stackTrace) {
      await PlaybackLogService.write('recent-songs', error, stackTrace);
    }
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

  Future<void> playNext() async => _playOffset(1);

  Future<void> _playOffset(int offset) async {
    final song = currentSong;
    if (song == null || queue.isEmpty) return;
    final currentIndex = queue.indexWhere((item) => item.id == song.id);
    final targetIndex = (currentIndex + offset + queue.length) % queue.length;
    await playSong(queue[targetIndex], fromQueue: queue);
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
    audioService.dispose();
    super.dispose();
  }
}
