import '../controllers/player_controller.dart';
import '../models/song.dart';
import 'app_preferences_service.dart';

class PlaybackStateService {
  PlaybackStateService({AppPreferencesService? preferences})
    : _preferences = preferences ?? AppPreferencesService();

  final AppPreferencesService _preferences;

  static const _key = 'playbackState';
  static const _maxQueueItems = 1000;

  Future<PlaybackSnapshot?> load() async {
    final value = await _preferences.read(_key);
    if (value is! Map) return null;
    try {
      final json = value.cast<String, Object?>();
      final queue = (json['queue'] is List ? json['queue'] as List : const [])
          .whereType<Map>()
          .map((item) => Song.fromJson(item.cast<String, Object?>()))
          .where((song) => song.id.isNotEmpty)
          .toList();
      final currentJson = json['currentSong'];
      final currentSong = currentJson is Map
          ? Song.fromJson(currentJson.cast<String, Object?>())
          : null;
      final mode = PlaybackMode.values.firstWhere(
        (item) => item.name == json['playbackMode']?.toString(),
        orElse: () => PlaybackMode.sequence,
      );
      return PlaybackSnapshot(
        queue: queue,
        currentSong: currentSong,
        position: Duration(
          milliseconds: int.tryParse(json['positionMs']?.toString() ?? '') ?? 0,
        ),
        playbackMode: mode,
        shuffleHistory: _readSongIds(json['shuffleHistory']),
        shuffleUpcoming: _readSongIds(json['shuffleUpcoming']),
        // 旧版本快照没有该字段，缺省回退 1.0 倍速。
        playbackSpeed:
            double.tryParse(json['playbackSpeed']?.toString() ?? '') ?? 1.0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PlaybackSnapshot snapshot) async {
    final queue = snapshot.queue.take(_maxQueueItems).toList();
    await _preferences.write(_key, {
      'queue': queue.map((song) => song.toJson()).toList(),
      'currentSong': snapshot.currentSong?.toJson(),
      'positionMs': snapshot.position.inMilliseconds,
      'playbackMode': snapshot.playbackMode.name,
      'shuffleHistory': snapshot.shuffleHistory,
      'shuffleUpcoming': snapshot.shuffleUpcoming,
      'playbackSpeed': snapshot.playbackSpeed,
    });
  }

  Future<void> clear() => _preferences.write(_key, null);
}

class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.queue,
    required this.currentSong,
    required this.position,
    required this.playbackMode,
    this.shuffleHistory = const [],
    this.shuffleUpcoming = const [],
    this.playbackSpeed = 1.0,
  });

  final List<Song> queue;
  final Song? currentSong;
  final Duration position;
  final PlaybackMode playbackMode;
  final List<String> shuffleHistory;
  final List<String> shuffleUpcoming;
  final double playbackSpeed;
}

List<String> _readSongIds(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString())
      .where((id) => id.isNotEmpty)
      .toList();
}
