import 'dart:convert';
import 'dart:io';

import 'app_storage_service.dart';

class AppPreferencesService {
  File get _file => AppStorageService.file('preferences.json');

  Future<Object?> read(String key) async {
    final values = await _load();
    return values[key];
  }

  Future<void> write(String key, Object? value) async {
    final values = await _load();
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(values), flush: true);
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
