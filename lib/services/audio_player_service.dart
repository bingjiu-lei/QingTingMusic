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

  Stream<void> get completedStream =>
      _player?.processingStateStream
          .where((state) => state == ProcessingState.completed)
          .map((_) {}) ??
      const Stream<void>.empty();

  Stream<String> get errorStream => _errors.stream;

  bool get isEnabled => _player != null;

  Future<void> open(Song song) async {
    final player = _player;
    if (player == null) return;
    final url = song.audioUrl.trim();
    if (url.isEmpty) throw StateError('播放地址为空');
    final uri = Uri.parse(url);

    // EchoMusic also hands the resolved URL directly to its playback engine.
    // This avoids Windows Media Foundation rejecting a local cache file due to
    // machine-specific ACL or packaged-app permission differences.
    await player.setAudioSource(
      AudioSource.uri(uri, headers: const {_userAgentHeader: _userAgent}),
    );
    unawaited(_cacheInBackground(song, uri));
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

  Future<void> _cacheInBackground(Song song, Uri uri) async {
    try {
      await _download(song, uri);
    } catch (_) {
      // A cache failure must never interrupt online playback.
    }
  }

  Future<File> _download(Song song, Uri uri) async {
    final directory = AppStorageService.directory('audio');
    await directory.create(recursive: true);
    await AppStorageService.ensureCurrentUserAccess(directory);
    final extension = uri.pathSegments.last.contains('.')
        ? uri.pathSegments.last.split('.').last
        : 'mp3';
    final safeId = (song.hash ?? song.id).replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    final file = File('${directory.path}\\v3_$safeId.$extension');
    if (await _isReadableAudio(file)) return file;
    await _discard(file);

    final partial = File('${file.path}.part');
    await _discard(partial);
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
      request.headers.set(_userAgentHeader, _userAgent);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('音频下载失败：${response.statusCode}');
      }
      await response.pipe(partial.openWrite());
      if (await partial.length() <= 1024) {
        throw const HttpException('音频文件内容为空');
      }
      final completed = await partial.rename(file.path);
      await AppStorageService.ensureCurrentUserAccess(completed);
      if (!await _isReadableAudio(completed)) {
        throw FileSystemException('下载后的音频文件不可读取', completed.path);
      }
      return completed;
    } finally {
      client.close(force: true);
      await _discard(partial);
    }
  }

  Future<bool> _isReadableAudio(File file) async {
    try {
      if (!await file.exists() || await file.length() <= 1024) return false;
      await AppStorageService.ensureCurrentUserAccess(file);
      final handle = await file.open(mode: FileMode.read);
      await handle.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _discard(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
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

  static const _userAgentHeader = HttpHeaders.userAgentHeader;
  static const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';
}
