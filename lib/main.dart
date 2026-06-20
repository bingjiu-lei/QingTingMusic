import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/app_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStorageService.initialize();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1120, 700),
      minimumSize: Size(960, 640),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.unmaximize();
      await windowManager.setSize(const Size(1120, 700));
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const QingTingMusicApp());
}
