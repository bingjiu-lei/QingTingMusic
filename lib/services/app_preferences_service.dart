import 'dart:convert';
import 'dart:io';

import 'app_storage_service.dart';

class AppPreferencesService {
  File get _file => AppStorageService.file('preferences.json');

  // Preferences share one file but many service instances; a single static
  // future chain serializes every read-modify-write so concurrent writers
  // (playback-state debounce vs. settings page) can't drop each other's keys.
  static Future<void> _queue = Future<void>.value();

  Future<Object?> read(String key) {
    return _enqueue(() async {
      final values = await _load();
      return values[key];
    });
  }

  Future<void> write(String key, Object? value) {
    return _enqueue(() async {
      final values = await _load();
      if (value == null) {
        values.remove(key);
      } else {
        values[key] = value;
      }
      await _file.parent.create(recursive: true);
      await _file.writeAsString(jsonEncode(values), flush: true);
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Map<String, Object?>> _load() async {
    if (!await _file.exists()) return {};
    try {
      final value = jsonDecode(await _file.readAsString());
      return value is Map ? value.cast<String, Object?>() : {};
    } catch (_) {
      return {};
    }
  }
}
