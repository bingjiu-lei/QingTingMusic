import '../models/song.dart';
import '../models/lyric.dart';
import '../models/search_catalog_item.dart';
import '../models/music_playlist.dart';

abstract interface class MusicRepository {
  Future<List<Song>> getHotSongs();

  Future<List<Song>> getNewSongs();

  Future<List<Song>> getDailyRecommendations();

  Future<List<Song>> getPersonalFmSongs({
    String action = 'play',
    Song? contextSong,
    int playtimeSeconds = 0,
    bool isOverplay = false,
    String mode = 'normal',
    int songPoolId = 0,
    int remainSongCount = 0,
  });

  Future<List<String>> searchSuggestions(String keyword);

  Future<List<Song>> searchSongs(String keyword);

  Future<List<SearchCatalogItem>> searchCatalog(
    String keyword,
    SearchCategory category,
  );

  Future<List<Song>> getCatalogSongs(SearchCatalogItem item);

  Future<List<SearchCatalogItem>> getArtistAlbums(SearchCatalogItem artist);

  Future<List<SearchCatalogItem>> getArtistAlbumsPage(
    SearchCatalogItem artist, {
    required int page,
    int pageSize = 50,
  });

  Future<List<MusicPlaylist>> getUserPlaylists();

  Future<List<Song>> getPlaylistSongs(MusicPlaylist playlist);

  Future<List<Song>> getCloudSongs();

  Future<List<SearchCatalogItem>> getFollowedArtists();

  Future<void> collectCatalog(SearchCatalogItem item);

  Future<void> uncollectCatalog(SearchCatalogItem item);

  Future<void> addSongToPlaylist(MusicPlaylist playlist, Song song);

  Future<void> removeSongFromPlaylist(MusicPlaylist playlist, Song song);

  Future<Song> resolvePlayback(Song song);

  Future<List<LyricLine>> getLyrics(Song song);
}
