import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/controllers/music_library_controller.dart';
import 'package:qing_ting_music/data/music_repository.dart';
import 'package:qing_ting_music/models/lyric.dart';
import 'package:qing_ting_music/models/music_playlist.dart';
import 'package:qing_ting_music/models/search_catalog_item.dart';
import 'package:qing_ting_music/models/song.dart';
import 'package:qing_ting_music/services/kugou_api_client.dart';

void main() {
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
    final controller = MusicLibraryController(repository);

    await controller.ensureLoaded(LibrarySection.playlists, refresh: true);
    await controller.ensureLoaded(LibrarySection.songs, refresh: true);
    expect(controller.favorites, hasLength(1));

    await controller.toggleFavorite(song);

    expect(repository.removedSongs, [song.id]);
    expect(controller.favorites, isEmpty);
    expect(controller.hasData(LibrarySection.songs), isFalse);
  });

  test('refreshes playlist tab even when cached playlists exist', () async {
    final cached = _playlist('cached', name: '收藏歌单').copyWith(songCount: 0);
    final fresh = _playlist('cached', name: '收藏歌单').copyWith(songCount: 12);
    final repository = _FakeMusicRepository(
      playlists: [fresh],
      favoriteSongs: const [],
    );
    final controller = MusicLibraryController(repository)..playlists = [cached];

    await controller.ensureLoaded(LibrarySection.playlists);

    expect(repository.playlistRequests, 1);
    expect(controller.playlists.single.songCount, 12);
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
    final controller = MusicLibraryController(repository);

    await controller.ensureLoaded(LibrarySection.playlists, refresh: true);

    expect(controller.createdPlaylists.map((item) => item.name), ['创建歌单']);
    expect(controller.collectedPlaylists.map((item) => item.name), ['收藏歌单']);
  });

  test('identifies playlists containing specific song and prevents duplicate addition', () async {
    final playlistA = _playlist('p1', name: '歌单A');
    final playlistB = _playlist('p2', name: '歌单B');
    final song = _song('s1');
    final repository = _FakeMusicRepository(
      playlists: [playlistA, playlistB],
      favoriteSongs: const [],
      playlistTracks: {'p1': [song]},
    );
    final controller = MusicLibraryController(repository);

    final containing = await controller.getPlaylistIdsContainingSong(song, [playlistA, playlistB]);
    expect(containing, contains('p1'));
    expect(containing, isNot(contains('p2')));

    expect(
      () => controller.addToPlaylist(playlistA, song),
      throwsA(isA<KugouApiException>()),
    );
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
      final controller = MusicLibraryController(repository);

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
    final controller = MusicLibraryController(repository);

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
    final controller = MusicLibraryController(repository);
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
    final controller = MusicLibraryController(repository);

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
      sourceListId: 'album-100',
      kind: MusicPlaylistKind.album,
    );
    final repository = _FakeMusicRepository(
      playlists: [collectedAlbum],
      favoriteSongs: const [],
    );
    final controller = MusicLibraryController(repository);
    await controller.ensureLoaded(LibrarySection.albums, refresh: true);

    await controller.toggleCatalogCollection(album);

    expect(repository.uncollectedListIds, ['generated-listid']);
    expect(controller.isCatalogCollected(album), isFalse);
  });
}

Song _song(String id) => Song(
  id: id,
  title: id,
  artist: 'artist',
  album: 'album',
  duration: const Duration(minutes: 3),
  audioUrl: 'https://example.com/$id.mp3',
  hash: 'hash-$id',
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

extension _MusicPlaylistTestCopy on MusicPlaylist {
  MusicPlaylist copyWith({int? songCount}) {
    return MusicPlaylist(
      id: id,
      listId: listId,
      name: name,
      songCount: songCount ?? this.songCount,
      coverUrl: coverUrl,
      sourceId: sourceId,
      sourceListId: sourceListId,
      isDefault: isDefault,
      isMine: isMine,
      kind: kind,
    );
  }
}

class _FakeMusicRepository implements MusicRepository {
  _FakeMusicRepository({
    required this.playlists,
    required List<Song> favoriteSongs,
    Map<String, List<Song>>? playlistTracks,
  })  : _favoriteSongs = List.of(favoriteSongs),
        playlistTracks = playlistTracks ?? {};

  final List<MusicPlaylist> playlists;
  final List<String> removedSongs = [];
  final List<SearchCategory> collectedCatalogs = [];
  final List<String> uncollectedListIds = [];
  final List<Song> _favoriteSongs;
  final Map<String, List<Song>> playlistTracks;
  int playlistRequests = 0;

  @override
  Future<List<MusicPlaylist>> getUserPlaylists() async {
    playlistRequests++;
    return List.unmodifiable(playlists);
  }

  @override
  Future<List<Song>> getPlaylistSongs(MusicPlaylist playlist) async {
    if (playlist.kind == MusicPlaylistKind.favoriteSongs) {
      return List.unmodifiable(_favoriteSongs);
    }
    if (playlistTracks.containsKey(playlist.id)) {
      return List.unmodifiable(playlistTracks[playlist.id]!);
    }
    if (playlistTracks.containsKey(playlist.listId)) {
      return List.unmodifiable(playlistTracks[playlist.listId]!);
    }
    return const [];
  }

  @override
  Future<void> removeSongFromPlaylist(MusicPlaylist playlist, Song song) async {
    removedSongs.add(song.id);
    _favoriteSongs.removeWhere((item) => item.id == song.id);
  }

  @override
  Future<void> addSongToPlaylist(MusicPlaylist playlist, Song song) async {
    _favoriteSongs.add(song);
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
  Future<List<Song>> getCatalogSongs(SearchCatalogItem item) async => const [];

  @override
  Future<List<Song>> getCloudSongs() async => const [];

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
}
