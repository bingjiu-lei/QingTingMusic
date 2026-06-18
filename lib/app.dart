import 'package:flutter/material.dart';

import 'pages/music_shell.dart';
import 'theme/app_theme.dart';

class QingTingMusicApp extends StatelessWidget {
  const QingTingMusicApp({
    super.key,
    this.enableAudio = true,
    this.enableWindowControls = true,
  });

  final bool enableAudio;
  final bool enableWindowControls;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QingTingMusic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: MusicShell(
        enableAudio: enableAudio,
        enableWindowControls: enableWindowControls,
      ),
    );
  }
}
