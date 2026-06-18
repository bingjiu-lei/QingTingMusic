import '../models/song.dart';
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
  Future<List<Song>> searchSongs(String keyword) async {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return const [];

    return songs.where((song) {
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query) ||
          song.album.toLowerCase().contains(query);
    }).toList();
  }
}
