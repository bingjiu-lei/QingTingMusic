import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:win32/win32.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/app_preferences_service.dart';
import 'services/app_storage_service.dart';
import 'services/single_instance_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.title = '晴听音乐';
  JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
  await AppStorageService.initialize();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    final singleInstance = SingleInstanceService(
      onShowRequested: _showMainWindow,
    );
    final shouldStart = await singleInstance.start();
    if (!shouldStart) {
      exit(0);
    }
    final preferences = AppPreferencesService();
    final windowState = await preferences.readWindowState();

    final options = WindowOptions(
      size: Size(windowState.width, windowState.height),
      minimumSize: const Size(
        WindowStateSnapshot.minWidth,
        WindowStateSnapshot.minHeight,
      ),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (windowState.isMaximized ||
          _shouldDefaultMaximizeOnTouch(preferences)) {
        await windowManager.maximize();
      }
    });
  }

  runApp(const QingTingMusicApp());
}

bool _shouldDefaultMaximizeOnTouch(AppPreferencesService preferences) {
  if (!Platform.isWindows) return false;
  try {
    // SM_MAXIMUMTOUCHES = 95. 返回设备最大触控点数，> 0 说明具备触屏输入能力
    final maxTouches = GetSystemMetrics(SM_MAXIMUMTOUCHES);
    if (maxTouches <= 0) return false;
    // 如果用户从未显式保存过最大化/窗口化状态，触控设备初次启动智能优先最大化
    final raw = preferences.readRawMaximizedSync();
    return raw == null;
  } catch (_) {
    return false;
  }
}

Future<void> _showMainWindow() async {
  if (await windowManager.isMinimized()) {
    await windowManager.restore();
  }
  if (!await windowManager.isVisible()) {
    await windowManager.show();
  }
  await windowManager.focus();
}
