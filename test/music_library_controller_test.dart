import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/controllers/music_library_controller.dart';
import 'package:qing_ting_music/data/music_repository.dart';
import 'package:qing_ting_music/models/lyric.dart';
import 'package:qing_ting_music/models/music_playlist.dart';
import 'package:qing_ting_music/models/search_catalog_item.dart';
import 'package:qing_ting_music/models/song.dart';
import 'package:qing_ting_music/services/kugou_api_client.dart';
import 'package:qing_ting_music/services/music_library_cache_service.dart';

void main() {
  test('preserves catalog owner id in playlist cache data', () {
    const playlist = MusicPlaylist(
      id: 'collection-album-100',
      listId: 'generated-listid',
      name: '测试专辑',
      songCount: 10,
      ownerId: 'artist-1',
      kind: MusicPlaylistKind.album,
    );

    final restored = MusicPlaylist.fromJson(playlist.toJson());

    expect(restored.ownerId, 'artist-1');
    expect(restored.sourceAlbumId, 'generated-listid');
  });

  test('uses original album id instead of user collection list id', () {
    const playlist = MusicPlaylist(
      id: 'collection-local',
      listId: 'generated-listid',
      sourceListId: 'album-100',
      name: '测试专辑',
      songCount: 10,
      kind: MusicPlaylistKind.album,
    );

    expect(playlist.sourceAlbumId, 'album-100');
  });

  test(
    'uses original playlist identifiers instead of collection record ids',
    () {
      const playlist = MusicPlaylist(
        id: 'collection-local',
        listId: 'generated-listid',
        sourceId: 'global-playlist-100',
        sourceListId: 'source-listid',
        name: '测试歌单',
        songCount: 10,
        kind: MusicPlaylistKind.collectedPlaylist,
      );

      expect(playlist.sourcePlaylistId, 'global-playlist-100');
      expect(playlist.sourcePlaylistListId, 'source-listid');
    },
  );

  test('removes the final favorite song from local state', () async {
    final favorite = _playlist(
      'favorite',
      kind: MusicPlaylistKind.favoriteSongs,
      name: '我喜欢',
    );
    final song = _song('only').copyWith(fileId: 1001);
    final repository = _FakeMusicRepository(
      playlists: [favorite],
      favoriteSongs: [song],
    );
    final controller = _controller(repository);

    await controller.ensureLoaded(LibrarySection.playlists, refresh: true);
    await controller.ensureLoaded(LibrarySection.songs, refresh: true);
    expect(controller.favorites, hasLength(1));

    await controller.toggleFavorite(song);

    expect(repository.removedSongs, [song.id]);
    expect(controller.favorites, isEmpty);
    expect(controller.hasData(LibrarySection.songs), isFalse);
  });

  test(
    'resolves fileId from playlist tracks when removing a song with null fileId',
    () async {
      final playlist = _playlist(
        'created-1',
        kind: MusicPlaylistKind.createdPlaylist,
        name: '自建歌单',
      );
      final songInPlaylist = _song('song-album').copyWith(fileId: 9988);
      final repository = _FakeMusicRepository(
        playlists: [playlist],
        favoriteSongs: const [],
        playlistTracks: {
          'created-1': [songInPlaylist],
        },
      );
      final controller = _controller(repository);

      // This song object represents a song viewed in an album/search (fileId is null)
      final songFromAlbum = _song('song-album');
      expect(songFromAlbum.fileId, isNull);

      await controller.removeFromPlaylist(playlist, songFromAlbum);

      expect(repository.removedSongs, ['song-album']);
      expect(repository.removedSongObjects.single.fileId, 9988);
    },
  );

  test('refreshes playlist tab even when cached playlists exist', () async {
    final cached = _playlist('cached', name: '收藏歌单').copyWith(songCount: 0);
    final fresh = _playlist('cached', name: '收藏歌单').copyWith(songCount: 12);
    final repository = _FakeMusicRepository(
      playlists: [fresh],
      favoriteSongs: const [],
    );
    final controller = _controller(repository)..playlists = [cached];

    await controller.ensureLoaded(LibrarySection.playlists);

    expect(repository.playlistRequests, 1);
    expect(controller.playlists.single.songCount, 12);
  });

  test('refreshes cloud songs tab and updates list unconditionally', () async {
    final song1 = _song('cloud-1');
    final song2 = _song('cloud-2');
    final repository = _FakeMusicRepository(
      playlists: const [],
      favoriteSongs: const [],
    )..cloudSongs = [song1];
    final controller = _controller(repository);

    await controller.ensureLoaded(LibrarySection.cloud);
    expect(controller.cloudSongs, [song1]);
    expect(repository.cloudRequests, 1);

    // Ensure it doesn't refetch without refresh flag when already loaded
    await controller.ensureLoaded(LibrarySection.cloud);
    expect(repository.cloudRequests, 1);

    // Refresh with new song uploaded
    repository.cloudSongs = [song1, song2];
    await controller.ensureLoaded(LibrarySection.cloud, refresh: true);
    expect(controller.cloudSongs, [song1, song2]);
    expect(repository.cloudRequests, 2);

    // Refresh when all songs deleted
    repository.cloudSongs = [];
    await controller.ensureLoaded(LibrarySection.cloud, refresh: true);
    expect(controller.cloudSongs, isEmpty);
    expect(repository.cloudRequests, 3);
  });

  test(
    'sorts cloud songs descending by addTime (latest uploaded first)',
    () async {
      final songOld = _song('cloud-old').copyWith(addTime: 1517468162);
      final songMid = _song('cloud-mid').copyWith(addTime: 1782640807);
      final songNew = _song('cloud-new').copyWith(addTime: 1789277682);
      final repository = _FakeMusicRepository(
        playlists: const [],
        favoriteSongs: const [],
      )..cloudSongs = [songNew, songOld, songMid];
      final controller = _controller(repository);

      await controller.ensureLoaded(LibrarySection.cloud);
      expect(controller.sortedCloudSongs.map((s) => s.id), [
        'cloud-new',
        'cloud-mid',
        'cloud-old',
      ]);
    },
  );

  test('preserves addTime across song serialization and deserialization', () {
    final song = _song('cloud-1').copyWith(addTime: 1789277682);
    final restored = Song.fromJson(song.toJson());
    expect(restored.addTime, 1789277682);
  });

  test('keeps created and collected playlists separated', () async {
    final created = _playlist(
      'created',
      name: '创建歌单',
      kind: MusicPlaylistKind.createdPlaylist,
    );
    final collected = _playlist(
      'collected',
      name: '收藏歌单',
      kind: MusicPlaylistKind.collectedPlaylist,
    );
    final repository = _FakeMusicRepository(
      playlists: [created, collected],
      favoriteSongs: const [],
    );
    final controller = _controller(repository);

    await controller.ensureLoaded(LibrarySection.playlists, refresh: true);

    expect(controller.createdPlaylists.map((item) => item.name), ['创建歌单']);
    expect(controller.collectedPlaylists.map((item) => item.name), ['收藏歌单']);
  });

  test(
    'identifies playlists containing specific song and prevents duplicate addition',
    () async {
      final playlistA = _playlist('ident-p1', name: '歌单A');
      final playlistB = _playlist('ident-p2', name: '歌单B');
      final song = _song('s1');
      final repository = _FakeMusicRepository(
        playlists: [playlistA, playlistB],
        favoriteSongs: const [],
        playlistTracks: {
          'ident-p1': [song],
        },
      );
      final controller = _controller(repository);

      final containing = await controller.getPlaylistIdsContainingSong(song, [
        playlistA,
        playlistB,
      ]);
      expect(containing, contains('ident-p1'));
      expect(containing, isNot(contains('ident-p2')));

      expect(
        () => controller.addToPlaylist(playlistA, song),
        throwsA(isA<KugouApiException>()),
      );
    },
  );

  test('refreshes playlist songs after adding to a cached playlist', () async {
    final playlist = _playlist('unique-refresh-p1', name: '歌单A');
    final existingSong = _song('existing');
    final addedSong = _song('added');
    final repository = _FakeMusicRepository(
      playlists: [playlist],
      favoriteSongs: const [],
      playlistTracks: {
        'unique-refresh-p1': [existingSong],
      },
    );
    final controller = _controller(repository);

    await controller.loadPlaylist(playlist);
    await controller.addToPlaylist(playlist, addedSong);

    final songs = await controller.loadPlaylist(playlist);
    expect(songs.map((item) => item.id), contains('added'));
    expect(
      controller.getPlaylistIdsContainingSongSync(addedSong, [playlist]),
      contains('unique-refresh-p1'),
    );
    expect(controller.isSongInAnyPlaylistSync(addedSong), isTrue);
  });

  test('refreshes persisted playlist songs once per app session', () async {
    final playlist = _playlist('session-refresh-p1', name: '歌单A');
    final staleSong = _song('stale');
    final freshSong = _song('fresh');
    final repository = _FakeMusicRepository(
      playlists: [playlist],
      favoriteSongs: const [],
      playlistTracks: {
        'session-refresh-p1': [freshSong],
      },
    );
    final cache = _FakeMusicLibraryCacheService()
      ..seedPlaylistSongs(playlist, [staleSong]);
    final controller = MusicLibraryController(repository, cacheService: cache);

    final firstLoad = await controller.loadPlaylist(playlist);
    final secondLoad = await controller.loadPlaylist(playlist);

    expect(firstLoad.map((song) => song.id), ['fresh']);
    expect(secondLoad.map((song) => song.id), ['fresh']);
    expect(repository.playlistSongRequests, 1);
  });

  test(
    'shows non-favorite default collection with created playlists',
    () async {
      final defaultCollection = _playlist(
        'default-collection',
        name: '默认收藏',
        kind: MusicPlaylistKind.createdPlaylist,
      );
      final favoriteSongs = _playlist(
        'favorite-songs',
        name: '我喜欢',
        kind: MusicPlaylistKind.favoriteSongs,
      );
      final repository = _FakeMusicRepository(
        playlists: [defaultCollection, favoriteSongs],
        favoriteSongs: const [],
      );
      final controller = _controller(repository);

      await controller.ensureLoaded(LibrarySection.playlists, refresh: true);

      expect(controller.createdPlaylists.map((item) => item.name), ['默认收藏']);
      expect(controller.favoritePlaylist?.name, '我喜欢');
    },
  );

  test('collects playlist and refreshes playlist collection state', () async {
    const playlist = SearchCatalogItem(
      id: 'global-playlist-100',
      title: '测试歌单',
      subtitle: '100 首歌曲',
      category: SearchCategory.playlist,
      listId: 'source-listid',
    );
    final repository = _FakeMusicRepository(
      playlists: [],
      favoriteSongs: const [],
    );
    final controller = _controller(repository);

    await controller.toggleCatalogCollection(playlist);

    expect(repository.collectedCatalogs, [SearchCategory.playlist]);
    expect(controller.isCatalogCollected(playlist), isTrue);
  });

  test('uncollects playlist with generated user list id', () async {
    const playlist = SearchCatalogItem(
      id: 'global-playlist-100',
      title: '测试歌单',
      subtitle: '100 首歌曲',
      category: SearchCategory.playlist,
      listId: 'source-listid',
    );
    final collectedPlaylist = MusicPlaylist(
      id: 'global-playlist-100',
      listId: 'generated-listid',
      name: '测试歌单',
      songCount: 100,
      sourceId: 'global-playlist-100',
      sourceListId: 'source-listid',
      kind: MusicPlaylistKind.collectedPlaylist,
    );
    final repository = _FakeMusicRepository(
      playlists: [collectedPlaylist],
      favoriteSongs: const [],
    );
    final controller = _controller(repository);
    await controller.ensureLoaded(LibrarySection.playlists, refresh: true);

    await controller.toggleCatalogCollection(playlist);

    expect(repository.uncollectedListIds, ['generated-listid']);
    expect(controller.isCatalogCollected(playlist), isFalse);
  });

  test('collects album and refreshes album collection state', () async {
    const album = SearchCatalogItem(
      id: 'album-100',
      title: '测试专辑',
      subtitle: '测试歌手',
      category: SearchCategory.album,
      listId: 'album-100',
      ownerId: 'artist-1',
    );
    final repository = _FakeMusicRepository(
      playlists: [],
      favoriteSongs: const [],
    );
    final controller = _controller(repository);

    await controller.toggleCatalogCollection(album);

    expect(repository.collectedCatalogs, [SearchCategory.album]);
    expect(controller.isCatalogCollected(album), isTrue);
  });

  test('uncollects album with generated user list id', () async {
    const album = SearchCatalogItem(
      id: 'album-100',
      title: '测试专辑',
      subtitle: '测试歌手',
      category: SearchCategory.album,
      listId: 'album-100',
    );
    final collectedAlbum = MusicPlaylist(
      id: 'collection-local',
      listId: 'generated-listid',
      name: '测试专辑',
      songCount: 10,
      ownerId: 'artist-1',
      sourceListId: 'album-100',
      kind: MusicPlaylistKind.album,
    );
    final repository = _FakeMusicRepository(
      playlists: [collectedAlbum],
      favoriteSongs: const [],
    );
    final controller = _controller(repository);
    await controller.ensureLoaded(LibrarySection.albums, refresh: true);

    await controller.toggleCatalogCollection(album);

    expect(repository.uncollectedListIds, ['generated-listid']);
    expect(repository.uncollectedCatalogs.single.ownerId, 'artist-1');
    expect(controller.isCatalogCollected(album), isFalse);
  });

  test(
    'isFavorite performs O(1) matching with high performance for large playlists',
    () {
      final repository = _FakeMusicRepository(playlists: [], favoriteSongs: []);
      final controller = _controller(repository);

      // Prepare 500 favorites
      final favoritesList = List<Song>.generate(
        500,
        (i) => _song(
          'fav-$i',
          title: 'Favorite Song $i',
          artist: 'Artist $i',
          album: 'Album $i',
          hash: 'FAVORITE_HASH_$i',
          albumAudioId: 100000 + i,
        ),
      );
      controller.favorites = favoritesList;

      // Prepare 2000 songs in a playlist
      final playlistSongs = List<Song>.generate(
        2000,
        (i) => _song(
          'song-$i',
          title: 'Song $i',
          artist: 'Artist $i',
          album: 'Album $i',
          hash: i % 2 == 0 ? 'FAVORITE_HASH_${i ~/ 2}' : 'NON_FAV_HASH_$i',
          albumAudioId: 200000 + i,
        ),
      );

      final stopwatch = Stopwatch()..start();
      final mapped = playlistSongs.map(controller.withFavoriteState).toList();
      stopwatch.stop();

      expect(mapped, hasLength(2000));
      expect(mapped[0].liked, isTrue);
      expect(mapped[1].liked, isFalse);
      expect(mapped[2].liked, isTrue);
      expect(mapped[498].liked, isTrue);
      // 2000 items with O(1) set lookup should execute in < 100ms (typically < 5ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    },
  );

  test(
    'isFavorite accurately identifies songs across hash, catalogHash, albumAudioId, and title/artist',
    () {
      final repository = _FakeMusicRepository(playlists: [], favoriteSongs: []);
      final controller = _controller(repository);

      controller.favorites = [
        _song(
          'fav-1',
          title: '晴天',
          artist: '周杰伦',
          album: '叶惠美',
          hash: 'hash_fav_1',
        ),
        _song(
          'fav-2',
          title: '稻香',
          artist: '周杰伦',
          album: '魔杰座',
          catalogHash: 'catalog_hash_2',
        ),
        _song(
          'fav-3',
          title: '告白气球',
          artist: '周杰伦',
          album: '周杰伦的床边故事',
          albumAudioId: 88888,
        ),
        _song('fav-4', title: '夜曲', artist: '周杰伦 / 周董', album: '十一月的萧邦'),
      ];

      // Direct hash match
      expect(
        controller.isFavorite(
          _song(
            'other-id-1',
            title: 'Different Title',
            artist: 'Different Artist',
            hash: 'HASH_FAV_1',
          ),
        ),
        isTrue,
      );

      // Cross check: cloud song catalogHash matching favorite direct hash
      expect(
        controller.isFavorite(
          _song(
            'cloud-song-1',
            title: 'Different Title',
            artist: 'Different Artist',
            catalogHash: 'hash_fav_1',
          ),
        ),
        isTrue,
      );

      // Cross check: regular song direct hash matching favorite catalogHash
      expect(
        controller.isFavorite(
          _song(
            'other-id-2',
            title: 'Different Title',
            artist: 'Different Artist',
            hash: 'CATALOG_HASH_2',
          ),
        ),
        isTrue,
      );

      // albumAudioId match
      expect(
        controller.isFavorite(
          _song(
            'other-id-3',
            title: 'Different Title',
            artist: 'Different Artist',
            albumAudioId: 88888,
          ),
        ),
        isTrue,
      );

      // Canonical title and artist match
      expect(
        controller.isFavorite(
          _song('other-id-4', title: '  夜曲  ', artist: '周杰伦、周董'),
        ),
        isTrue,
      );

      // Non-favorite song
      expect(
        controller.isFavorite(
          _song(
            'not-fav',
            title: '青花瓷',
            artist: '周杰伦',
            hash: 'some_other_hash',
          ),
        ),
        isFalse,
      );
    },
  );
}

Song _song(
  String id, {
  String? title,
  String? artist,
  String? album,
  String? hash,
  String? catalogHash,
  int? albumAudioId,
}) => Song(
  id: id,
  title: title ?? id,
  artist: artist ?? 'artist',
  album: album ?? 'album',
  duration: const Duration(minutes: 3),
  audioUrl: 'https://example.com/$id.mp3',
  hash: hash ?? 'hash-$id',
  catalogHash: catalogHash,
  albumAudioId: albumAudioId,
);

MusicPlaylist _playlist(
  String id, {
  String? name,
  MusicPlaylistKind kind = MusicPlaylistKind.createdPlaylist,
}) => MusicPlaylist(
  id: id,
  listId: id,
  name: name ?? id,
  songCount: 1,
  kind: kind,
);

class _FakeMusicLibraryCacheService extends MusicLibraryCacheService {
  MusicLibrarySnapshot _snapshot = const MusicLibrarySnapshot();
  final Map<String, List<Song>> _tracks = {};

  void seedPlaylistSongs(MusicPlaylist playlist, List<Song> songs) {
    _tracks['${playlist.kind.name}:${playlist.listId}'] = List.of(songs);
  }

  @override
  Future<MusicLibrarySnapshot> load() async => _snapshot;

  @override
  Future<void> save(MusicLibrarySnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<List<Song>> loadPlaylistSongs(String cacheKey) async {
    return _tracks[cacheKey] ?? const [];
  }

  @override
  List<Song> getPlaylistSongsSync(String cacheKey) {
    return _tracks[cacheKey] ?? const [];
  }

  @override
  Future<void> savePlaylistSongs(String cacheKey, List<Song> songs) async {
    _tracks[cacheKey] = List.of(songs);
  }

  @override
  Future<void> clearPlaylistSongs(String cacheKey) async {
    _tracks.remove(cacheKey);
  }
}

MusicLibraryController _controller(MusicRepository repository) =>
    MusicLibraryController(
      repository,
      cacheService: _FakeMusicLibraryCacheService(),
    );

class _FakeMusicRepository implements MusicRepository {
  _FakeMusicRepository({
    required this.playlists,
    required List<Song> favoriteSongs,
    Map<String, List<Song>>? playlistTracks,
  }) : _favoriteSongs = List.of(favoriteSongs),
       playlistTracks = playlistTracks ?? {};

  final List<MusicPlaylist> playlists;
  final List<String> removedSongs = [];
  final List<Song> removedSongObjects = [];
  final List<SearchCategory> collectedCatalogs = [];
  final List<String> uncollectedListIds = [];
  final List<SearchCatalogItem> uncollectedCatalogs = [];
  final List<Song> _favoriteSongs;
  final Map<String, List<Song>> playlistTracks;
  List<Song> cloudSongs = const [];
  int playlistRequests = 0;
  int playlistSongRequests = 0;
  int cloudRequests = 0;

  @override
  Future<List<MusicPlaylist>> getUserPlaylists() async {
    playlistRequests++;
    return List.unmodifiable(playlists);
  }

  @override
  Future<List<Song>> getPlaylistSongs(MusicPlaylist playlist) async {
    playlistSongRequests++;
    if (playlist.kind == MusicPlaylistKind.favoriteSongs) {
      return List.unmodifiable(_favoriteSongs);
    }
    if (playlistTracks.containsKey(playlist.id)) {
      return List.of(playlistTracks[playlist.id]!);
    }
    if (playlistTracks.containsKey(playlist.listId)) {
      return List.unmodifiable(playlistTracks[playlist.listId]!);
    }
    return const [];
  }

  @override
  Future<void> removeSongFromPlaylist(MusicPlaylist playlist, Song song) async {
    removedSongs.add(song.id);
    removedSongObjects.add(song);
    _favoriteSongs.removeWhere((item) => item.id == song.id);
  }

  @override
  Future<void> addSongToPlaylist(MusicPlaylist playlist, Song song) async {
    if (playlist.kind == MusicPlaylistKind.favoriteSongs) {
      _favoriteSongs.add(song);
      return;
    }
    final key = playlist.listId.isNotEmpty ? playlist.listId : playlist.id;
    playlistTracks.putIfAbsent(key, () => []).add(song);
  }

  @override
  Future<void> createPlaylist(String name, {bool isPrivate = false}) async {
    playlists.add(
      MusicPlaylist(
        id: 'created-$name',
        listId: 'created-$name',
        name: name,
        songCount: 0,
      ),
    );
  }

  @override
  Future<void> deletePlaylist(MusicPlaylist playlist) async {
    playlists.removeWhere((item) => item.listId == playlist.listId);
  }

  @override
  Future<List<SearchCatalogItem>> getArtistAlbums(
    SearchCatalogItem artist,
  ) async => const [];

  @override
  Future<List<SearchCatalogItem>> getArtistAlbumsPage(
    SearchCatalogItem artist, {
    required int page,
    int pageSize = 50,
  }) async => const [];

  @override
  Future<List<SearchCatalogItem>> getSimilarArtists(
    SearchCatalogItem artist,
  ) async => const [];

  @override
  Future<List<Song>> getCatalogSongs(SearchCatalogItem item) async => const [];

  @override
  Future<List<Song>> getArtistMvs(
    SearchCatalogItem artist, {
    int page = 1,
    int pageSize = 30,
  }) async => const [];

  @override
  Future<List<Song>> getCloudSongs() async {
    cloudRequests++;
    return List.unmodifiable(cloudSongs);
  }

  @override
  Future<List<SearchCatalogItem>> getFollowedArtists() async => const [];

  @override
  Future<void> collectCatalog(SearchCatalogItem item) async {
    collectedCatalogs.add(item.category);
    if (item.category == SearchCategory.playlist) {
      playlists.add(
        MusicPlaylist(
          id: item.id,
          listId: 'generated-${item.id}',
          name: item.title,
          songCount: 1,
          coverUrl: item.imageUrl,
          sourceId: item.id,
          sourceListId: item.listId,
          kind: MusicPlaylistKind.collectedPlaylist,
        ),
      );
    } else if (item.category == SearchCategory.album) {
      playlists.add(
        MusicPlaylist(
          id: 'collection-${item.id}',
          listId: 'generated-${item.id}',
          name: item.title,
          songCount: 1,
          coverUrl: item.imageUrl,
          sourceListId: item.listId ?? item.id,
          kind: MusicPlaylistKind.album,
        ),
      );
    }
  }

  @override
  Future<void> uncollectCatalog(SearchCatalogItem item) async {
    uncollectedCatalogs.add(item);
    uncollectedListIds.add(item.listId ?? item.id);
    playlists.removeWhere((playlist) => playlist.listId == item.listId);
  }

  @override
  Future<List<Song>> getHotSongs() async => const [];

  @override
  Future<List<Song>> getNewSongs() async => const [];

  @override
  Future<List<Song>> getDailyRecommendations() async => const [];

  @override
  Future<List<Song>> getPersonalFmSongs({
    String action = 'play',
    Song? contextSong,
    int playtimeSeconds = 0,
    bool isOverplay = false,
    String mode = 'normal',
    int songPoolId = 0,
    int remainSongCount = 0,
  }) async => const [];

  @override
  Future<Song> resolvePlayback(Song song) async => song;

  @override
  Future<List<LyricLine>> getLyrics(Song song) async => const [];

  @override
  Future<List<String>> getArtistPortraits(Song song) async => const [];

  @override
  Future<List<SearchCatalogItem>> searchCatalog(
    String keyword,
    SearchCategory category,
  ) async => const [];

  @override
  Future<List<Song>> searchSongs(String keyword) async => const [];

  @override
  Future<List<String>> searchSuggestions(String keyword) async => const [];

  @override
  Future<List<SongClimaxSegment>> getSongClimax(String hash) async => const [];

  @override
  Future<String?> getAlbumReleaseDate(String albumId) async => null;
}
