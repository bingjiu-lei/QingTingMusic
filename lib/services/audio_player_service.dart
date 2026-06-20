import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'app_storage_service.dart';

class AudioPlayerService {
  AudioPlayerService({required bool enabled}) {
    _player = enabled ? AudioPlayer() : null;
    _eventSubscription = _player?.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _errors.add(error.toString());
      },
    );
  }

  late final AudioPlayer? _player;
  StreamSubscription<PlaybackEvent>? _eventSubscription;
  final StreamController<String> _errors = StreamController.broadcast();

  Stream<bool> get playingStream =>
      _player?.playingStream ?? const Stream<bool>.empty();

  Stream<Duration> get positionStream =>
      _player?.positionStream ?? const Stream<Duration>.empty();

  Stream<Duration> get bufferedPositionStream =>
      _player?.bufferedPositionStream ?? const Stream<Duration>.empty();

  Stream<Duration?> get durationStream =>
      _player?.durationStream ?? const Stream<Duration?>.empty();

  Stream<String> get errorStream => _errors.stream;

  bool get isEnabled => _player != null;

  Future<void> open(Song song) async {
    final player = _player;
    if (player == null) return;
    final url = song.audioUrl.trim();
    if (url.isEmpty) throw StateError('播放地址为空');

    final file = await _download(song, Uri.parse(url));
    await player.setAudioSource(AudioSource.uri(Uri.file(file.path)));
    unawaited(player.play());
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!player.playing) {
      unawaited(player.play());
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
    if (!player.playing) {
      unawaited(player.play());
    }
  }

  Future<File> _download(Song song, Uri uri) async {
    final directory = AppStorageService.directory('audio');
    await directory.create(recursive: true);
    final extension = uri.pathSegments.last.contains('.')
        ? uri.pathSegments.last.split('.').last
        : 'mp3';
    final safeId = (song.hash ?? song.id).replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    final file = File('${directory.path}\\$safeId.$extension');
    if (await file.exists() && await file.length() > 1024) return file;

    final partial = File('${file.path}.part');
    if (await partial.exists()) await partial.delete();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    client.findProxy = (_) {
      final raw =
          Platform.environment['HTTPS_PROXY'] ??
          Platform.environment['HTTP_PROXY'] ??
          Platform.environment['ALL_PROXY'];
      final proxy = raw == null ? null : Uri.tryParse(raw);
      return proxy == null ? 'DIRECT' : 'PROXY ${proxy.host}:${proxy.port}';
    };
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('音频下载失败：${response.statusCode}');
      }
      await response.pipe(partial.openWrite());
      if (await partial.length() <= 1024) {
        throw const HttpException('音频文件内容为空');
      }
      return await partial.rename(file.path);
    } finally {
      client.close(force: true);
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<void> play() async => _player?.play();

  bool get isPlaying => _player?.playing ?? false;

  Future<void> pause() async => _player?.pause();

  Future<void> seek(Duration position) async => _player?.seek(position);

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _player?.dispose();
    await _errors.close();
  }
}
