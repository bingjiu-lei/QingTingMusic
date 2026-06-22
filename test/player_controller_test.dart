import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/controllers/music_library_controller.dart';
import 'package:qing_ting_music/controllers/player_controller.dart';
import 'package:qing_ting_music/data/demo_music_repository.dart';
import 'package:qing_ting_music/models/music_playlist.dart';
import 'package:qing_ting_music/models/song.dart';
import 'package:qing_ting_music/services/audio_player_service.dart';

void main() {
  test('automatically advances when playback completes', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(audioService: audio);
    final songs = [_song('one'), _song('two')];

    await controller.playSong(songs.first, fromQueue: songs);
    audio.finish(songs.first.duration);
    audio.complete();
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(controller.currentSong?.id, 'two');
    expect(audio.opened.map((song) => song.id), ['one', 'two']);

    controller.dispose();
  });

  test('ignores a stale completion event while a song is starting', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(audioService: audio);
    final songs = [_song('one'), _song('two')];

    await controller.playSong(songs.first, fromQueue: songs);
    audio.complete();
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(controller.currentSong?.id, 'one');
    expect(audio.opened.map((song) => song.id), ['one']);

    controller.dispose();
  });

  test('albums and cloud songs are exposed newest first', () {
    final controller = MusicLibraryController(DemoMusicRepository())
      ..albums = [_playlist('old'), _playlist('new')]
      ..cloudSongs = [_song('old'), _song('new')];

    expect(controller.sortedAlbums.map((item) => item.id), ['new', 'old']);
    expect(controller.sortedCloudSongs.map((item) => item.id), ['new', 'old']);
  });
}

Song _song(String id) => Song(
  id: id,
  title: id,
  artist: 'artist',
  album: 'album',
  duration: const Duration(minutes: 3),
  audioUrl: 'https://example.com/$id.mp3',
);

MusicPlaylist _playlist(String id) =>
    MusicPlaylist(id: id, listId: id, name: id, songCount: 1);

class _FakeAudioPlayerService extends AudioPlayerService {
  _FakeAudioPlayerService() : super(enabled: false);

  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final List<Song> opened = [];

  @override
  bool get isEnabled => true;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<void> get completedStream => _completed.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Future<void> open(Song song) async {
    opened.add(song);
    _playing.add(true);
  }

  void complete() => _completed.add(null);

  void finish(Duration duration) => _position.add(duration);

  @override
  Future<void> dispose() async {
    await _playing.close();
    await _completed.close();
    await _position.close();
    await super.dispose();
  }
}
