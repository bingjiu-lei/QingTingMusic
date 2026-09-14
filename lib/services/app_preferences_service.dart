import 'dart:convert';
import 'dart:io';

import 'app_storage_service.dart';

class AppPreferencesService {
  File get _file => AppStorageService.file('preferences.json');

  Future<Object?> read(String key) async {
    final values = _load();
    return values[key];
  }

  Future<void> write(String key, Object? value) async {
    final values = _load();
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
    try {
      if (!_file.parent.existsSync()) {
        _file.parent.createSync(recursive: true);
      }
      _file.writeAsStringSync(jsonEncode(values), flush: true);
    } catch (_) {}
  }

  Map<String, Object?> _load() {
    if (!_file.existsSync()) return {};
    try {
      final value = jsonDecode(_file.readAsStringSync());
      return value is Map ? value.cast<String, Object?>() : {};
    } catch (_) {
      return {};
    }
  }
}
