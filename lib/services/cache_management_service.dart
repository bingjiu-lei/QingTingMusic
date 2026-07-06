import 'dart:io';

import 'app_preferences_service.dart';
import 'app_storage_service.dart';

class CacheManagementService {
  CacheManagementService({AppPreferencesService? preferences})
    : _preferences = preferences ?? AppPreferencesService();

  final AppPreferencesService _preferences;

  static const cacheLimitKey = 'cacheLimitBytes';
  static const defaultLimitBytes = 1024 * 1024 * 1024;

  Future<int> loadLimitBytes() async {
    final value = await _preferences.read(cacheLimitKey);
    if (value is int && value > 0) return value;
    return defaultLimitBytes;
  }

  Future<void> saveLimitBytes(int bytes) async {
    if (bytes <= 0) return;
    await _preferences.write(cacheLimitKey, bytes);
    await trimToLimit();
  }

  Future<int> cacheSizeBytes() async {
    var total = 0;
    for (final entry in await _cacheEntries()) {
      total += entry.length;
    }
    return total;
  }

  Future<void> clearCache() async {
    for (final entity in _managedRoots()) {
      try {
        if (await entity.exists()) {
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<void> clearDownloadedInstallers() async {
    final directory = AppStorageService.directory('updates');
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last.toLowerCase();
      if (!name.endsWith('.exe') && !name.endsWith('.download')) continue;
      try {
        await entity.delete();
      } catch (_) {}
    }
  }

  Future<void> trimToLimit() async {
    final limit = await loadLimitBytes();
    final entries = await _cacheEntries();
    var total = entries.fold<int>(0, (sum, entry) => sum + entry.length);
    if (total <= limit) return;

    final target = (limit * 0.8).round();
    entries.sort((a, b) => a.modified.compareTo(b.modified));
    for (final entry in entries) {
      if (total <= target) break;
      try {
        if (await entry.file.exists()) {
          await entry.file.delete();
          total -= entry.length;
        }
      } catch (_) {}
    }
  }

  Future<List<_CacheEntry>> _cacheEntries() async {
    final entries = <_CacheEntry>[];
    for (final entity in _managedRoots()) {
      if (!await entity.exists()) continue;
      if (entity is File) {
        final entry = await _entryFor(entity);
        if (entry != null) entries.add(entry);
        continue;
      }
      if (entity is Directory) {
        await for (final child in entity.list(recursive: true)) {
          if (child is! File) continue;
          final entry = await _entryFor(child);
          if (entry != null) entries.add(entry);
        }
      }
    }
    return entries;
  }

  Future<_CacheEntry?> _entryFor(File file) async {
    try {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file || stat.size <= 0) {
        return null;
      }
      return _CacheEntry(
        file: file,
        length: stat.size,
        modified: stat.modified,
      );
    } catch (_) {
      return null;
    }
  }

  List<FileSystemEntity> _managedRoots() => [
    AppStorageService.directory('audio'),
    AppStorageService.directory('updates'),
    AppStorageService.file('library-cache.json'),
    AppStorageService.file('library-playlist-tracks.json'),
    AppStorageService.file('search-cache.json'),
    AppStorageService.file('recent-songs.json'),
    AppStorageService.file('playback.log'),
  ];
}

class _CacheEntry {
  const _CacheEntry({
    required this.file,
    required this.length,
    required this.modified,
  });

  final File file;
  final int length;
  final DateTime modified;
}
