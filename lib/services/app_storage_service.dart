import 'dart:io';

class AppStorageService {
  static Directory? _overrideDirectory;
  static Directory? _resolvedDirectory;

  static Directory get dataDirectory {
    final override = _overrideDirectory;
    if (override != null) return override;
    return _resolvedDirectory ?? _preferredDirectory();
  }

  static File file(String name) => File('${dataDirectory.path}\\$name');

  static Directory directory(String name) =>
      Directory('${dataDirectory.path}\\$name');

  static void overrideForTesting(Directory? directory) {
    _overrideDirectory = directory;
  }

  static Future<void> initialize() async {
    if (_overrideDirectory == null) {
      final preferred = _preferredDirectory();
      try {
        await preferred.create(recursive: true);
        _resolvedDirectory = preferred;
      } catch (_) {
        final fallback = Directory(
          '${File(Platform.resolvedExecutable).parent.path}\\userdata',
        );
        await fallback.create(recursive: true);
        _resolvedDirectory = fallback;
      }
    } else {
      await dataDirectory.create(recursive: true);
    }
    if (!Platform.isWindows) return;

    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      await _migrateDirectory(Directory('$localAppData\\QingTingMusic'));
    }

    final publicRoot = Platform.environment['PUBLIC'];
    if (publicRoot != null) {
      await _migrateDirectory(Directory('$publicRoot\\QingTingMusic'));
    }
  }

  static Directory _preferredDirectory() {
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    if (!Platform.isWindows) {
      return Directory('${executableDirectory.path}\\userdata');
    }

    final systemDrive = (Platform.environment['SystemDrive'] ?? 'C:')
        .toUpperCase();
    final executableOnSystemDrive = executableDirectory.path
        .toUpperCase()
        .startsWith('$systemDrive\\');
    if (executableOnSystemDrive && Directory(r'D:\').existsSync()) {
      return Directory(r'D:\QingTingMusic\userdata');
    }
    return Directory('${executableDirectory.path}\\userdata');
  }

  static Future<void> _migrateDirectory(Directory source) async {
    if (!await source.exists()) return;
    try {
      await for (final entity in source.list(recursive: true)) {
        if (entity is! File) continue;
        final relativePath = entity.path.substring(source.path.length + 1);
        final target = File('${dataDirectory.path}\\$relativePath');
        if (!await target.exists()) {
          await target.parent.create(recursive: true);
          await entity.copy(target.path);
        }
        await entity.delete();
      }
      if (await source.exists()) {
        await source.delete(recursive: true);
      }
    } catch (_) {
      // Old public files may have restrictive ACLs. New writes still use userdata.
    }
  }
}
