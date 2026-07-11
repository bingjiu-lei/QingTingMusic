import 'package:flutter/foundation.dart';

import '../services/app_preferences_service.dart';

enum PlaybackQuality {
  standard('标准', 128),
  high('HQ', 320),
  lossless('无损', 'flac');

  const PlaybackQuality(this.label, this.requestValue);

  final String label;
  final Object requestValue;
}

class PlaybackQualityController extends ChangeNotifier {
  PlaybackQualityController({AppPreferencesService? preferences})
    : _preferences = preferences ?? AppPreferencesService();

  static const _preferenceKey = 'playbackQuality';

  final AppPreferencesService _preferences;
  PlaybackQuality _quality = PlaybackQuality.standard;

  PlaybackQuality get quality => _quality;

  /// Keeps playback available when a preferred stream is not available.
  List<Object> get requestCandidates {
    final values = <Object>[_quality.requestValue];
    for (final candidate in PlaybackQuality.values) {
      if (!values.contains(candidate.requestValue)) {
        values.add(candidate.requestValue);
      }
    }
    return values;
  }

  Future<void> initialize() async {
    final saved = await _preferences.read(_preferenceKey);
    final value = saved?.toString();
    final next = PlaybackQuality.values.where((item) => item.name == value);
    if (next.isEmpty) return;
    _quality = next.first;
    notifyListeners();
  }

  Future<void> select(PlaybackQuality value) async {
    if (_quality == value) return;
    _quality = value;
    notifyListeners();
    await _preferences.write(_preferenceKey, value.name);
  }
}
