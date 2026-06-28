import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/controllers/music_library_controller.dart';
import 'package:qing_ting_music/controllers/player_controller.dart';
import 'package:qing_ting_music/data/demo_music_repository.dart';
import 'package:qing_ting_music/models/music_playlist.dart';
import 'package:qing_ting_music/models/song.dart';
import 'package:qing_ting_music/services/audio_player_service.dart';
import 'package:qing_ting_music/services/kugou_api_client.dart';

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

  test(
    'advances on completion even when final position is not emitted',
    () async {
      final audio = _FakeAudioPlayerService();
      final controller = PlayerController(audioService: audio);
      final songs = [_song('one'), _song('two')];

      await controller.playSong(songs.first, fromQueue: songs);
      await Future<void>.delayed(const Duration(milliseconds: 850));
      audio.complete();
      await Future<void>.delayed(const Duration(milliseconds: 180));

      expect(controller.currentSong?.id, 'two');
      expect(audio.opened.map((song) => song.id), ['one', 'two']);

      controller.dispose();
    },
  );

  test(
    'advances when playback stalls near the end without completion',
    () async {
      final audio = _FakeAudioPlayerService();
      final controller = PlayerController(audioService: audio);
      final songs = [_song('one'), _song('two')];

      await controller.playSong(songs.first, fromQueue: songs);
      await Future<void>.delayed(const Duration(milliseconds: 850));
      audio.seekTo(songs.first.duration - const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 1900));

      expect(controller.currentSong?.id, 'two');
      expect(audio.opened.map((song) => song.id), ['one', 'two']);

      controller.dispose();
    },
  );

  test('stops at the end in sequence mode', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(audioService: audio);
    final songs = [_song('one'), _song('two')];

    await controller.playSong(songs.last, fromQueue: songs);
    audio.finish(songs.last.duration);
    audio.complete();
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(controller.currentSong?.id, 'two');
    expect(controller.isPlaying, isFalse);
    expect(audio.opened.map((song) => song.id), ['two']);

    controller.dispose();
  });

  test('replays current song in repeat one mode', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(audioService: audio);
    final songs = [_song('one'), _song('two')];

    controller
      ..cyclePlaybackMode()
      ..cyclePlaybackMode();
    await controller.playSong(songs.first, fromQueue: songs);
    audio.finish(songs.first.duration);
    audio.complete();
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(controller.playbackMode, PlaybackMode.repeatOne);
    expect(controller.currentSong?.id, 'one');
    expect(audio.opened.map((song) => song.id), ['one', 'one']);

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

  test(
    'keeps the playing song visible when the next song cannot resolve',
    () async {
      final audio = _FakeAudioPlayerService();
      final songs = [_song('one'), _song('blocked')];
      final controller = PlayerController(
        audioService: audio,
        resolveSong: (song) async {
          if (song.id == 'blocked') {
            throw const KugouApiException('暂时无法获取这首歌的播放地址');
          }
          return song;
        },
      );

      await controller.playSong(songs.first, fromQueue: songs);
      audio.seekTo(const Duration(seconds: 42));
      await Future<void>.delayed(Duration.zero);
      await controller.playSong(songs.last, fromQueue: songs);

      expect(controller.currentSong?.id, 'one');
      expect(controller.isPlaying, isTrue);
      expect(controller.position, const Duration(seconds: 42));
      expect(controller.errorText, contains('blocked'));
      expect(audio.opened.map((song) => song.id), ['one']);

      controller.dispose();
    },
  );

  test('library collections are exposed newest first', () {
    final controller = MusicLibraryController(DemoMusicRepository())
      ..favorites = [_song('old'), _song('new')]
      ..playlists = [
        _playlist('created-old', kind: MusicPlaylistKind.createdPlaylist),
        _playlist('created-new', kind: MusicPlaylistKind.createdPlaylist),
        _playlist('collected-old', kind: MusicPlaylistKind.collectedPlaylist),
        _playlist('collected-new', kind: MusicPlaylistKind.collectedPlaylist),
      ]
      ..albums = [_playlist('old'), _playlist('new')]
      ..cloudSongs = [_song('old'), _song('new')];

    expect(controller.sortedFavorites.map((item) => item.id), ['new', 'old']);
    expect(controller.createdPlaylists.map((item) => item.id), [
      'created-new',
      'created-old',
    ]);
    expect(controller.collectedPlaylists.map((item) => item.id), [
      'collected-new',
      'collected-old',
    ]);
    expect(controller.sortedAlbums.map((item) => item.id), ['new', 'old']);
    expect(controller.sortedCloudSongs.map((item) => item.id), ['new', 'old']);
  });

  test(
    'shows a temporary notice when playback uses a cloud replacement',
    () async {
      final audio = _FakeAudioPlayerService();
      final controller = PlayerController(
        audioService: audio,
        resolveSong: (song) async => song.copyWith(playbackNotice: '已切换云盘版本'),
      );

      await controller.playSong(_song('cloud-match'));

      expect(controller.playbackNotice, '已切换云盘版本');
      expect(audio.opened.single.id, 'cloud-match');

      controller.dispose();
    },
  );
}

Song _song(String id) => Song(
  id: id,
  title: id,
  artist: 'artist',
  album: 'album',
  duration: const Duration(minutes: 3),
  audioUrl: 'https://example.com/$id.mp3',
);

MusicPlaylist _playlist(
  String id, {
  MusicPlaylistKind kind = MusicPlaylistKind.createdPlaylist,
}) => MusicPlaylist(id: id, listId: id, name: id, songCount: 1, kind: kind);

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

  void seekTo(Duration position) => _position.add(position);

  @override
  Future<void> dispose() async {
    await _playing.close();
    await _completed.close();
    await _position.close();
    await super.dispose();
  }
}
