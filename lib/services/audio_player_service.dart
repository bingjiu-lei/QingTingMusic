import 'package:media_kit/media_kit.dart';

import '../models/song.dart';

class AudioPlayerService {
  AudioPlayerService({required bool enabled})
    : _player = enabled ? Player() : null;

  final Player? _player;

  Stream<bool> get playingStream =>
      _player?.stream.playing ?? const Stream<bool>.empty();

  Stream<Duration> get positionStream =>
      _player?.stream.position ?? const Stream<Duration>.empty();

  Stream<Duration> get durationStream =>
      _player?.stream.duration ?? const Stream<Duration>.empty();

  Stream<String> get errorStream =>
      _player?.stream.error ?? const Stream<String>.empty();

  bool get isEnabled => _player != null;

  Future<void> open(Song song) async {
    final player = _player;
    if (player == null) return;

    await player.open(
      Media(
        Uri.parse(song.audioUrl).toString(),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ),
      play: true,
    );
  }

  Future<void> play() async => _player?.play();

  Future<void> pause() async => _player?.pause();

  Future<void> seek(Duration position) async => _player?.seek(position);

  Future<void> dispose() async => _player?.dispose();
}
