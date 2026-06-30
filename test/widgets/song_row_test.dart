import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/models/song.dart';
import 'package:qing_ting_music/widgets/song_row.dart';

void main() {
  testWidgets('uses visible artist names instead of separator-only text', (
    tester,
  ) async {
    final song = Song(
      id: 'song-1',
      title: '祝福你',
      artist: ' / / / ',
      album: '新年歌',
      audioUrl: 'https://example.com/song.mp3',
      duration: const Duration(minutes: 3, seconds: 16),
      artists: const [SongArtist(name: '甄妮', id: 1001)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongRow(song: song, index: 0, onPlay: () {}),
        ),
      ),
    );

    expect(find.text('甄妮'), findsOneWidget);
    expect(find.text(' / / / '), findsNothing);
  });

  testWidgets('falls back to group artist label for separator-only artists', (
    tester,
  ) async {
    final song = Song(
      id: 'song-2',
      title: '祝福你',
      artist: ' / / / ',
      album: '新年歌',
      audioUrl: 'https://example.com/song.mp3',
      duration: const Duration(minutes: 3, seconds: 16),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongRow(song: song, index: 0, onPlay: () {}),
        ),
      ),
    );

    expect(find.text('群星'), findsOneWidget);
    expect(find.text(' / / / '), findsNothing);
  });

  testWidgets('does not render clickable separator artists with ids', (
    tester,
  ) async {
    var openedArtist = false;
    final song = Song(
      id: 'song-3',
      title: '祝福你',
      artist: ' / / / ',
      album: '新年歌',
      audioUrl: 'https://example.com/song.mp3',
      duration: const Duration(minutes: 3, seconds: 16),
      artists: const [
        SongArtist(name: '/', id: 1001),
        SongArtist(name: '/', id: 1002),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongRow(
            song: song,
            index: 0,
            onPlay: () {},
            onArtist: () => openedArtist = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('群星'));
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('群星'), findsOneWidget);
    expect(find.text('/'), findsNothing);
    expect(openedArtist, isFalse);
  });

  testWidgets('keeps long multi-artist names visible instead of slash only', (
    tester,
  ) async {
    final song = Song(
      id: 'song-4',
      title: '祝福你',
      artist:
          '林子祥 / 叶蒨文 / 刘德华 / 何婉盈 / 曾航生 / 蔡立儿 / 张卫健 / 吕方 / 杜德伟 / 刘锡明 / 钟镇涛 / 太极乐队',
      album: 'Warner Chinese New Year Compilation',
      audioUrl: 'https://example.com/song.mp3',
      duration: const Duration(minutes: 3, seconds: 16),
      artists: const [
        SongArtist(name: '林子祥'),
        SongArtist(name: '叶蒨文'),
        SongArtist(name: '刘德华'),
        SongArtist(name: '何婉盈'),
        SongArtist(name: '曾航生'),
        SongArtist(name: '蔡立儿'),
        SongArtist(name: '张卫健'),
        SongArtist(name: '吕方'),
        SongArtist(name: '杜德伟'),
        SongArtist(name: '刘锡明'),
        SongArtist(name: '钟镇涛'),
        SongArtist(name: '太极乐队'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 760,
          child: Scaffold(
            body: SongRow(
              song: song,
              index: 0,
              onPlay: () {},
              onArtistLink: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('林子祥'), findsOneWidget);
    expect(find.text('叶蒨文'), findsOneWidget);
    expect(find.text('刘德华'), findsOneWidget);
  });

  testWidgets('opens the clicked artist in a multi-artist line', (
    tester,
  ) async {
    String? openedArtist;
    final song = Song(
      id: 'song-5',
      title: '祝福你',
      artist: '林子祥 / 叶蒨文',
      album: 'Warner Chinese New Year Compilation',
      audioUrl: 'https://example.com/song.mp3',
      duration: const Duration(minutes: 3, seconds: 16),
      artists: const [
        SongArtist(name: '林子祥'),
        SongArtist(name: '叶蒨文'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 760,
          child: Scaffold(
            body: SongRow(
              song: song,
              index: 0,
              onPlay: () {},
              onArtistLink: (artist) => openedArtist = artist.name,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('叶蒨文'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(openedArtist, '叶蒨文');
  });
}
