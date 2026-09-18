import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/controllers/music_library_controller.dart';
import 'package:qing_ting_music/controllers/music_search_controller.dart';
import 'package:qing_ting_music/controllers/player_controller.dart';
import 'package:qing_ting_music/data/demo_music_repository.dart';
import 'package:qing_ting_music/models/search_catalog_item.dart';
import 'package:qing_ting_music/models/song.dart';
import 'package:qing_ting_music/pages/collection_detail_page.dart';
import 'package:qing_ting_music/pages/library_page.dart';
import 'package:qing_ting_music/pages/search_page.dart';
import 'package:qing_ting_music/services/audio_player_service.dart';
import 'package:qing_ting_music/services/favorite_mv_service.dart';
import 'package:qing_ting_music/services/music_library_cache_service.dart';
import 'package:qing_ting_music/services/search_history_service.dart';

class _FakeAudioPlayer extends AudioPlayerService {
  _FakeAudioPlayer() : super(enabled: false);

  @override
  Future<void> open(Song song) async {}

  @override
  Future<void> pause() async {}
}

void _noop() {}
void _noopSong(Song _) {}
void _noopSongs(List<Song> _) {}
void _noopSongQueue(Song _, List<Song> queue) {}
void _noopCatalog(SearchCatalogItem _) {}
void _noopInt(int _) {}

