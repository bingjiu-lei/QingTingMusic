import 'package:flutter/foundation.dart';

import '../models/song.dart';

/// Holds the account-scoped MV favorites loaded from Kugou.
///
/// MV favorites are no longer a local-only feature. Network operations belong
/// to MusicRepository; this class only keeps the current list and notifies the
/// library when it changes.
class FavoriteMvService extends ChangeNotifier {
  static const maxItems = 500;

  final List<Song> _mvs = [];
  List<Song> get mvs => List.unmodifiable(_mvs);

  bool isFavorite(Song song) {
    if (!song.isMv) return false;
    return _mvs.any((item) => _sameMv(item, song));
  }

  Song? findFavorite(Song song) {
    if (!song.isMv) return null;
    for (final item in _mvs) {
      if (_sameMv(item, song)) return item;
    }
    return null;
  }

  void replaceAll(Iterable<Song> songs) {
    _mvs
      ..clear()
      ..addAll(
        songs
            .where((song) => song.isMv)
            .map((song) => song.copyWith(isMv: true, liked: true))
            .take(maxItems),
      );
    notifyListeners();
  }

  void add(Song song) {
    if (!song.isMv) return;
    _mvs.removeWhere((item) => _sameMv(item, song));
    _mvs.insert(0, song.copyWith(isMv: true, liked: true));
    if (_mvs.length > maxItems) _mvs.removeLast();
    notifyListeners();
  }

  void remove(Song song) {
    final oldLength = _mvs.length;
    _mvs.removeWhere((item) => _sameMv(item, song));
    if (_mvs.length != oldLength) notifyListeners();
  }

  void clear() {
    if (_mvs.isEmpty) return;
    _mvs.clear();
    notifyListeners();
  }

  bool _sameMv(Song left, Song right) {
    final leftMvId = left.mvId?.trim() ?? '';
    final rightMvId = right.mvId?.trim() ?? '';
    if (leftMvId.isNotEmpty && rightMvId.isNotEmpty) {
      return leftMvId == rightMvId;
    }
    final leftHash = left.hash?.trim().toLowerCase() ?? '';
    final rightHash = right.hash?.trim().toLowerCase() ?? '';
    if (leftHash.isNotEmpty && rightHash.isNotEmpty) {
      return leftHash == rightHash;
    }
    return left.id.trim().toLowerCase() == right.id.trim().toLowerCase();
  }
}
