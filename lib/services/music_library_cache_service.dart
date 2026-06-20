import 'dart:convert';
import 'dart:io';

import '../models/music_playlist.dart';
import '../models/search_catalog_item.dart';
import '../models/song.dart';
import 'app_storage_service.dart';

class MusicLibrarySnapshot {
  const MusicLibrarySnapshot({
    this.playlists = const [],
    this.favorites = const [],
    this.cloudSongs = const [],
    this.artists = const [],
    this.albums = const [],
  });

  final List<MusicPlaylist> playlists;
  final List<Song> favorites;
  final List<Song> cloudSongs;
  final List<SearchCatalogItem> artists;
  final List<MusicPlaylist> albums;
}

class MusicLibraryCacheService {
  File get _file => AppStorageService.file('library-cache.json');

  Future<MusicLibrarySnapshot> load() async {
    if (!await _file.exists()) return const MusicLibrarySnapshot();
    try {
      final json =
          jsonDecode(await _file.readAsString()) as Map<String, Object?>;
      return MusicLibrarySnapshot(
        playlists: _list(
          json['playlists'],
        ).map(MusicPlaylist.fromJson).toList(),
        favorites: _list(json['favorites']).map(Song.fromJson).toList(),
        cloudSongs: _list(json['cloudSongs']).map(Song.fromJson).toList(),
        artists: _list(
          json['artists'],
        ).map(SearchCatalogItem.fromJson).toList(),
        albums: _list(json['albums']).map(MusicPlaylist.fromJson).toList(),
      );
    } catch (_) {
      return const MusicLibrarySnapshot();
    }
  }

  Future<void> save(MusicLibrarySnapshot snapshot) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode({
        'playlists': snapshot.playlists.map((item) => item.toJson()).toList(),
        'favorites': snapshot.favorites.map((item) => item.toJson()).toList(),
        'cloudSongs': snapshot.cloudSongs.map((item) => item.toJson()).toList(),
        'artists': snapshot.artists.map((item) => item.toJson()).toList(),
        'albums': snapshot.albums.map((item) => item.toJson()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      }),
      flush: true,
    );
  }

  List<Map<String, Object?>> _list(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
  }
}
