import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/controllers/music_library_controller.dart';
import 'package:qing_ting_music/controllers/player_controller.dart';
import 'package:qing_ting_music/data/demo_music_repository.dart';
import 'package:qing_ting_music/models/music_playlist.dart';
import 'package:qing_ting_music/models/song.dart';
import 'package:qing_ting_music/services/audio_player_service.dart';
import 'package:qing_ting_music/services/kugou_api_client.dart';
import 'package:qing_ting_music/services/playback_state_service.dart';

void main() {
  test('automatically advances when playback completes', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(audioService: audio);
    final songs = [_song('one'), _song('two')];

    await controller.playSong(songs.first, fromQueue: songs);
    await Future<void>.delayed(const Duration(milliseconds: 750));
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

  test('advances on completion when metadata duration is zero', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(audioService: audio);
    final songs = [
      _song('unknown-duration').copyWith(duration: Duration.zero),
      _song('next'),
    ];

    await controller.playSong(songs.first, fromQueue: songs);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    audio.complete();
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(controller.currentSong?.id, 'next');
    expect(audio.opened.map((song) => song.id), ['unknown-duration', 'next']);

    controller.dispose();
  });

  test('automatic advance skips an unplayable queue item', () async {
    final audio = _FakeAudioPlayerService();
    final songs = [_song('one'), _song('blocked'), _song('three')];
    final controller = PlayerController(
      audioService: audio,
      resolveSong: (song) async {
        if (song.id == 'blocked') {
          throw const KugouApiException('该歌曲无版权或需付费');
        }
        return song;
      },
    );

    await controller.playSong(songs.first, fromQueue: songs);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    audio.complete();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(controller.currentSong?.id, 'three');
    expect(audio.opened.map((song) => song.id), ['one', 'three']);

    controller.dispose();
  });

  test('seeking after completion reopens and resumes the song', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(audioService: audio);
    final song = _song('one');

    await controller.playSong(song);
    audio.markCompleted();
    await controller.seek(const Duration(minutes: 1));

    expect(audio.opened.map((item) => item.id), ['one', 'one']);
    expect(audio.seekRequests, contains(const Duration(minutes: 1)));

    controller.dispose();
  });

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
    await Future<void>.delayed(const Duration(milliseconds: 750));
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
    await Future<void>.delayed(const Duration(milliseconds: 750));
    audio.finish(songs.first.duration);
    audio.complete();
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(controller.playbackMode, PlaybackMode.repeatOne);
    expect(controller.currentSong?.id, 'one');
    expect(audio.opened.map((song) => song.id), ['one', 'one']);

    controller.dispose();
  });

  test('shuffle playback returns along the actual listening path', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(audioService: audio);
    final songs = [_song('one'), _song('two'), _song('three')];

    controller
      ..cyclePlaybackMode()
      ..cyclePlaybackMode()
      ..cyclePlaybackMode();
    await controller.playSong(songs.first, fromQueue: songs);
    await controller.playNext();
    final secondId = controller.currentSong!.id;
    await controller.playNext();
    final thirdId = controller.currentSong!.id;

    expect(controller.playbackMode, PlaybackMode.shuffle);
    expect(secondId, isNot('one'));
    expect(thirdId, isNot(secondId));

    await controller.playPrevious();
    expect(controller.currentSong?.id, secondId);
    await controller.playPrevious();
    expect(controller.currentSong?.id, 'one');
    await controller.playNext();
    expect(controller.currentSong?.id, secondId);

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
    'ignores a stale completion event even when stale position is at the end',
    () async {
      final audio = _FakeAudioPlayerService();
      final controller = PlayerController(audioService: audio);
      final songs = [_song('one'), _song('two'), _song('three')];

      await controller.playSong(songs[1], fromQueue: songs);
      audio.finish(songs[1].duration);
      audio.complete();
      await Future<void>.delayed(const Duration(milliseconds: 180));

      expect(controller.currentSong?.id, 'two');
      expect(audio.opened.map((song) => song.id), ['two']);

      controller.dispose();
    },
  );

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

  test('saves playback state while position keeps changing', () async {
    final audio = _FakeAudioPlayerService();
    final state = _FakePlaybackStateService();
    final controller = PlayerController(
      audioService: audio,
      playbackStateService: state,
    );

    await controller.playSong(_song('one'));
    audio.seekTo(const Duration(seconds: 10));
    audio.seekTo(const Duration(seconds: 11));
    audio.seekTo(const Duration(seconds: 12));
    await Future<void>.delayed(const Duration(milliseconds: 2300));

    expect(state.saved, isNotEmpty);
    expect(state.saved.last.currentSong?.id, 'one');
    expect(state.saved.last.position, const Duration(seconds: 12));

    controller.dispose();
  });

  test('position ticks update progress without notifying listeners', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(audioService: audio);

    await controller.playSong(_song('one'));
    await Future<void>.delayed(Duration.zero);
    var notifications = 0;
    controller.addListener(() => notifications++);
    audio.seekTo(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);

    expect(controller.position, const Duration(seconds: 5));
    expect(controller.progress.value.position, const Duration(seconds: 5));
    expect(notifications, 0);

    controller.dispose();
  });

  test('clamps playback speed and reapplies it after opening a song', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(audioService: audio);

    await controller.setPlaybackSpeed(3.0);
    expect(controller.playbackSpeed, 2.0);
    await controller.setPlaybackSpeed(0.1);
    expect(controller.playbackSpeed, 0.5);
    expect(audio.speedRequests, [2.0, 0.5]);

    await controller.playSong(_song('one'));
    expect(audio.speedRequests, [2.0, 0.5, 0.5]);

    controller.dispose();
  });

  test('does not record a song into recents when opening fails', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(audioService: audio);

    await controller.playSong(_song('one'));
    audio.openError = const KugouApiException('该歌曲无版权或需付费');
    final played = await controller.playSong(_song('blocked'));

    expect(played, isFalse);
    expect(controller.recentSongs.map((song) => song.id), ['one']);

    controller.dispose();
  });

  test('hides technical playback notices by default', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(audioService: audio);

    audio.showTechnicalNotice('已使用本地缓存');
    await Future<void>.delayed(Duration.zero);

    expect(controller.playbackNotice, isNull);

    controller.dispose();
  });

  test('shows technical playback notices in developer mode', () async {
    final audio = _FakeAudioPlayerService();
    final controller = PlayerController(
      audioService: audio,
      showTechnicalPlaybackNotices: true,
    );

    audio.showTechnicalNotice('已使用本地缓存');
    await Future<void>.delayed(Duration.zero);

    expect(controller.playbackNotice, '已使用本地缓存');

    controller.dispose();
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

MusicPlaylist _playlist(
  String id, {
  MusicPlaylistKind kind = MusicPlaylistKind.createdPlaylist,
}) => MusicPlaylist(id: id, listId: id, name: id, songCount: 1, kind: kind);

class _FakeAudioPlayerService extends AudioPlayerService {
  _FakeAudioPlayerService() : super(enabled: false);

  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _technicalNotices = StreamController<String>.broadcast();
  final List<Song> opened = [];
  final List<Duration> seekRequests = [];
  final List<double> speedRequests = [];
  Object? openError;
  bool _completedState = false;

  @override
  bool get isEnabled => true;

  @override
  bool get isCompleted => _completedState;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<void> get completedStream => _completed.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<String> get technicalNoticeStream => _technicalNotices.stream;

  @override
  Future<void> open(Song song) async {
    final error = openError;
    if (error != null) {
      openError = null;
      throw error;
    }
    _completedState = false;
    opened.add(song);
    _playing.add(true);
  }

  @override
  Future<void> setSpeed(double speed) async {
    speedRequests.add(speed);
  }

  void complete() {
    _completedState = true;
    _playing.add(false);
    _completed.add(null);
  }

  void markCompleted() {
    _completedState = true;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seekRequests.add(position);
    _position.add(position);
  }

  void finish(Duration duration) => _position.add(duration);

  void seekTo(Duration position) => _position.add(position);

  void showTechnicalNotice(String message) => _technicalNotices.add(message);

  @override
  Future<void> dispose() async {
    await _playing.close();
    await _completed.close();
    await _position.close();
    await _technicalNotices.close();
    await super.dispose();
  }
}

class _FakePlaybackStateService extends PlaybackStateService {
  final saved = <PlaybackSnapshot>[];

  @override
  Future<PlaybackSnapshot?> load() async => null;

  @override
  Future<void> save(PlaybackSnapshot snapshot) async {
    saved.add(snapshot);
  }

  @override
  Future<void> clear() async {}
}
