import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/song.dart';
import 'app_storage_service.dart';

class FavoriteBilibiliService extends ChangeNotifier {
  static const maxItems = 1000;
  static const fileName = 'bilibili_favorites.json';

  final List<Song> _songs = [];
  bool _initialized = false;

  List<Song> get songs => List.unmodifiable(_songs);

  File get _file => AppStorageService.file(fileName);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await load();
  }

  Future<void> load() async {
    try {
      final file = _file;
      if (!await file.exists()) {
        _songs.clear();
        notifyListeners();
        return;
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) return;
      final raw = jsonDecode(content);
      if (raw is List) {
        _songs
          ..clear()
          ..addAll(
            raw
                .whereType<Map<String, Object?>>()
                .map((json) {
                  // 加载收藏时清空可能残留的临时 audioUrl，确保播放时由播放解析器获取最新鲜活地址
                  final s = Song.fromJson(
                    json,
                  ).copyWith(liked: true, audioUrl: '');
                  if (s.album == '哔哩哔哩') {
                    return Song(
                      id: s.id,
                      title: s.title,
                      artist: s.artist,
                      album: 'B站',
                      duration: s.duration,
                      audioUrl: '',
                      coverUrl: s.coverUrl,
                      mvId: s.mvId,
                      isSpecialSource: s.isSpecialSource,
                      liked: true,
                      playbackSource: s.playbackSource,
                      playbackQuality: s.playbackQuality,
                    );
                  }
                  return s;
                })
                .take(maxItems),
          );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final file = _file;
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      // 持久化存储时统一将临时 audioUrl 置空，仅保存歌曲元数据
      final data = _songs
          .map((song) => song.copyWith(audioUrl: '').toJson())
          .toList();
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e, stack) {
      debugPrint('保存B站本地收藏失败: $e');
    }
  }

  bool isFavorite(Song song) {
    return _songs.any((item) => _sameSong(item, song));
  }

  Future<void> add(Song song) async {
    _songs.removeWhere((item) => _sameSong(item, song));
    // 收藏时不持久化当前可能已解析的临时时效直链
    _songs.insert(
      0,
      song.copyWith(liked: true, playbackSource: 'bilibili', audioUrl: ''),
    );
    if (_songs.length > maxItems) {
      _songs.removeLast();
    }
    notifyListeners();
    await _save();
  }

  Future<void> remove(Song song) async {
    final oldLength = _songs.length;
    _songs.removeWhere((item) => _sameSong(item, song));
    if (_songs.length != oldLength) {
      notifyListeners();
      await _save();
    }
  }

  Future<bool> toggle(Song song) async {
    if (isFavorite(song)) {
      await remove(song);
      return false;
    } else {
      await add(song);
      return true;
    }
  }

  Future<void> clear() async {
    if (_songs.isEmpty) return;
    _songs.clear();
    notifyListeners();
    await _save();
  }

  bool _sameSong(Song a, Song b) {
    if (a.mvId != null &&
        b.mvId != null &&
        a.mvId!.isNotEmpty &&
        b.mvId!.isNotEmpty) {
      return a.mvId!.toLowerCase() == b.mvId!.toLowerCase();
    }
    return a.id.toLowerCase() == b.id.toLowerCase();
  }
}
