import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

class RecentSongsService {
  static const _key = 'recent_songs';
  static const maxItems = 30;

  File get _file {
    final root =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.current.path;
    return File('$root\\QingTingMusic\\recent-songs.json');
  }

  Future<List<Song>> load() async {
    if (Platform.isWindows && await _file.exists()) {
      try {
        final values = jsonDecode(await _file.readAsString());
        if (values is List) {
          return values
              .whereType<Map>()
              .map((item) => Song.fromJson(item.cast<String, Object?>()))
              .toList();
        }
      } catch (_) {}
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      final values = preferences.getStringList(_key) ?? const [];
      return values.map(_decode).whereType<Song>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<Song> songs) async {
    final values = songs.take(maxItems).toList();
    if (Platform.isWindows) {
      await _file.parent.create(recursive: true);
      await _file.writeAsString(
        jsonEncode(values.map((song) => song.toJson()).toList()),
        flush: true,
      );
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_key, values.map(_encode).toList());
  }

  String _encode(Song song) => jsonEncode(song.toJson());

  Song? _decode(String value) {
    try {
      return Song.fromJson((jsonDecode(value) as Map).cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }
}
