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
                  final s = Song.fromJson(json).copyWith(liked: true);
                  if (s.album == '哔哩哔哩') {
                    return Song(
                      id: s.id,
                      title: s.title,
                      artist: s.artist,
                      album: 'B站',
                      duration: s.duration,
                      audioUrl: s.audioUrl,
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
      final data = _songs.map((song) => song.toJson()).toList();
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }

  bool isFavorite(Song song) {
    return _songs.any((item) => _sameSong(item, song));
  }

  Future<void> add(Song song) async {
    _songs.removeWhere((item) => _sameSong(item, song));
    _songs.insert(0, song.copyWith(liked: true, playbackSource: 'bilibili'));
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
