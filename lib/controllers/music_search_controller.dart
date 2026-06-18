import 'package:flutter/foundation.dart';

import '../data/music_repository.dart';
import '../models/song.dart';
import '../services/search_history_service.dart';

class MusicSearchController extends ChangeNotifier {
  MusicSearchController({
    required this.repository,
    required this.historyService,
  });

  final MusicRepository repository;
  final SearchHistoryService historyService;

  String keyword = '';
  List<String> history = const [];
  List<Song> suggestions = const [];
  List<Song> results = const [];
  bool hasSearched = false;

  Future<void> initialize() async {
    history = await historyService.load();
    notifyListeners();
  }

  Future<void> updateKeyword(String value) async {
    keyword = value;
    hasSearched = false;
    results = const [];
    suggestions = await repository.searchSongs(value);
    notifyListeners();
  }

  Future<void> search([String? value]) async {
    final query = (value ?? keyword).trim();
    if (query.isEmpty) return;

    keyword = query;
    results = await repository.searchSongs(query);
    suggestions = const [];
    hasSearched = true;
    history = [
      query,
      ...history.where((item) => item != query),
    ].take(SearchHistoryService.maxItems).toList();
    await historyService.save(history);
    notifyListeners();
  }

  Future<void> useHistory(String value) async {
    await updateKeyword(value);
    await search(value);
  }

  Future<void> removeHistory(String value) async {
    history = history.where((item) => item != value).toList();
    await historyService.save(history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history = const [];
    await historyService.save(history);
    notifyListeners();
  }
}
