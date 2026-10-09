import 'dart:convert';
import 'dart:io';

import 'app_storage_service.dart';

class WindowStateSnapshot {
  const WindowStateSnapshot({
    required this.width,
    required this.height,
    required this.isMaximized,
  });

  final double width;
  final double height;
  final bool isMaximized;

  static const defaultWidth = 1120.0;
  static const defaultHeight = 700.0;
  static const minWidth = 960.0;
  static const minHeight = 640.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindowStateSnapshot &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height &&
          isMaximized == other.isMaximized;

  @override
  int get hashCode => Object.hash(width, height, isMaximized);
}

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

  Future<WindowStateSnapshot> readWindowState() async {
    final values = _load();
    final rawWidth = values['windowWidth'];
    final rawHeight = values['windowHeight'];
    final rawMaximized = values['windowMaximized'];

    final width =
        (rawWidth is num
                ? rawWidth.toDouble()
                : WindowStateSnapshot.defaultWidth)
            .clamp(WindowStateSnapshot.minWidth, 7680.0);
    final height =
        (rawHeight is num
                ? rawHeight.toDouble()
                : WindowStateSnapshot.defaultHeight)
            .clamp(WindowStateSnapshot.minHeight, 4320.0);
    final isMaximized = rawMaximized is bool ? rawMaximized : false;

    return WindowStateSnapshot(
      width: width,
      height: height,
      isMaximized: isMaximized,
    );
  }

  Future<void> writeWindowState({
    double? width,
    double? height,
    bool? isMaximized,
  }) async {
    final values = _load();
    if (width != null) {
      values['windowWidth'] = width.clamp(WindowStateSnapshot.minWidth, 7680.0);
    }
    if (height != null) {
      values['windowHeight'] = height.clamp(
        WindowStateSnapshot.minHeight,
        4320.0,
      );
    }
    if (isMaximized != null) {
      values['windowMaximized'] = isMaximized;
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
