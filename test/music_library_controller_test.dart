import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/controllers/music_library_controller.dart';
import 'package:qing_ting_music/data/music_repository.dart';
import 'package:qing_ting_music/models/music_playlist.dart';
import 'package:qing_ting_music/models/search_catalog_item.dart';
import 'package:qing_ting_music/models/song.dart';

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

class _FakeMusicRepository implements MusicRepository {
  _FakeMusicRepository({
    required this.playlists,
    required List<Song> favoriteSongs,
  }) : _favoriteSongs = List.of(favoriteSongs);

  final List<MusicPlaylist> playlists;
  final List<String> removedSongs = [];
  final List<Song> _favoriteSongs;

  @override
  Future<List<MusicPlaylist>> getUserPlaylists() async => playlists;

  @override
  Future<List<Song>> getPlaylistSongs(MusicPlaylist playlist) async {
    if (playlist.kind == MusicPlaylistKind.favoriteSongs) {
      return List.unmodifiable(_favoriteSongs);
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
  Future<List<SearchCatalogItem>> getArtistAlbums(
    SearchCatalogItem artist,
  ) async => const [];

  @override
  Future<List<Song>> getCatalogSongs(SearchCatalogItem item) async => const [];

  @override
  Future<List<Song>> getCloudSongs() async => const [];

  @override
  Future<List<SearchCatalogItem>> getFollowedArtists() async => const [];

  @override
  Future<List<Song>> getHotSongs() async => const [];

  @override
  Future<List<Song>> getNewSongs() async => const [];

  @override
  Future<Song> resolvePlayback(Song song) async => song;

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
