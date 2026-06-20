import 'dart:io';

class PlaybackLogService {
  static Future<void> write(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) async {
    try {
      final root = Platform.environment['PUBLIC'] ?? r'C:\Users\Public';
      final file = File('$root\\QingTingMusic\\playback.log');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${DateTime.now().toIso8601String()} [$stage]\n$error\n$stackTrace\n\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }
}
