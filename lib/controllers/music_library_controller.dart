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

  List<Song> get sortedFavorites => favorites.reversed.toList();

  List<MusicPlaylist> get createdPlaylists => playlists
      .where((item) => item.kind == MusicPlaylistKind.createdPlaylist)
      .toList()
      .reversed
      .toList();

  List<MusicPlaylist> get collectedPlaylists => playlists
      .where((item) => item.kind == MusicPlaylistKind.collectedPlaylist)
      .toList()
      .reversed
      .toList();

  List<MusicPlaylist> get editablePlaylists => playlists
      .where((item) => item.kind == MusicPlaylistKind.createdPlaylist)
      .where((item) => item.listId != favoritePlaylist?.listId)
      .toList()
      .reversed
      .toList();

  List<MusicPlaylist> get sortedAlbums => albums.reversed.toList();

  List<Song> get sortedCloudSongs => cloudSongs.reversed.toList();

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
    notifyListeners();
  }

  void invalidateLoadedState() {
    loaded.clear();
    loading.clear();
    errors.clear();
    _playlistRequest = null;
    notifyListeners();
  }

  void clearAccountState() {
    playlists = const [];
    favorites = const [];
    cloudSongs = const [];
    followedArtists = const [];
    albums = const [];
    loaded.clear();
    loading.clear();
    errors.clear();
    _playlistRequest = null;
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
          if (nextPlaylists.isNotEmpty || playlists.isEmpty) {
            playlists = nextPlaylists;
          }
          final favorite = _favoriteFrom(nextPlaylists);
          final nextFavorites = favorite == null
              ? const <Song>[]
              : await repository.getPlaylistSongs(favorite);
          if (nextFavorites.isNotEmpty || favorites.isEmpty) {
            favorites = nextFavorites;
          }
        case LibrarySection.playlists:
          final nextPlaylists = await _loadPlaylists(
            refresh: refresh,
            allowCache: loaded.contains(section),
          );
          if (nextPlaylists.isNotEmpty || playlists.isEmpty) {
            playlists = nextPlaylists;
          }
        case LibrarySection.albums:
          final nextPlaylists = await _loadPlaylists(
            refresh: refresh,
            allowCache: loaded.contains(section),
          );
          if (nextPlaylists.isNotEmpty || playlists.isEmpty) {
            playlists = nextPlaylists;
          }
          final nextAlbums = nextPlaylists
              .where((item) => item.kind == MusicPlaylistKind.album)
              .toList();
          if (nextAlbums.isNotEmpty || albums.isEmpty) {
            albums = nextAlbums;
          }
        case LibrarySection.artists:
          final nextArtists = await repository.getFollowedArtists();
          if (nextArtists.isNotEmpty || followedArtists.isEmpty) {
            followedArtists = nextArtists;
          }
        case LibrarySection.cloud:
          final nextCloudSongs = await repository.getCloudSongs();
          if (nextCloudSongs.isNotEmpty || cloudSongs.isEmpty) {
            cloudSongs = nextCloudSongs;
          }
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

  Future<List<MusicPlaylist>> _loadPlaylists({
    required bool refresh,
    bool allowCache = true,
  }) {
    if (!refresh && allowCache && playlists.isNotEmpty) {
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

  bool isFavorite(Song song) => favorites.any((item) => _sameSong(item, song));

  Song withFavoriteState(Song song) {
    return song.copyWith(liked: isFavorite(song));
  }

  bool isCatalogCollected(SearchCatalogItem item) {
    return _collectedCatalogItem(item) != null;
  }

  Future<void> toggleCatalogCollection(SearchCatalogItem item) async {
    final collectedItem = _collectedCatalogItem(item);
    if (collectedItem != null) {
      await repository.uncollectCatalog(collectedItem);
    } else {
      await repository.collectCatalog(item);
    }
    await _refreshCatalogCollection(item.category);
    final nowCollected = isCatalogCollected(item);
    if (collectedItem == null && !nowCollected) {
      throw const KugouApiException('收藏未生效，请稍后重试');
    }
    if (collectedItem != null && nowCollected) {
      throw const KugouApiException('取消收藏未生效，请稍后重试');
    }
  }

  Future<void> _refreshCatalogCollection(SearchCategory category) async {
    switch (category) {
      case SearchCategory.playlist:
        await ensureLoaded(LibrarySection.playlists, refresh: true);
      case SearchCategory.album:
        throw const KugouApiException('暂不支持收藏专辑');
      case SearchCategory.artist:
        await ensureLoaded(LibrarySection.artists, refresh: true);
      case SearchCategory.song:
        break;
    }
  }

  SearchCatalogItem? _collectedCatalogItem(SearchCatalogItem item) {
    switch (item.category) {
      case SearchCategory.playlist:
        for (final playlist in playlists) {
          if (playlist.kind == MusicPlaylistKind.collectedPlaylist &&
              (_sameCatalog(
                    playlist.id,
                    item.id,
                    playlist.listId,
                    item.listId,
                  ) ||
                  _sameCatalog(
                    playlist.sourceId ?? '',
                    item.id,
                    playlist.sourceListId ?? '',
                    item.listId,
                  ) ||
                  _sameCatalogTitle(playlist.name, item.title))) {
            return SearchCatalogItem(
              id: playlist.id,
              title: playlist.name,
              subtitle: '${playlist.songCount} 首歌曲',
              category: SearchCategory.playlist,
              imageUrl: playlist.coverUrl,
              listId: playlist.listId,
              ownerId: playlist.sourceId,
            );
          }
        }
      case SearchCategory.album:
        return null;
      case SearchCategory.artist:
        for (final artist in followedArtists) {
          if (artist.id == item.id || artist.title == item.title) {
            return artist;
          }
        }
      case SearchCategory.song:
        return null;
    }
    return null;
  }

  Future<void> toggleFavorite(Song song) async {
    final favorite = favoritePlaylist;
    if (favorite == null) {
      throw const KugouApiException('没有找到默认收藏歌单');
    }
    final existing = favorites.cast<Song?>().firstWhere(
      (item) => item != null && _sameSong(item, song),
      orElse: () => null,
    );
    if (existing == null) {
      await repository.addSongToPlaylist(favorite, song);
    } else {
      await repository.removeSongFromPlaylist(favorite, existing);
      favorites = favorites
          .where((item) => !_sameSong(item, existing))
          .toList(growable: false);
      unawaited(_saveCache());
      notifyListeners();
    }
    await ensureLoaded(LibrarySection.songs, refresh: true);
  }

  Future<void> addToPlaylist(MusicPlaylist playlist, Song song) async {
    await repository.addSongToPlaylist(playlist, song);
    await ensureLoaded(LibrarySection.playlists, refresh: true);
  }

  Future<void> removeFromPlaylist(MusicPlaylist playlist, Song song) async {
    await repository.removeSongFromPlaylist(playlist, song);
    await ensureLoaded(LibrarySection.playlists, refresh: true);
  }

  bool _sameSong(Song left, Song right) {
    final leftHash = left.hash;
    final rightHash = right.hash;
    if (leftHash != null &&
        leftHash.isNotEmpty &&
        rightHash != null &&
        rightHash.isNotEmpty) {
      return leftHash == rightHash;
    }
    return left.id == right.id;
  }

  bool _sameCatalog(
    String leftId,
    String rightId,
    String leftListId,
    String? rightListId,
  ) {
    if (leftId.isNotEmpty && rightId.isNotEmpty && leftId == rightId) {
      return true;
    }
    return leftListId.isNotEmpty &&
        rightListId != null &&
        rightListId.isNotEmpty &&
        leftListId == rightListId;
  }

  bool _sameCatalogTitle(String left, String right) {
    final normalizedLeft = left.trim().toLowerCase();
    final normalizedRight = right.trim().toLowerCase();
    return normalizedLeft.isNotEmpty && normalizedLeft == normalizedRight;
  }
}
