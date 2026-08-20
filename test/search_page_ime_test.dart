import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qing_ting_music/controllers/music_search_controller.dart';
import 'package:qing_ting_music/data/demo_music_repository.dart';
import 'package:qing_ting_music/pages/search_page.dart';
import 'package:qing_ting_music/services/search_history_service.dart';

void main() {
  testWidgets('defers search updates until an IME composition is committed', (
    tester,
  ) async {
    final controller = MusicSearchController(
      repository: DemoMusicRepository(),
      historyService: SearchHistoryService(),
    );

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
          ),
        ),
      ),
    );

    final input = tester.testTextInput;
    input.updateEditingValue(
      const TextEditingValue(
        text: 'gu',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    expect(controller.keyword, isEmpty);

    input.updateEditingValue(
      const TextEditingValue(
        text: '姑娘',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();
    expect(controller.keyword, '姑娘');

    // Drain the suggestion debounce started after the committed value.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
