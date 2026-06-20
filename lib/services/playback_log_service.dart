import 'dart:io';

import 'app_storage_service.dart';

class PlaybackLogService {
  static Future<void> write(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) async {
    try {
      final file = AppStorageService.file('playback.log');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${DateTime.now().toIso8601String()} [$stage]\n$error\n$stackTrace\n\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }
}
