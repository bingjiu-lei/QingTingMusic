import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/models/music_playlist.dart';
import 'package:qing_ting_music/models/song.dart';
import 'package:qing_ting_music/widgets/add_to_playlist_dialog.dart';

void main() {
  final song = Song(
    id: 'song-1',
    title: 'Rewind',
    artist: 'Wonder Girls',
    album: 'REBOOT',
    audioUrl: 'https://example.com/song.mp3',
    duration: const Duration(minutes: 3, seconds: 30),
  );

  final playlistA = MusicPlaylist(
    id: 'p-1',
    listId: 'p-1',
    name: 'KPOP',
    songCount: 10,
    kind: MusicPlaylistKind.createdPlaylist,
  );

  final playlistB = MusicPlaylist(
    id: 'p-2',
    listId: 'p-2',
    name: '经典老歌',
    songCount: 5,
    kind: MusicPlaylistKind.createdPlaylist,
  );

  testWidgets('renders song info and playlists with dual toggle state', (
    tester,
  ) async {
    final removedPlaylists = <MusicPlaylist>[];
    final addedPlaylists = <MusicPlaylist>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddToPlaylistDialog(
            song: song,
            playlists: [playlistA, playlistB],
            containingPlaylistIds: const {'p-1'},
            onAddToPlaylist: (p) async => addedPlaylists.add(p),
            onRemoveFromPlaylist: (p) async => removedPlaylists.add(p),
          ),
        ),
      ),
    );

    expect(find.text('收藏与歌单管理'), findsOneWidget);
    expect(find.text('Rewind'), findsOneWidget);
    expect(find.text('Wonder Girls'), findsOneWidget);
    expect(find.text('KPOP'), findsOneWidget);
    expect(find.text('经典老歌'), findsOneWidget);
    expect(find.text('已收录'), findsOneWidget);
    expect(find.text('添加'), findsOneWidget);

    // Tapping already added playlist prompts confirmation dialog
    await tester.tap(find.text('KPOP'));
    await tester.pumpAndSettle();

    expect(find.text('移出歌单'), findsOneWidget);
    expect(find.text('确定要将《Rewind》从歌单「KPOP」中移出吗？'), findsOneWidget);

    // Cancel first
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(removedPlaylists, isEmpty);
    expect(find.text('已收录'), findsOneWidget);

    // Tap again and confirm
    await tester.tap(find.text('KPOP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认移出'));
    await tester.pumpAndSettle();

    expect(removedPlaylists, [playlistA]);
    expect(find.text('已收录'), findsNothing);

    await tester.tap(find.text('经典老歌'));
    await tester.pumpAndSettle();

    expect(addedPlaylists, [playlistB]);
    expect(find.text('已收录'), findsOneWidget);
  });

  testWidgets(
    'displays quick skip banner when playing from contained playlist and requires confirmation',
    (tester) async {
      MusicPlaylist? skippedPlaylist;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddToPlaylistDialog(
              song: song,
              playlists: [playlistA, playlistB],
              containingPlaylistIds: const {'p-1'},
              currentPlayingPlaylist: playlistA,
              isCurrentPlayingSong: true,
              onRemoveAndSkipCurrent: (p) async => skippedPlaylist = p,
            ),
          ),
        ),
      );

      expect(find.text('正在播放「KPOP」'), findsOneWidget);
      expect(find.text('从当前歌单移除并切歌'), findsOneWidget);

      await tester.tap(find.text('从当前歌单移除并切歌'));
      await tester.pumpAndSettle();

      expect(
        find.text('从当前歌单移除并切歌'),
        findsNWidgets(2),
      ); // banner & dialog title
      expect(
        find.text('确定要将《Rewind》从正在播放的歌单「KPOP」中移除，并自动切入下一首吗？'),
        findsOneWidget,
      );

      // Confirm removal
      await tester.tap(find.text('确认移除'));
      await tester.pumpAndSettle();

      expect(skippedPlaylist, playlistA);
    },
  );
}
