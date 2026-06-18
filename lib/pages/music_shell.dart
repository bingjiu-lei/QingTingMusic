import 'package:flutter/material.dart';

import '../controllers/music_search_controller.dart';
import '../controllers/player_controller.dart';
import '../data/demo_music_repository.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/search_history_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_window_caption.dart';
import '../widgets/player_bar.dart';
import '../widgets/sidebar.dart';
import 'library_page.dart';
import 'search_page.dart';
import 'settings_page.dart';

class MusicShell extends StatefulWidget {
  const MusicShell({
    super.key,
    required this.enableAudio,
    required this.enableWindowControls,
  });

  final bool enableAudio;
  final bool enableWindowControls;

  @override
  State<MusicShell> createState() => _MusicShellState();
}

class _MusicShellState extends State<MusicShell> {
  final repository = DemoMusicRepository();
  late final PlayerController playerController;
  late final MusicSearchController searchController;

  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    playerController = PlayerController(
      audioService: AudioPlayerService(enabled: widget.enableAudio),
    )..addListener(_refresh);
    searchController = MusicSearchController(
      repository: repository,
      historyService: SearchHistoryService(),
    )..addListener(_refresh);
    searchController.initialize();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _playSong(Song song) async {
    if (playerController.currentSong?.id == song.id &&
        playerController.isPlaying) {
      await playerController.togglePlay();
      return;
    }
    await playerController.playSong(song, fromQueue: DemoMusicRepository.songs);
  }

  @override
  void dispose() {
    playerController
      ..removeListener(_refresh)
      ..dispose();
    searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compactSidebar = constraints.maxWidth < 1050;
          return Column(
            children: [
              AppWindowCaption(enabled: widget.enableWindowControls),
              Expanded(
                child: Row(
                  children: [
                    AppSidebar(
                      compact: compactSidebar,
                      selectedIndex: selectedIndex,
                      onChanged: (index) {
                        setState(() => selectedIndex = index);
                      },
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: ColoredBox(
                        color: AppColors.page,
                        child: _selectedPage(),
                      ),
                    ),
                  ],
                ),
              ),
              PlayerBar(controller: playerController),
            ],
          );
        },
      ),
    );
  }

  Widget _selectedPage() {
    return switch (selectedIndex) {
      0 => LibraryPage(
        allSongs: DemoMusicRepository.songs,
        recentSongs: playerController.recentSongs,
        currentSong: playerController.currentSong,
        isPlaying: playerController.isPlaying,
        onPlay: _playSong,
      ),
      1 => SearchPage(
        controller: searchController,
        currentSong: playerController.currentSong,
        isPlaying: playerController.isPlaying,
        onPlay: _playSong,
      ),
      _ => const SettingsPage(),
    };
  }
}
