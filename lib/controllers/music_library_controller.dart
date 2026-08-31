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
  final Map<String, List<Song>> _playlistTracksInMemory = {};
  final Set<String> _playlistCachesRefreshedThisSession = {};
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
    playlists = _resolvePlaylistCovers(snapshot.playlists);
    favorites = snapshot.favorites;
    cloudSongs = snapshot.cloudSongs;
    followedArtists = snapshot.artists;
    albums = snapshot.albums;
    _prefetchCreatedPlaylistsCovers(playlists);
    notifyListeners();
  }

  void invalidateLoadedState() {
    loaded.clear();
    loading.clear();
    errors.clear();
    _playlistCachesRefreshedThisSession.clear();
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
    _playlistTracksInMemory.clear();
    _playlistCachesRefreshedThisSession.clear();
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
            _prefetchCreatedPlaylistsCovers(playlists);
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
            _prefetchCreatedPlaylistsCovers(playlists);
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
  }) async {
    if (!refresh && allowCache && playlists.isNotEmpty) {
      return _resolvePlaylistCovers(playlists);
    }
    final raw = await (_playlistRequest ??= repository
        .getUserPlaylists()
        .whenComplete(() {
          _playlistRequest = null;
        }));
    return _resolvePlaylistCovers(raw);
  }

  List<MusicPlaylist> _resolvePlaylistCovers(List<MusicPlaylist> list) {
    final result = <MusicPlaylist>[];
    for (final playlist in list) {
      if (!playlist.hasCustomCover &&
          (playlist.kind == MusicPlaylistKind.createdPlaylist ||
              playlist.kind == MusicPlaylistKind.favoriteSongs)) {
        final cacheKey = _playlistCacheKey(playlist);
        final cached =
            _playlistTracksInMemory[cacheKey] ??
            cacheService.getPlaylistSongsSync(cacheKey);
        if (cached.isNotEmpty &&
            cached.first.coverUrl != null &&
            cached.first.coverUrl!.isNotEmpty) {
          result.add(playlist.copyWith(coverUrl: cached.first.coverUrl));
          continue;
        }
        final existing = playlists
            .where(
              (p) =>
                  (p.id.isNotEmpty && p.id == playlist.id) ||
                  (p.listId.isNotEmpty && p.listId == playlist.listId),
            )
            .firstOrNull;
        if (existing != null &&
            existing.coverUrl != null &&
            existing.coverUrl!.isNotEmpty) {
          result.add(playlist.copyWith(coverUrl: existing.coverUrl));
          continue;
        }
      }
      result.add(playlist);
    }
    return result;
  }

  void _prefetchCreatedPlaylistsCovers(List<MusicPlaylist> list) {
    for (final playlist in list) {
      if (!playlist.hasCustomCover &&
          (playlist.kind == MusicPlaylistKind.createdPlaylist ||
              playlist.kind == MusicPlaylistKind.favoriteSongs)) {
        final cacheKey = _playlistCacheKey(playlist);
        if (_playlistTracksInMemory.containsKey(cacheKey)) continue;
        unawaited(() async {
          try {
            final cached = await cacheService.loadPlaylistSongs(cacheKey);
            if (cached.isNotEmpty) {
              _playlistTracksInMemory[cacheKey] = cached;
              if (cached.first.coverUrl != null &&
                  cached.first.coverUrl!.isNotEmpty) {
                _updatePlaylistCover(playlist, cached.first.coverUrl);
              }
              return;
            }
            final songs = await repository.getPlaylistSongs(playlist);
            if (songs.isNotEmpty) {
              _playlistTracksInMemory[cacheKey] = songs;
              _playlistCachesRefreshedThisSession.add(cacheKey);
              unawaited(cacheService.savePlaylistSongs(cacheKey, songs));
              if (songs.first.coverUrl != null &&
                  songs.first.coverUrl!.isNotEmpty) {
                _updatePlaylistCover(playlist, songs.first.coverUrl);
              }
            }
          } catch (_) {}
        }());
      }
    }
  }

  void _updatePlaylistCover(MusicPlaylist target, String? newCover) {
    if (newCover == null || newCover.trim().isEmpty) return;
    var updated = false;
    playlists = playlists.map((p) {
      if (p.id == target.id ||
          (p.listId.isNotEmpty && p.listId == target.listId)) {
        if (p.coverUrl != newCover) {
          updated = true;
          return p.copyWith(coverUrl: newCover);
        }
      }
      return p;
    }).toList();
    if (updated) {
      unawaited(_saveCache());
      notifyListeners();
    }
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

  Future<List<Song>> loadPlaylist(
    MusicPlaylist playlist, {
    bool refresh = false,
  }) async {
    final cacheKey = _playlistCacheKey(playlist);
    if (!refresh && _playlistCachesRefreshedThisSession.contains(cacheKey)) {
      return _playlistTracksInMemory[cacheKey] ?? const [];
    }

    final cached = !refresh
        ? _playlistTracksInMemory[cacheKey] ??
              await cacheService.loadPlaylistSongs(cacheKey)
        : const <Song>[];
    try {
      final songs = await repository.getPlaylistSongs(playlist);
      if (songs.isNotEmpty || cached.isEmpty || refresh) {
        _playlistTracksInMemory[cacheKey] = songs;
        _playlistCachesRefreshedThisSession.add(cacheKey);
        unawaited(cacheService.savePlaylistSongs(cacheKey, songs));
        if (!playlist.hasCustomCover &&
            (playlist.kind == MusicPlaylistKind.createdPlaylist ||
                playlist.kind == MusicPlaylistKind.favoriteSongs)) {
          final firstCover = songs.isNotEmpty ? songs.first.coverUrl : null;
          if (firstCover != null && firstCover.isNotEmpty) {
            _updatePlaylistCover(playlist, firstCover);
          }
        }
        return songs;
      }
    } catch (_) {
      if (cached.isEmpty || refresh) rethrow;
    }

    if (cached.isNotEmpty) {
      _playlistTracksInMemory[cacheKey] = cached;
      _updatePlaylistCoverFromSongs(playlist, cached);
    }
    return cached;
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
      _removeCollectedCatalogLocally(collectedItem);
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

  void _removeCollectedCatalogLocally(SearchCatalogItem item) {
    switch (item.category) {
      case SearchCategory.playlist:
        playlists = playlists
            .where(
              (playlist) =>
                  playlist.kind != MusicPlaylistKind.collectedPlaylist ||
                  !(_sameCatalog(
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
                      _sameCatalogTitle(playlist.name, item.title)),
            )
            .toList();
      case SearchCategory.album:
        playlists = playlists
            .where(
              (playlist) =>
                  playlist.kind != MusicPlaylistKind.album ||
                  !(_sameCatalog(
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
                      _sameCatalogTitle(playlist.name, item.title)),
            )
            .toList();
        albums = albums
            .where(
              (album) =>
                  !(_sameCatalog(
                        album.id,
                        item.id,
                        album.listId,
                        item.listId,
                      ) ||
                      _sameCatalog(
                        album.sourceId ?? '',
                        item.id,
                        album.sourceListId ?? '',
                        item.listId,
                      ) ||
                      _sameCatalogTitle(album.name, item.title)),
            )
            .toList();
      case SearchCategory.artist:
        followedArtists = followedArtists
            .where(
              (artist) => artist.id != item.id && artist.title != item.title,
            )
            .toList();
      case SearchCategory.song:
        break;
    }
  }

  Future<void> _refreshCatalogCollection(SearchCategory category) async {
    switch (category) {
      case SearchCategory.playlist:
        await ensureLoaded(LibrarySection.playlists, refresh: true);
      case SearchCategory.album:
        await ensureLoaded(LibrarySection.albums, refresh: true);
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
              subtitle: '${playlist.songCount} 首',
              category: SearchCategory.playlist,
              imageUrl: playlist.coverUrl,
              listId: playlist.listId,
              ownerId: playlist.ownerId,
            );
          }
        }
      case SearchCategory.album:
        for (final album in albums) {
          if (_sameCatalog(album.id, item.id, album.listId, item.listId) ||
              _sameCatalog(
                album.sourceId ?? '',
                item.id,
                album.sourceListId ?? '',
                item.listId,
              ) ||
              _sameCatalogTitle(album.name, item.title)) {
            return SearchCatalogItem(
              id: album.sourceListId ?? album.id,
              title: album.name,
              subtitle: '${album.songCount} 首',
              category: SearchCategory.album,
              imageUrl: album.coverUrl,
              listId: album.listId,
              ownerId: album.ownerId,
            );
          }
        }
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
    final cacheKey = _playlistCacheKey(playlist);
    try {
      final existingSongs = await loadPlaylist(playlist);
      if (existingSongs.any((item) => _sameSong(item, song))) {
        throw const KugouApiException('歌单中已存在该歌曲');
      }
    } catch (e) {
      if (e is KugouApiException) rethrow;
    }
    await repository.addSongToPlaylist(playlist, song);
    _playlistTracksInMemory.remove(cacheKey);
    _playlistCachesRefreshedThisSession.remove(cacheKey);
    await cacheService.clearPlaylistSongs(cacheKey);
    final freshSongs = await repository.getPlaylistSongs(playlist);
    if (freshSongs.isNotEmpty) {
      _playlistTracksInMemory[cacheKey] = freshSongs;
      _playlistCachesRefreshedThisSession.add(cacheKey);
      unawaited(cacheService.savePlaylistSongs(cacheKey, freshSongs));
      if (!playlist.hasCustomCover &&
          (playlist.kind == MusicPlaylistKind.createdPlaylist ||
              playlist.kind == MusicPlaylistKind.favoriteSongs)) {
        final firstCover = freshSongs.first.coverUrl;
        if (firstCover != null && firstCover.isNotEmpty) {
          _updatePlaylistCover(playlist, firstCover);
        }
      }
    }
    await ensureLoaded(LibrarySection.playlists, refresh: true);
  }

  Set<String> getPlaylistIdsContainingSongSync(
    Song song,
    List<MusicPlaylist> targetPlaylists,
  ) {
    final containingIds = <String>{};
    for (final playlist in targetPlaylists) {
      final cacheKey = _playlistCacheKey(playlist);
      final songs =
          _playlistTracksInMemory[cacheKey] ??
          cacheService.getPlaylistSongsSync(cacheKey);
      if (songs.any((item) => _sameSong(item, song))) {
        final key = playlist.listId.isNotEmpty ? playlist.listId : playlist.id;
        containingIds.add(key);
      }
    }
    return containingIds;
  }

  Future<Set<String>> getPlaylistIdsContainingSong(
    Song song,
    List<MusicPlaylist> targetPlaylists,
  ) async {
    final containingIds = getPlaylistIdsContainingSongSync(
      song,
      targetPlaylists,
    );
    if (containingIds.isNotEmpty) return containingIds;
    await Future.wait(
      targetPlaylists.map((playlist) async {
        try {
          final songs = await loadPlaylist(playlist);
          if (songs.any((item) => _sameSong(item, song))) {
            final key = playlist.listId.isNotEmpty
                ? playlist.listId
                : playlist.id;
            containingIds.add(key);
          }
        } catch (_) {}
      }),
    );
    return containingIds;
  }

  Future<void> removeFromPlaylist(MusicPlaylist playlist, Song song) async {
    await repository.removeSongFromPlaylist(playlist, song);
    final cacheKey = _playlistCacheKey(playlist);
    _playlistTracksInMemory.remove(cacheKey);
    _playlistCachesRefreshedThisSession.remove(cacheKey);
    await cacheService.clearPlaylistSongs(cacheKey);
    final freshSongs = await repository.getPlaylistSongs(playlist);
    if (freshSongs.isNotEmpty) {
      _playlistTracksInMemory[cacheKey] = freshSongs;
      _playlistCachesRefreshedThisSession.add(cacheKey);
      unawaited(cacheService.savePlaylistSongs(cacheKey, freshSongs));
      if (!playlist.hasCustomCover &&
          (playlist.kind == MusicPlaylistKind.createdPlaylist ||
              playlist.kind == MusicPlaylistKind.favoriteSongs)) {
        final firstCover = freshSongs.first.coverUrl;
        if (firstCover != null && firstCover.isNotEmpty) {
          _updatePlaylistCover(playlist, firstCover);
        }
      }
    }
    await ensureLoaded(LibrarySection.playlists, refresh: true);
  }

  Future<void> createPlaylist(String name, {bool isPrivate = false}) async {
    await repository.createPlaylist(name, isPrivate: isPrivate);
    loaded.remove(LibrarySection.playlists);
    await ensureLoaded(LibrarySection.playlists, refresh: true);
  }

  Future<void> deletePlaylist(MusicPlaylist playlist) async {
    if (playlist.isDefault) {
      throw const KugouApiException('默认收藏歌单不能删除');
    }
    await repository.deletePlaylist(playlist);
    playlists = playlists
        .where((item) => item.listId != playlist.listId)
        .toList();
    unawaited(cacheService.clearPlaylistSongs(_playlistCacheKey(playlist)));
    unawaited(_saveCache());
    notifyListeners();
    loaded.remove(LibrarySection.playlists);
    await ensureLoaded(LibrarySection.playlists, refresh: true);
  }

  void _updatePlaylistCoverFromSongs(MusicPlaylist playlist, List<Song> songs) {
    if (playlist.hasCustomCover || songs.isEmpty) return;
    if (playlist.kind != MusicPlaylistKind.createdPlaylist &&
        playlist.kind != MusicPlaylistKind.favoriteSongs) {
      return;
    }
    final firstCover = songs.first.coverUrl;
    if (firstCover != null && firstCover.isNotEmpty) {
      _updatePlaylistCover(playlist, firstCover);
    }
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

  String _playlistCacheKey(MusicPlaylist playlist) {
    final identity = playlist.listId.isNotEmpty
        ? playlist.listId
        : playlist.sourceListId?.isNotEmpty == true
        ? playlist.sourceListId!
        : playlist.sourceId?.isNotEmpty == true
        ? playlist.sourceId!
        : playlist.id;
    return '${playlist.kind.name}:$identity';
  }
}
