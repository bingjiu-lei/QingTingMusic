import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../services/app_preferences_service.dart';

enum PlaybackQuality {
  standard('标准', 128),
  high('HQ', 320),
  lossless('无损', 'flac'),
  hiRes('Hi-Res', 'high');

  const PlaybackQuality(this.label, this.requestValue);

  final String label;
  final Object requestValue;

  static PlaybackQuality? fromRequestValue(Object? value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    return switch (raw) {
      '0' || '1' || '128' || 'standard' => PlaybackQuality.standard,
      '2' || '320' || 'highquality' => PlaybackQuality.high,
      '3' || 'flac' || 'lossless' || 'sq' => PlaybackQuality.lossless,
      '6' || 'hires' || 'hi-res' || 'high' || 'hr' => PlaybackQuality.hiRes,
      _ => null,
    };
  }
}

class PlaybackQualityController extends ChangeNotifier {
  PlaybackQualityController({
    AppPreferencesService? preferences,
    this.onQualityChanged,
  }) : _preferences = preferences ?? AppPreferencesService();

  static const _preferenceKey = 'playbackQuality';

  final AppPreferencesService _preferences;
  final VoidCallback? onQualityChanged;
  PlaybackQuality _quality = PlaybackQuality.standard;
  String? _currentSongKey;
  bool _currentSongIsCloud = false;
  Set<PlaybackQuality> _availableQualities = const {};
  bool _hasAvailability = false;
  bool _availabilityAttempted = false;

  PlaybackQuality get quality => _quality;

  /// The current song's resources reported by `/privilege/lite`.
  /// `null` means that availability has not been loaded yet.
  List<PlaybackQuality> get availableQualities {
    if (_currentSongKey == null) return PlaybackQuality.values;
    if (!_hasAvailability) return const [];
    return PlaybackQuality.values
        .where(_availableQualities.contains)
        .toList(growable: false);
  }

  bool get hasCurrentSongAvailability => _hasAvailability;

  bool get availabilityChecked => _availabilityAttempted;

  bool get hasCloudSource => _currentSongIsCloud;

  bool get shouldLoadCurrentSongAvailability => !_availabilityAttempted;

  /// Keeps playback available when a preferred stream is not available.
  List<Object> get requestCandidates {
    const fallbackOrder = <PlaybackQuality>[
      PlaybackQuality.hiRes,
      PlaybackQuality.lossless,
      PlaybackQuality.high,
      PlaybackQuality.standard,
    ];
    final selectedIndex = fallbackOrder.indexOf(_quality);
    return fallbackOrder
        .skip(selectedIndex < 0 ? fallbackOrder.length - 1 : selectedIndex)
        .map((candidate) => candidate.requestValue)
        .toList(growable: false);
  }

  Future<void> initialize() async {
    final saved = await _preferences.read(_preferenceKey);
    final value = saved?.toString();
    final next = PlaybackQuality.values.where((item) => item.name == value);
    if (next.isEmpty) return;
    _quality = next.first;
    notifyListeners();
  }

  void setCurrentSong(Song? song) {
    final nextKey = _songKey(song);
    if (_currentSongKey == nextKey) return;
    _currentSongKey = nextKey;
    _currentSongIsCloud = song?.isCloud == true;
    _availableQualities = const {};
    _hasAvailability = false;
    _availabilityAttempted = false;
    notifyListeners();
  }

  void setAvailableQualities(Song song, Iterable<Object?> values) {
    final key = _songKey(song);
    if (key == null || key != _currentSongKey) return;
    _availabilityAttempted = true;
    final next = values
        .map(PlaybackQuality.fromRequestValue)
        .whereType<PlaybackQuality>()
        .toSet();
    if (next.isEmpty) return;
    _availableQualities = next;
    _hasAvailability = true;
    notifyListeners();
  }

  void markAvailabilityChecked(Song song) {
    final key = _songKey(song);
    if (key == null || key != _currentSongKey) return;
    _availabilityAttempted = true;
  }

  Future<void> select(PlaybackQuality value) async {
    if (_quality == value) return;
    _quality = value;
    notifyListeners();
    onQualityChanged?.call();
    await _preferences.write(_preferenceKey, value.name);
  }

  String? _songKey(Song? song) {
    final catalogHash = song?.catalogHash?.trim().toLowerCase() ?? '';
    if (song?.isCloud == true && catalogHash.isNotEmpty) {
      return catalogHash;
    }
    final hash = song?.hash?.trim().toLowerCase() ?? '';
    if (hash.isNotEmpty) return hash;
    final id = song?.id.trim().toLowerCase() ?? '';
    return id.isEmpty ? null : id;
  }
}
