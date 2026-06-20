import 'dart:convert';
import 'dart:io';

import '../models/song.dart';
import 'app_storage_service.dart';

class RecentSongsService {
  static const maxItems = 30;

  File get _file => AppStorageService.file('recent-songs.json');

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

    return const [];
  }

  Future<void> save(List<Song> songs) async {
    final values = songs.take(maxItems).toList();
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode(values.map((song) => song.toJson()).toList()),
      flush: true,
    );
  }
}
