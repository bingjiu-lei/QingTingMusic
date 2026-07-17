import '../models/song.dart';
import '../models/lyric.dart';
import '../models/search_catalog_item.dart';
import '../models/music_playlist.dart';
import '../services/kugou_api_client.dart';
import 'music_repository.dart';

class KugouMusicRepository implements MusicRepository {
  KugouMusicRepository(this.apiClient);

  final KugouApiClient apiClient;

  @override
  Future<List<Song>> getHotSongs() async => const [];

  @override
  Future<List<Song>> getNewSongs() async => const [];

  @override
  Future<List<Song>> getDailyRecommendations() {
    return apiClient.getDailyRecommendations();
  }

  @override
  Future<List<Song>> getPersonalFmSongs({
    String action = 'play',
    Song? contextSong,
    int playtimeSeconds = 0,
    bool isOverplay = false,
    String mode = 'normal',
    int songPoolId = 0,
    int remainSongCount = 0,
  }) {
    return apiClient.getPersonalFmSongs(
      action: action,
      contextSong: contextSong,
      playtimeSeconds: playtimeSeconds,
      isOverplay: isOverplay,
      mode: mode,
      songPoolId: songPoolId,
      remainSongCount: remainSongCount,
    );
  }

  @override
  Future<List<String>> searchSuggestions(String keyword) {
    return apiClient.searchSuggestions(keyword);
  }

  @override
  Future<List<Song>> searchSongs(String keyword) {
    return apiClient.searchSongs(keyword);
  }

  @override
  Future<List<SearchCatalogItem>> searchCatalog(
    String keyword,
    SearchCategory category,
  ) {
    return apiClient.searchCatalog(keyword, category);
  }

  @override
  Future<List<Song>> getCatalogSongs(SearchCatalogItem item) {
    return apiClient.getCatalogSongs(item);
  }

  @override
  Future<List<SearchCatalogItem>> getArtistAlbums(SearchCatalogItem artist) {
    return apiClient.getArtistAlbums(artist);
  }

  @override
  Future<List<SearchCatalogItem>> getArtistAlbumsPage(
    SearchCatalogItem artist, {
    required int page,
    int pageSize = 50,
  }) {
    return apiClient.getArtistAlbumsPage(
      artist,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<MusicPlaylist>> getUserPlaylists() {
    return apiClient.getUserPlaylists();
  }

  @override
  Future<List<Song>> getPlaylistSongs(MusicPlaylist playlist) {
    return apiClient.getPlaylistSongs(playlist);
  }

  @override
  Future<List<Song>> getCloudSongs() {
    return apiClient.getCloudSongs();
  }

  @override
  Future<List<SearchCatalogItem>> getFollowedArtists() {
    return apiClient.getFollowedArtists();
  }

  @override
  Future<void> collectCatalog(SearchCatalogItem item) {
    return apiClient.collectCatalog(item);
  }

  @override
  Future<void> uncollectCatalog(SearchCatalogItem item) {
    return apiClient.uncollectCatalog(item);
  }

  @override
  Future<void> addSongToPlaylist(MusicPlaylist playlist, Song song) {
    return apiClient.addSongToPlaylist(playlist, song);
  }

  @override
  Future<void> removeSongFromPlaylist(MusicPlaylist playlist, Song song) {
    return apiClient.removeSongFromPlaylist(playlist, song);
  }

  @override
  Future<Song> resolvePlayback(Song song) {
    return apiClient.resolvePlayback(song);
  }

  @override
  Future<List<LyricLine>> getLyrics(Song song) {
    return apiClient.getLyrics(song);
  }

  @override
  Future<List<String>> getArtistPortraits(Song song) {
    return apiClient.getArtistPortraits(song);
  }
}
