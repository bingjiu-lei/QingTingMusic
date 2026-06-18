import '../models/song.dart';

abstract interface class MusicRepository {
  Future<List<Song>> getHotSongs();

  Future<List<Song>> getNewSongs();

  Future<List<Song>> searchSongs(String keyword);
}
