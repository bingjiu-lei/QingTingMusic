import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/music_repository.dart';
import '../models/music_playlist.dart';
import '../models/search_catalog_item.dart';
import '../models/song.dart';
import '../services/kugou_api_client.dart';
import '../services/music_library_cache_service.dart';

enum LibrarySection { songs, playlists, albums, artists, cloud, recent }

class MusicLibraryController extends ChangeNotifier {
  MusicLibraryController(
    this.repository, {
    MusicLibraryCacheService? cacheService,
  }) : cacheService = cacheService ?? MusicLibraryCacheService();

  final MusicRepository repository;
  final MusicLibraryCacheService cacheService;

  List<MusicPlaylist> playlists = const [];
  List<Song> favorites = const [];
  List<Song> cloudSongs = const [];
  List<SearchCatalogItem> followedArtists = const [];
  List<MusicPlaylist> albums = const [];
  final Set<LibrarySection> loading = {};
  final Set<LibrarySection> loaded = {};
  final Map<LibrarySection, String> errors = {};
  Future<List<MusicPlaylist>>? _playlistRequest;

  MusicPlaylist? get favoritePlaylist {
    for (final playlist in playlists) {
      if (playlist.name == '我喜欢') return playlist;
    }
    for (final playlist in playlists) {
      if (playlist.kind == MusicPlaylistKind.favoriteSongs) return playlist;
    }
    return null;
  }

  List<MusicPlaylist> get createdPlaylists => playlists
      .where((item) => item.kind == MusicPlaylistKind.createdPlaylist)
      .toList();

  List<MusicPlaylist> get collectedPlaylists => playlists
      .where((item) => item.kind == MusicPlaylistKind.collectedPlaylist)
      .toList();

  bool isLoading(LibrarySection section) => loading.contains(section);

  bool hasData(LibrarySection section) => switch (section) {
    LibrarySection.songs => favorites.isNotEmpty,
    LibrarySection.playlists =>
      createdPlaylists.isNotEmpty || collectedPlaylists.isNotEmpty,
    LibrarySection.albums => albums.isNotEmpty,
    LibrarySection.artists => followedArtists.isNotEmpty,
    LibrarySection.cloud => cloudSongs.isNotEmpty,
    LibrarySection.recent => true,
  };

  Future<void> initialize() async {
    final snapshot = await cacheService.load();
    playlists = snapshot.playlists;
    favorites = snapshot.favorites;
    cloudSongs = snapshot.cloudSongs;
    followedArtists = snapshot.artists;
    albums = snapshot.albums;
    if (playlists.isNotEmpty) loaded.add(LibrarySection.playlists);
    if (favorites.isNotEmpty) loaded.add(LibrarySection.songs);
    if (cloudSongs.isNotEmpty) loaded.add(LibrarySection.cloud);
    if (followedArtists.isNotEmpty) loaded.add(LibrarySection.artists);
    if (albums.isNotEmpty) loaded.add(LibrarySection.albums);
    notifyListeners();
  }

  Future<void> ensureLoaded(
    LibrarySection section, {
    bool refresh = false,
  }) async {
    if (section == LibrarySection.recent) return;
    if (!refresh && (loaded.contains(section) || loading.contains(section))) {
      return;
    }
    loading.add(section);
    errors.remove(section);
    notifyListeners();
    try {
      switch (section) {
        case LibrarySection.songs:
          final nextPlaylists = await _loadPlaylists(refresh: refresh);
          final favorite = _favoriteFrom(nextPlaylists);
          favorites = favorite == null
              ? const []
              : await repository.getPlaylistSongs(favorite);
        case LibrarySection.playlists:
          playlists = await _loadPlaylists(refresh: refresh);
        case LibrarySection.albums:
          final nextPlaylists = await _loadPlaylists(refresh: refresh);
          albums = nextPlaylists
              .where((item) => item.kind == MusicPlaylistKind.album)
              .toList();
        case LibrarySection.artists:
          followedArtists = await repository.getFollowedArtists();
        case LibrarySection.cloud:
          cloudSongs = await repository.getCloudSongs();
        case LibrarySection.recent:
          break;
      }
      loaded.add(section);
      unawaited(_saveCache());
    } on AuthenticationRequiredException {
      errors[section] = '登录后查看你的音乐内容';
    } on KugouApiException catch (error) {
      errors[section] = error.message;
    } catch (_) {
      errors[section] = '加载失败，请稍后重试';
    } finally {
      loading.remove(section);
      notifyListeners();
    }
  }

  Future<void> refreshCachedInBackground() async {
    for (final section in loaded.toList()) {
      unawaited(ensureLoaded(section, refresh: true));
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
  }

  Future<List<MusicPlaylist>> _loadPlaylists({required bool refresh}) {
    if (!refresh && playlists.isNotEmpty) {
      return Future.value(playlists);
    }
    return _playlistRequest ??= repository.getUserPlaylists().whenComplete(() {
      _playlistRequest = null;
    });
  }

  MusicPlaylist? _favoriteFrom(List<MusicPlaylist> values) {
    for (final playlist in values) {
      if (playlist.name == '我喜欢') return playlist;
    }
    for (final playlist in values) {
      if (playlist.kind == MusicPlaylistKind.favoriteSongs) return playlist;
    }
    return null;
  }

  Future<void> _saveCache() {
    return cacheService.save(
      MusicLibrarySnapshot(
        playlists: playlists,
        favorites: favorites,
        cloudSongs: cloudSongs,
        artists: followedArtists,
        albums: albums,
      ),
    );
  }

  Future<List<Song>> loadPlaylist(MusicPlaylist playlist) {
    return repository.getPlaylistSongs(playlist);
  }

  bool isFavorite(Song song) => favorites.any((item) => item.hash == song.hash);

  Song withFavoriteState(Song song) {
    return song.copyWith(liked: isFavorite(song));
  }

  Future<void> toggleFavorite(Song song) async {
    final favorite = favoritePlaylist;
    if (favorite == null) {
      throw const KugouApiException('没有找到默认收藏歌单');
    }
    final existing = favorites.cast<Song?>().firstWhere(
      (item) => item?.hash == song.hash,
      orElse: () => null,
    );
    if (existing == null) {
      await repository.addSongToPlaylist(favorite, song);
    } else {
      await repository.removeSongFromPlaylist(favorite, existing);
    }
    await ensureLoaded(LibrarySection.songs, refresh: true);
  }
}
