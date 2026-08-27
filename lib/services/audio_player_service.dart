import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'app_storage_service.dart';
import 'cache_management_service.dart';

class AudioPlayerService {
  AudioPlayerService({
    required bool enabled,
    CacheManagementService? cacheManagementService,
  }) : _cacheManagementService =
           cacheManagementService ?? CacheManagementService() {
    _player = enabled ? AudioPlayer() : null;
    _eventSubscription = _player?.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _errors.add(error.toString());
      },
    );
  }

  late final AudioPlayer? _player;
  final CacheManagementService _cacheManagementService;
  StreamSubscription<PlaybackEvent>? _eventSubscription;
  final StreamController<String> _errors = StreamController.broadcast();
  final StreamController<String> _technicalNotices =
      StreamController.broadcast();
  final Map<String, DateTime> _localPlaybackSkips = {};
  int _openGeneration = 0;
  Duration? _openedDuration;
  Timer? _localGuardTimer;
  // Set on pause() and cleared on play()/open(): delayed play retries must
  // never override an explicit user pause.
  bool _userPaused = false;

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

  Stream<String> get technicalNoticeStream => _technicalNotices.stream;

  bool get isEnabled => _player != null;

  Duration? get currentDuration => _openedDuration ?? _player?.duration;

  bool get isCompleted => _player?.processingState == ProcessingState.completed;

  /// Cancels the current source switch without waiting for a replacement URL.
  /// The next [open] call gets a new generation and can start immediately.
  Future<void> cancelPendingOpen() async {
    _openGeneration++;
    _localGuardTimer?.cancel();
    _userPaused = true;
    await _player?.stop();
  }

  Future<void> open(Song song) async {
    final player = _player;
    if (player == null) return;
    final url = song.audioUrl.trim();
    if (url.isEmpty) throw StateError('播放地址为空');
    final uri = Uri.parse(url);

    // Each open() bumps the generation so a stale local-playback guard from a
    // previous song knows to cancel itself instead of clobbering the new one.
    _openGeneration++;
    _openedDuration = null;
    _userPaused = false;
    _localGuardTimer?.cancel();
    final generation = _openGeneration;

    final cacheFile = await _readableCachedFile(song, uri);
    if (cacheFile != null && !_shouldSkipLocalPlayback(song)) {
      if (await _playLocal(player, cacheFile, generation)) {
        await _touch(cacheFile);
        unawaited(_cacheManagementService.trimToLimit());
        _technicalNotices.add('已使用本地缓存');
        // Confirm playback asynchronously so a rejected cache file can fall
        // back to the online URL without blocking open() and stuttering the
        // start of the track.
        _guardLocalPlayback(player, song, uri, generation);
        return;
      }
      _skipLocalPlayback(song);
    }

    await _openUri(
      player,
      uri,
      generation,
      headers: const {_userAgentHeader: _userAgent},
    );
    unawaited(_cacheInBackground(song, uri));
  }

  /// Starts playback from a cached local file. Only blocks for setAudioSource
  /// (fast for a local file); the play retry and failure watch happen off the
  /// critical path so the caller resumes immediately.
  Future<bool> _playLocal(AudioPlayer player, File file, int generation) async {
    try {
      _openedDuration = await player.setAudioSource(
        AudioSource.uri(Uri.file(file.path)),
      );
      if (generation != _openGeneration || _userPaused) return false;
      unawaited(player.play());
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 200)).then((_) {
          if (generation != _openGeneration || _userPaused) return;
          if (!player.playing) unawaited(player.play());
        }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Non-blocking watch: if the local file never actually starts playing
  /// (rejected by the backend, corrupt, ACL issue), fall back to the online
  /// URL. Once position advances, playback is considered confirmed and the
  /// guard disarms.
  void _guardLocalPlayback(
    AudioPlayer player,
    Song song,
    Uri onlineUri,
    int generation,
  ) {
    var attempts = 0;
    _localGuardTimer?.cancel();
    _localGuardTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (generation != _openGeneration || _userPaused) {
        timer.cancel();
        return;
      }
      if (player.position > Duration.zero) {
        timer.cancel();
        return;
      }
      attempts++;
      final state = player.processingState;
      final failed =
          state == ProcessingState.idle ||
          state == ProcessingState.completed ||
          attempts >= 8;
      if (!failed) return;
      timer.cancel();
      unawaited(_fallbackToOnline(player, song, onlineUri, generation));
    });
  }

  Future<void> _fallbackToOnline(
    AudioPlayer player,
    Song song,
    Uri onlineUri,
    int generation,
  ) async {
    if (generation != _openGeneration) return;
    _skipLocalPlayback(song);
    _technicalNotices.add('本地缓存不可用，已切换在线播放');
    await _openUri(
      player,
      onlineUri,
      generation,
      headers: const {_userAgentHeader: _userAgent},
    );
    unawaited(_cacheInBackground(song, onlineUri));
  }

  Future<void> _openUri(
    AudioPlayer player,
    Uri uri,
    int generation, {
    Map<String, String>? headers,
  }) async {
    if (generation != _openGeneration || _userPaused) return;
    await player.stop();
    if (generation != _openGeneration || _userPaused) return;
    _openedDuration = await player.setAudioSource(
      AudioSource.uri(uri, headers: headers),
    );
    if (generation != _openGeneration || _userPaused) return;
    unawaited(player.play());
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (generation != _openGeneration || _userPaused) return;
    if (!player.playing) {
      unawaited(player.play());
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
    if (generation != _openGeneration || _userPaused) return;
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
    final file = _cacheFile(song, uri);
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
      unawaited(_cacheManagementService.trimToLimit());
      return completed;
    } finally {
      client.close(force: true);
      await _discard(partial);
    }
  }

  Future<File?> _readableCachedFile(Song song, Uri uri) async {
    final file = _cacheFile(song, uri);
    return await _isReadableAudio(file) ? file : null;
  }

  File _cacheFile(Song song, Uri uri) {
    final directory = AppStorageService.directory('audio');
    final extension = uri.pathSegments.last.contains('.')
        ? uri.pathSegments.last.split('.').last
        : 'mp3';
    final quality =
        (song.playbackQuality?.isNotEmpty == true
                ? song.playbackQuality!
                : 'auto')
            .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final safeId = '${(song.hash ?? song.id)}_$quality'.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    return File('${directory.path}\\v3_$safeId.$extension');
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

  bool _shouldSkipLocalPlayback(Song song) {
    final key = _cacheKey(song);
    final until = _localPlaybackSkips[key];
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _localPlaybackSkips.remove(key);
    return false;
  }

  void _skipLocalPlayback(Song song) {
    _localPlaybackSkips[_cacheKey(song)] = DateTime.now().add(
      const Duration(hours: 24),
    );
  }

  String _cacheKey(Song song) =>
      '${song.hash ?? song.id}:${song.playbackQuality ?? 'auto'}';

  Future<void> _touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } catch (_) {}
  }

  Future<void> play() async {
    _userPaused = false;
    await _player?.play();
  }

  bool get isPlaying => _player?.playing ?? false;

  Future<void> pause() async {
    _userPaused = true;
    await _player?.pause();
  }

  Future<void> seek(Duration position) async => _player?.seek(position);

  Future<void> setVolume(double value) async {
    await _player?.setVolume(value.clamp(0.0, 1.0));
  }

  double get speed => _player?.speed ?? 1.0;

  Future<void> setSpeed(double speed) async {
    await _player?.setSpeed(speed);
  }

  Future<void> dispose() async {
    _localGuardTimer?.cancel();
    await _eventSubscription?.cancel();
    await _player?.dispose();
    await _errors.close();
    await _technicalNotices.close();
  }

  static const _userAgentHeader = HttpHeaders.userAgentHeader;
  static const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';
}
