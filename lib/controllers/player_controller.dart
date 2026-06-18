import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';

class PlayerController extends ChangeNotifier {
  PlayerController({required this.audioService}) {
    _subscriptions = [
      audioService.playingStream.listen((value) {
        isPlaying = value;
        notifyListeners();
      }),
      audioService.positionStream.listen((value) {
        position = value;
        notifyListeners();
      }),
      audioService.durationStream.listen((value) {
        if (value != Duration.zero) duration = value;
        notifyListeners();
      }),
      audioService.errorStream.listen((message) {
        isPlaying = false;
        errorText = message.isEmpty ? '播放失败，请稍后重试。' : message;
        notifyListeners();
      }),
    ];
  }

  final AudioPlayerService audioService;
  late final List<StreamSubscription<Object?>> _subscriptions;

  List<Song> queue = const [];
  Song? currentSong;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  String? errorText;
  final List<Song> recentSongs = [];

  Future<void> playSong(Song song, {List<Song>? fromQueue}) async {
    if (fromQueue != null && fromQueue.isNotEmpty) {
      queue = List.unmodifiable(fromQueue);
    } else if (!queue.any((item) => item.id == song.id)) {
      queue = [song];
    }

    currentSong = song;
    position = Duration.zero;
    duration = song.duration;
    errorText = null;
    recentSongs.removeWhere((item) => item.id == song.id);
    recentSongs.insert(0, song);
    if (recentSongs.length > 8) recentSongs.removeLast();

    if (!audioService.isEnabled) {
      isPlaying = true;
      notifyListeners();
      return;
    }

    notifyListeners();
    try {
      await audioService.open(song);
    } catch (_) {
      isPlaying = false;
      errorText = '播放失败，请检查网络或音频地址。';
      notifyListeners();
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

    if (position == Duration.zero) {
      await playSong(song);
      return;
    }

    await audioService.play();
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
