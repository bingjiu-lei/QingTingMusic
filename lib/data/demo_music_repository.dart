import '../models/song.dart';
import '../models/lyric.dart';
import '../models/search_catalog_item.dart';
import '../models/music_playlist.dart';
import 'music_repository.dart';
import '../models/artist_directory.dart';
import '../models/rank_chart_item.dart';

class DemoMusicRepository implements MusicRepository {
  @override
  Future<ArtistDirectory> getArtistDirectory({
    int type = 0,
    int sexType = 0,
  }) async => const ArtistDirectory([]);

  @override
  Future<List<RankChartItem>> getAllRanks() async => const [
    RankChartItem(
      rankId: 8888,
      rankName: 'TOP500',
      coverUrl: '',
      topSongs: [
        '1. 少年锦时 - 赵雷',
        '2. Imagine - John Lennon',
        '3. 故乡 - 叶启田',
        '4. 晴天 - 周杰伦',
      ],
      groupName: '官方榜',
    ),
    RankChartItem(
      rankId: 6666,
      rankName: '飙升榜',
      coverUrl: '',
      topSongs: [
        '1. 晴天 - 周杰伦',
        '2. 起风了 - 买辣椒也用券',
        '3. 蓝莲花 - 许巍',
        '4. 少年锦时 - 赵雷',
      ],
      groupName: '官方榜',
    ),
    RankChartItem(
      rankId: 31308,
      rankName: '新歌榜',
      coverUrl: '',
      topSongs: [
        '1. 新歌一 - 歌手A',
        '2. 新歌二 - 歌手B',
        '3. 新歌三 - 歌手C',
        '4. 新歌四 - 歌手D',
      ],
      groupName: '官方榜',
    ),
    RankChartItem(
      rankId: 24971,
      rankName: '民谣榜',
      coverUrl: '',
      topSongs: ['1. 南山南 - 马頔', '2. 安和桥 - 宋冬野', '3. 成都 - 赵雷', '4. 理想三旬 - 陈鸿宇'],
      groupName: '特色榜',
    ),
    RankChartItem(
      rankId: 4681,
      rankName: '欧美金曲榜',
      coverUrl: '',
      topSongs: [
        '1. Shape of You - Ed Sheeran',
        '2. Rolling in the Deep - Adele',
        '3. Blank Space - Taylor Swift',
        '4. Closer - The Chainsmokers',
      ],
      groupName: '全球榜',
    ),
  ];

  @override
  Future<List<RankChartItem>> getFeaturedRanks() async => getAllRanks();

  @override
  Future<List<Song>> getRankSongs(int rankId, {int pageSize = 50}) async =>
      songs;
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
  Future<List<Song>> getArtistMvs(
    SearchCatalogItem artist, {
    int page = 1,
    int pageSize = 30,
  }) async => const [];

  @override
  Future<List<Song>> getFavoriteMvs() async => const [];

  @override
  Future<void> collectMv(Song song) async {}

  @override
  Future<void> uncollectMv(Song song) async {}

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
