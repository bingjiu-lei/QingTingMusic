import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/song.dart';
import 'app_storage_service.dart';

class FavoriteMvService extends ChangeNotifier {
  FavoriteMvService() {
    _load();
  }

  static const maxItems = 500;
  File get _file => AppStorageService.file('favorite-mvs.json');

  final List<Song> _mvs = [];
  List<Song> get mvs => List.unmodifiable(_mvs);

  bool isFavorite(Song song) {
    if (!song.isMv) return false;
    final hash = song.hash?.toLowerCase() ?? '';
    final id = song.id.toLowerCase();
    return _mvs.any((item) {
      if (hash.isNotEmpty && item.hash?.toLowerCase() == hash) return true;
      if (item.id.toLowerCase() == id) return true;
      return false;
    });
  }

  Future<void> toggleFavorite(Song song) async {
    if (!song.isMv) return;
    if (isFavorite(song)) {
      final hash = song.hash?.toLowerCase() ?? '';
      final id = song.id.toLowerCase();
      _mvs.removeWhere((item) =>
          (hash.isNotEmpty && item.hash?.toLowerCase() == hash) ||
          item.id.toLowerCase() == id);
    } else {
      _mvs.insert(0, song.copyWith(liked: true));
      if (_mvs.length > maxItems) {
        _mvs.removeLast();
      }
    }
    notifyListeners();
    _save();
  }

  void _load() {
    if (Platform.isWindows && _file.existsSync()) {
      try {
        final values = jsonDecode(_file.readAsStringSync());
        if (values is List) {
          _mvs.clear();
          _mvs.addAll(
            values
                .whereType<Map>()
                .map((item) => Song.fromJson(item.cast<String, Object?>()))
                .map((song) => song.copyWith(isMv: true, liked: true)),
          );
        }
      } catch (_) {}
    }
  }

  void _save() {
    try {
      if (!_file.parent.existsSync()) {
        _file.parent.createSync(recursive: true);
      }
      _file.writeAsStringSync(
        jsonEncode(_mvs.map((song) => song.toJson()).toList()),
        flush: true,
      );
    } catch (_) {}
  }
}