void main() {
  testWidgets(
    'SearchPage hides MV category when enableMvFeature is false and shows it when true',
    (tester) async {
      final controller = MusicSearchController(
        repository: DemoMusicRepository(),
        historyService: SearchHistoryService(),
      );
      controller.hasSearched = true;

      // Test with enableMvFeature = false
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchPage(
              controller: controller,
              currentSong: null,
              isPlaying: false,
              onPlay: (song, queue) {},
              onPlayAll: (_) {},
              onLogin: () {},
              onOpenCatalog: (_) {},
              onLike: (_) {},
              onAddToPlaylist: (_) {},
              onOpenArtist: (_) {},
              onOpenAlbum: (_) {},
              enableMvFeature: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // With false: 单曲, 专辑, 歌手, 歌单 are visible, MV is NOT visible
      expect(find.text('单曲'), findsOneWidget);
      expect(find.text('歌单'), findsOneWidget);
      expect(find.text('专辑'), findsOneWidget);
      expect(find.text('歌手'), findsOneWidget);
      expect(find.text('MV'), findsNothing);

      // Test with enableMvFeature = true
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchPage(
              controller: controller,
              currentSong: null,
              isPlaying: false,
              onPlay: (song, queue) {},
              onPlayAll: (_) {},
              onLogin: () {},
              onOpenCatalog: (_) {},
              onLike: (_) {},
              onAddToPlaylist: (_) {},
              onOpenArtist: (_) {},
              onOpenAlbum: (_) {},
              enableMvFeature: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // With true: MV is visible
      expect(find.text('MV'), findsOneWidget);

      // Select MV category
      controller.selectCategory(SearchCategory.mv);
      await tester.pump();
      expect(controller.category, SearchCategory.mv);

      // Turn enableMvFeature back to false -> should switch category back to song
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchPage(
              controller: controller,
              currentSong: null,
              isPlaying: false,
              onPlay: (song, queue) {},
              onPlayAll: (_) {},
              onLogin: () {},
              onOpenCatalog: (_) {},
              onLike: (_) {},
              onAddToPlaylist: (_) {},
              onOpenArtist: (_) {},
              onOpenAlbum: (_) {},
              enableMvFeature: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(controller.category, SearchCategory.song);
    },
  );

  testWidgets(
    'LibraryPage hides MV tab when enableMvFeature is false and shows it when true',
    (tester) async {
      final libraryController = MusicLibraryController(
        DemoMusicRepository(),
        cacheService: MusicLibraryCacheService(),
        favoriteMvService: FavoriteMvService(),
      );

      // With enableMvFeature = false
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryPage(
              controller: libraryController,
              recentSongs: const [],
              currentSong: null,
              isPlaying: false,
              onPlay: (song, queue) {},
              onPlayAll: (_) {},
              onLike: (_) {},
              onAddToPlaylist: (_) {},
              onOpenArtist: (_) {},
              onOpenAlbum: (_) {},
              onOpenPlaylist: (_) {},
              onOpenCatalog: (_) {},
              onLogin: () {},
              onCreatePlaylist: () {},
              selectedTab: 0,
              onTabChanged: (_) {},
              enableMvFeature: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // MV tab should not exist
      expect(find.text('MV'), findsNothing);
      expect(find.text('歌曲'), findsOneWidget);
      expect(find.text('歌单'), findsOneWidget);
      expect(find.text('专辑'), findsOneWidget);
      expect(find.text('歌手'), findsOneWidget);
      expect(find.text('云盘'), findsOneWidget);
      expect(find.text('最近播放'), findsOneWidget);

      // With enableMvFeature = true
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryPage(
              controller: libraryController,
              recentSongs: const [],
              currentSong: null,
              isPlaying: false,
              onPlay: (song, queue) {},
              onPlayAll: (_) {},
              onLike: (_) {},
              onAddToPlaylist: (_) {},
              onOpenArtist: (_) {},
              onOpenAlbum: (_) {},
              onOpenPlaylist: (_) {},
              onOpenCatalog: (_) {},
              onLogin: () {},
              onCreatePlaylist: () {},
              selectedTab: 0,
              onTabChanged: (_) {},
              enableMvFeature: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // MV tab should now exist
      expect(find.text('MV'), findsOneWidget);
    },
  );

  test('CollectionDetailPage tabs list respects enableMvFeature', () {
    const artistPageWithoutMv = CollectionDetailPage(
      kind: CollectionDetailKind.artist,
      title: 'Artist',
      subtitle: '',
      imageUrl: null,
      songs: [],
      relatedItems: [],
      similarArtists: [],
      relatedItemsLoadingMore: false,
      relatedItemsCanLoadMore: false,
      isLoading: false,
      onBack: _noop,
      onPlay: _noopSongQueue,
      onPlayAll: _noopSongs,
      onLike: _noopSong,
      onAddToPlaylist: _noopSong,
      onOpenArtist: _noopSong,
      onOpenAlbum: _noopSong,
      onOpenCatalog: _noopCatalog,
      onLoadMoreRelatedItems: _noop,
      selectedTab: 0,
      onTabChanged: _noopInt,
      storageKeyPrefix: 'artist:test',
      isCollected: false,
      enableMvFeature: false,
    );
    expect(artistPageWithoutMv.tabs, ['歌曲', '专辑', '相似歌手']);

    const artistPageWithMv = CollectionDetailPage(
      kind: CollectionDetailKind.artist,
      title: 'Artist',
      subtitle: '',
      imageUrl: null,
      songs: [],
      relatedItems: [],
      similarArtists: [],
      relatedItemsLoadingMore: false,
      relatedItemsCanLoadMore: false,
      isLoading: false,
      onBack: _noop,
      onPlay: _noopSongQueue,
      onPlayAll: _noopSongs,
      onLike: _noopSong,
      onAddToPlaylist: _noopSong,
      onOpenArtist: _noopSong,
      onOpenAlbum: _noopSong,
      onOpenCatalog: _noopCatalog,
      onLoadMoreRelatedItems: _noop,
      selectedTab: 0,
      onTabChanged: _noopInt,
      storageKeyPrefix: 'artist:test',
      isCollected: false,
      enableMvFeature: true,
    );
    expect(artistPageWithMv.tabs, ['歌曲', '专辑', 'MV', '相似歌手']);
  });

  testWidgets(
    'CollectionDetailPage hides MV tab when enableMvFeature is false and resets tab if MV was selected',
    (tester) async {
      int activeTab = 2; // MV was active
      Widget buildPage(bool enableMv) => MaterialApp(
        home: Scaffold(
          body: CollectionDetailPage(
            kind: CollectionDetailKind.artist,
            title: '周杰伦',
            subtitle: '',
            imageUrl: null,
            songs: const [],
            relatedItems: const [],
            similarArtists: const [],
            relatedItemsLoadingMore: false,
            relatedItemsCanLoadMore: false,
            isLoading: false,
            selectedTab: activeTab,
            onTabChanged: (tab) => activeTab = tab,
            storageKeyPrefix: 'artist:test',
            isCollected: false,
            enableMvFeature: enableMv,
            onBack: () {},
            onPlay: (_, queue) {},
            onPlayAll: (_) {},
            onLike: (_) {},
            onAddToPlaylist: (_) {},
            onOpenArtist: (_) {},
            onOpenAlbum: (_) {},
            onOpenCatalog: (_) {},
            onLoadMoreRelatedItems: () {},
          ),
        ),
      );

      // Render with MV enabled:
      await tester.pumpWidget(buildPage(true));
      await tester.pump();
      expect(find.text('MV'), findsOneWidget);

      // Rebuild with MV disabled:
      await tester.pumpWidget(buildPage(false));
      await tester.pumpAndSettle();
      expect(find.text('MV'), findsNothing);
      expect(activeTab, 0);
    },
  );

  test(
    'PlayerController.removeMvSongsFromQueue cleans queue and switches current song if current is MV',
    () async {
      final audio = _FakeAudioPlayer();
      final controller = PlayerController(audioService: audio);
      const normalSong1 = Song(
        id: 'song1',
        title: 'Normal 1',
        artist: 'Artist',
        album: 'Album',
        duration: Duration(minutes: 3),
        audioUrl: 'https://example.com/1.mp3',
      );
      const mvSong = Song(
        id: 'mv1',
        title: 'MV 1',
        artist: 'Artist',
        album: 'Album',
        duration: Duration(minutes: 4),
        audioUrl: 'https://example.com/mv1.mp4',
        isMv: true,
      );
      const normalSong2 = Song(
        id: 'song2',
        title: 'Normal 2',
        artist: 'Artist',
        album: 'Album',
        duration: Duration(minutes: 3),
        audioUrl: 'https://example.com/2.mp3',
      );

      // Play MV song with queue containing normal and MV songs
      await controller.playSong(
        mvSong,
        fromQueue: [mvSong, normalSong1, normalSong2],
      );
      expect(controller.currentSong?.id, 'mv1');
      expect(controller.queue.length, 3);

      // Call removeMvSongsFromQueue
      await controller.removeMvSongsFromQueue();

      // MV song removed from queue, and current song switched to normalSong1
      expect(controller.queue.map((s) => s.id), ['song1', 'song2']);
      expect(controller.currentSong?.id, 'song1');

      controller.dispose();
    },
  );

  test(
    'PlayerController.removeMvSongsFromQueue stops playback when queue only has MV songs',
    () async {
      final audio = _FakeAudioPlayer();
      final controller = PlayerController(audioService: audio);
      const mvSong1 = Song(
        id: 'mv1',
        title: 'MV 1',
        artist: 'Artist',
        album: 'Album',
        duration: Duration(minutes: 4),
        audioUrl: 'https://example.com/mv1.mp4',
        isMv: true,
      );
      const mvSong2 = Song(
        id: 'mv2',
        title: 'MV 2',
        artist: 'Artist',
        album: 'Album',
        duration: Duration(minutes: 4),
        audioUrl: 'https://example.com/mv2.mp4',
        isMv: true,
      );

      await controller.playSong(mvSong1, fromQueue: [mvSong1, mvSong2]);
      expect(controller.currentSong?.id, 'mv1');
      expect(controller.queue.length, 2);

      await controller.removeMvSongsFromQueue();

      expect(controller.queue, isEmpty);
      expect(controller.currentSong, isNull);
      expect(controller.isPlaying, isFalse);

      controller.dispose();
    },
  );

  test(
    'PlayerController.removeMvSongsFromQueue does not interrupt non-MV song even if substituted from MV',
    () async {
      final audio = _FakeAudioPlayer();
      final controller = PlayerController(audioService: audio);
      const substitutedSong = Song(
        id: 'sub1',
        title: 'Substituted',
        artist: 'Artist',
        album: 'Album',
        duration: Duration(minutes: 3),
        audioUrl: 'https://example.com/sub.mp3',
        isMv: false,
        playbackNotice: '已切换MV音源',
      );
      const mvSong = Song(
        id: 'mv1',
        title: 'MV 1',
        artist: 'Artist',
        album: 'Album',
        duration: Duration(minutes: 4),
        audioUrl: 'https://example.com/mv1.mp4',
        isMv: true,
      );

      await controller.playSong(
        substitutedSong,
        fromQueue: [substitutedSong, mvSong],
      );
      expect(controller.currentSong?.id, 'sub1');
      expect(controller.queue.length, 2);

      await controller.removeMvSongsFromQueue();

      // Substituted song remains current and in queue; mvSong removed
      expect(controller.queue.map((s) => s.id), ['sub1']);
      expect(controller.currentSong?.id, 'sub1');

      controller.dispose();
    },
  );
}
