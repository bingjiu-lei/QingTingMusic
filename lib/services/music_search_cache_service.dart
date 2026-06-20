import 'dart:convert';
import 'dart:io';

import '../models/search_catalog_item.dart';
import '../models/song.dart';
import 'app_storage_service.dart';

class MusicSearchCache {
  const MusicSearchCache({this.songs = const {}, this.catalogs = const {}});

  final Map<String, List<Song>> songs;
  final Map<String, List<SearchCatalogItem>> catalogs;
}

class MusicSearchCacheService {
  File get _file => AppStorageService.file('search-cache.json');

  Future<MusicSearchCache> load() async {
    if (!await _file.exists()) return const MusicSearchCache();
    try {
      final json =
          jsonDecode(await _file.readAsString()) as Map<String, Object?>;
      return MusicSearchCache(
        songs: _decodeMap(json['songs'], Song.fromJson),
        catalogs: _decodeMap(json['catalogs'], SearchCatalogItem.fromJson),
      );
    } catch (_) {
      return const MusicSearchCache();
    }
  }

  Future<void> save(
    Map<String, List<Song>> songs,
    Map<String, List<SearchCatalogItem>> catalogs,
  ) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode({
        'songs': songs.map(
          (key, value) =>
              MapEntry(key, value.map((item) => item.toJson()).toList()),
        ),
        'catalogs': catalogs.map(
          (key, value) =>
              MapEntry(key, value.map((item) => item.toJson()).toList()),
        ),
      }),
      flush: true,
    );
  }

  Map<String, List<T>> _decodeMap<T>(
    Object? value,
    T Function(Map<String, Object?> json) decode,
  ) {
    if (value is! Map) return {};
    return value.map((key, records) {
      final list = records is List
          ? records
                .whereType<Map>()
                .map((item) => decode(item.cast<String, Object?>()))
                .toList()
          : <T>[];
      return MapEntry(key.toString(), list);
    });
  }
}
