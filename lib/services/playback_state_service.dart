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
  });

  final List<Song> queue;
  final Song? currentSong;
  final Duration position;
  final PlaybackMode playbackMode;
}
