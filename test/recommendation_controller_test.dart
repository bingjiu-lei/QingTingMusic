import 'package:flutter_test/flutter_test.dart';

import 'package:qing_ting_music/controllers/recommendation_controller.dart';
import 'package:qing_ting_music/data/demo_music_repository.dart';
import 'package:qing_ting_music/models/song.dart';

void main() {
  test(
    'dislike FM reports garbage and merges newly recommended songs',
    () async {
      final current = _song('current');
      final queued = _song('queued');
      final fetched = _song('fetched');
      final repository = _RecordingFmRepository([fetched]);
      final controller = RecommendationController(repository)
        ..fmSongs = [current, queued];

      final next = await controller.dislikeFm(current, playtimeSeconds: 42);

      expect(next?.id, queued.id);
      expect(controller.fmSongs.map((song) => song.id), [
        queued.id,
        fetched.id,
      ]);
      expect(repository.requests, hasLength(1));
      expect(repository.requests.single.action, 'garbage');
      expect(repository.requests.single.contextSong?.id, current.id);
      expect(repository.requests.single.playtimeSeconds, 42);
      expect(repository.requests.single.remainSongCount, 1);
    },
  );
}

Song _song(String id) => Song(
  id: id,
  title: id,
  artist: 'artist',
  album: 'album',
  duration: const Duration(minutes: 3),
  audioUrl: '',
);

class _RecordingFmRepository extends DemoMusicRepository {
  _RecordingFmRepository(this.response);

  final List<Song> response;
  final requests =
      <
        ({
          String action,
          Song? contextSong,
          int playtimeSeconds,
          int remainSongCount,
        })
      >[];

  @override
  Future<List<Song>> getPersonalFmSongs({
    String action = 'play',
    Song? contextSong,
    int playtimeSeconds = 0,
    bool isOverplay = false,
    String mode = 'normal',
    int songPoolId = 0,
    int remainSongCount = 0,
  }) async {
    requests.add((
      action: action,
      contextSong: contextSong,
      playtimeSeconds: playtimeSeconds,
      remainSongCount: remainSongCount,
    ));
    return response;
  }
}
