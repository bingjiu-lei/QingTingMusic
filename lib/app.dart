import 'package:flutter/material.dart';

import 'controllers/theme_controller.dart';
import 'pages/music_shell.dart';
import 'theme/app_theme.dart';

class QingTingMusicApp extends StatefulWidget {
  const QingTingMusicApp({
    super.key,
    this.enableAudio = true,
    this.enableWindowControls = true,
    this.useDemoData = false,
  });

  final bool enableAudio;
  final bool enableWindowControls;
  final bool useDemoData;

  @override
  State<QingTingMusicApp> createState() => _QingTingMusicAppState();
}

class _QingTingMusicAppState extends State<QingTingMusicApp> {
  late final ThemeController themeController;

  @override
  void initState() {
    super.initState();
    themeController = ThemeController()..initialize();
  }

  @override
  void dispose() {
    themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        title: 'QingTingMusic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeController.isDark ? ThemeMode.dark : ThemeMode.light,
        themeAnimationDuration: const Duration(milliseconds: 260),
        home: MusicShell(
          enableAudio: widget.enableAudio,
          enableWindowControls: widget.enableWindowControls,
          useDemoData: widget.useDemoData,
          themeController: themeController,
        ),
      ),
    );
  }
}
