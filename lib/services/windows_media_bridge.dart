import 'dart:io';

import 'package:flutter/services.dart';

class WindowsMediaBridge {
  WindowsMediaBridge();

  static const _channel = MethodChannel('qingting/windows_media');

  Future<void> initialize({
    required Future<void> Function() onPrevious,
    required Future<void> Function() onTogglePlay,
    required Future<void> Function() onNext,
  }) async {
    if (!Platform.isWindows) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'previous':
          await onPrevious();
        case 'togglePlay':
          await onTogglePlay();
        case 'next':
          await onNext();
      }
    });
    await _channel.invokeMethod<void>('initialize');
  }

  Future<void> updatePlayback({
    required bool isPlaying,
    required String title,
    required String artist,
  }) async {
    if (!Platform.isWindows) return;
    await _channel.invokeMethod<void>('updatePlayback', {
      'isPlaying': isPlaying,
      'title': title,
      'artist': artist,
    });
  }

  Future<void> setDesktopLyricsVisible(bool visible) async {
    if (!Platform.isWindows) return;
    await _channel.invokeMethod<void>('showDesktopLyrics', visible);
  }

  Future<void> updateDesktopLyrics({
    required String text,
    String secondary = '',
    required double progress,
    required bool dark,
    required int accent,
  }) async {
    if (!Platform.isWindows) return;
    await _channel.invokeMethod<void>('updateDesktopLyrics', {
      'text': text,
      'secondary': secondary,
      'progress': progress.clamp(0.0, 1.0),
      'dark': dark,
      'accent': accent,
    });
  }

  Future<void> dispose() async {
    if (!Platform.isWindows) return;
    _channel.setMethodCallHandler(null);
    await _channel.invokeMethod<void>('dispose');
  }
}
