import '../models/song.dart';
import '../models/lyric.dart';
import '../models/search_catalog_item.dart';
import '../models/music_playlist.dart';
import 'music_repository.dart';

class DemoMusicRepository implements MusicRepository {
  static const songs = [
    Song(
      id: 'zhao-lei-shao-nian-jin-shi',
      title: '少年锦时',
      artist: '赵雷',
      album: '无法长大',
      duration: Duration(minutes: 4, seconds: 43),
      audioUrl:
          'https://img.leiyun.blog/file/音乐/1779897120694_少年锦时-赵雷-5835274-320.mp3',
      liked: true,
    ),
    Song(
      id: 'john-lennon-imagine',
      title: 'Imagine',
      artist: 'John Lennon',
      album: 'Imagine (Remastered)',
      duration: Duration(minutes: 3, seconds: 8),
      audioUrl:
          'https://img.leiyun.blog/file/音乐/1779526283836_Imagine_Remastered_2010_-John_Lennon-939544-320.mp3',
    ),
    Song(
      id: 'ye-qi-tian-gu-xiang',
      title: '故乡',
      artist: '叶启田',
      album: '故乡',
      duration: Duration(minutes: 3, seconds: 54),
      audioUrl:
          'https://img.leiyun.blog/file/音乐/1779507615116_故乡-叶启田-41209169-320.mp3',
    ),
  ];

  @override
  Future<List<Song>> getHotSongs() async => songs;

  @override
  Future<List<Song>> getNewSongs() async => songs.reversed.toList();

  @override
  Future<List<Song>> getDailyRecommendations() async => songs;

  @override
  Future<List<Song>> getPersonalFmSongs({
    String action = 'play',
    Song? contextSong,
    int playtimeSeconds = 0,
    bool isOverplay = false,
    String mode = 'normal',
    int songPoolId = 0,
    int remainSongCount = 0,
  }) async => songs.reversed.toList();

  @override
  Future<List<String>> searchSuggestions(String keyword) async {
    final matches = await searchSongs(keyword);
    return matches.map((song) => song.title).toList();
  }

  @override
  Future<List<Song>> searchSongs(String keyword) async {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return const [];

    return songs.where((song) {
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query) ||
          song.album.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Future<List<SearchCatalogItem>> searchCatalog(
    String keyword,
    SearchCategory category,
  ) async {
    return const [];
  }

  @override
  Future<List<Song>> getCatalogSongs(SearchCatalogItem item) async => songs;

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
  Future<List<MusicPlaylist>> getUserPlaylists() async => const [
    MusicPlaylist(
      id: 'demo-favorites',
      listId: 'demo-favorites',
      name: '默认收藏',
      songCount: 1,
      isDefault: true,
      isMine: true,
      kind: MusicPlaylistKind.favoriteSongs,
    ),
  ];

  @override
  Future<List<Song>> getPlaylistSongs(MusicPlaylist playlist) async {
    return songs.where((song) => song.liked).toList();
  }

  @override
  Future<List<Song>> getCloudSongs() async => const [];

  @override
  Future<List<SearchCatalogItem>> getFollowedArtists() async => const [];

  @override
  Future<void> collectCatalog(SearchCatalogItem item) async {}

  @override
  Future<void> uncollectCatalog(SearchCatalogItem item) async {}

  @override
  Future<void> addSongToPlaylist(MusicPlaylist playlist, Song song) async {}

  @override
  Future<void> removeSongFromPlaylist(
    MusicPlaylist playlist,
    Song song,
  ) async {}

  @override
  Future<void> createPlaylist(String name, {bool isPrivate = false}) async {}

  @override
  Future<void> deletePlaylist(MusicPlaylist playlist) async {}

  @override
  Future<List<SongClimaxSegment>> getSongClimax(String hash) async => const [];

  @override
  Future<String?> getAlbumReleaseDate(String albumId) async => null;

  @override
  Future<Song> resolvePlayback(Song song) async => song;

  @override
  Future<List<LyricLine>> getLyrics(Song song) async => const [];

  @override
  Future<List<String>> getArtistPortraits(Song song) async => const [];
}
