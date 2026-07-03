import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/music_repository.dart';
import '../models/song.dart';
import '../models/search_catalog_item.dart';
import '../services/kugou_api_client.dart';
import '../services/search_history_service.dart';
import '../services/music_search_cache_service.dart';

class MusicSearchController extends ChangeNotifier {
  MusicSearchController({
    required this.repository,
    required this.historyService,
    MusicSearchCacheService? cacheService,
  }) : cacheService = cacheService ?? MusicSearchCacheService();

  final MusicRepository repository;
  final SearchHistoryService historyService;
  final MusicSearchCacheService cacheService;

  String keyword = '';
  List<String> history = const [];
  List<String> suggestions = const [];
  List<Song> results = const [];
  List<SearchCatalogItem> catalogResults = const [];
  SearchCategory category = SearchCategory.song;
  bool hasSearched = false;
  bool isLoading = false;
  String? errorText;
  bool requiresLogin = false;
  int _suggestionRequest = 0;
  int _searchRequest = 0;
  final Map<String, List<Song>> _songCache = {};
  final Map<String, List<SearchCatalogItem>> _catalogCache = {};
  final Map<String, Future<List<SearchCatalogItem>>> _catalogRequests = {};

  Future<void> initialize() async {
    final values = await Future.wait<Object>([
      historyService.load(),
      cacheService.load(),
    ]);
    history = values[0] as List<String>;
    final cache = values[1] as MusicSearchCache;
    _songCache.addAll(cache.songs);
    _catalogCache.addAll(cache.catalogs);
    notifyListeners();
  }

  Future<void> updateKeyword(String value) async {
    keyword = value;
    hasSearched = false;
    results = const [];
    catalogResults = const [];
    errorText = null;
    requiresLogin = false;
    final query = value.trim();
    final request = ++_suggestionRequest;
    if (query.isEmpty) {
      suggestions = const [];
      notifyListeners();
      return;
    }

    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (request != _suggestionRequest) return;
    try {
      final next = await repository.searchSuggestions(query);
      if (request != _suggestionRequest) return;
      suggestions = next;
    } catch (_) {
      if (request != _suggestionRequest) return;
      suggestions = const [];
    }
    notifyListeners();
  }

  Future<void> search([String? value]) async {
    final query = (value ?? keyword).trim();
    if (query.isEmpty) return;

    keyword = query;
    suggestions = const [];
    hasSearched = true;
    isLoading = true;
    errorText = null;
    requiresLogin = false;
    notifyListeners();
    final request = ++_searchRequest;

    try {
      if (category == SearchCategory.song) {
        final cached = _songCache[query];
        results = _usableSongCache(cached)
            ? cached!
            : await repository.searchSongs(query);
        if (results.isNotEmpty) _songCache[query] = results;
        unawaited(cacheService.save(_songCache, _catalogCache));
        catalogResults = const [];
      } else {
        final key = '${category.name}:$query';
        final cached = _catalogCache[key];
        catalogResults = cached != null && cached.isNotEmpty
            ? cached
            : await _loadCatalog(query, category);
        if (request != _searchRequest) return;
        if (catalogResults.isNotEmpty) _catalogCache[key] = catalogResults;
        unawaited(cacheService.save(_songCache, _catalogCache));
        results = const [];
      }
    } on AuthenticationRequiredException {
      results = const [];
      requiresLogin = true;
      errorText = '登录后即可搜索完整歌曲';
    } on KugouApiException catch (error) {
      results = const [];
      errorText = error.message;
    } catch (_) {
      results = const [];
      errorText = '搜索失败，请稍后重试';
    } finally {
      if (request == _searchRequest) isLoading = false;
    }

    if (request != _searchRequest) return;
    history = [
      query,
      ...history.where((item) => item != query),
    ].take(SearchHistoryService.maxItems).toList();
    notifyListeners();
    unawaited(historyService.save(history));
    if (category == SearchCategory.song && errorText == null) {
      unawaited(_prefetchCatalog(query));
    }
  }

  Future<void> selectCategory(SearchCategory value) async {
    if (category == value) return;
    category = value;
    if (hasSearched && keyword.trim().isNotEmpty) {
      final query = keyword.trim();
      if (value == SearchCategory.song && _songCache.containsKey(query)) {
        final cached = _songCache[query]!;
        if (_usableSongCache(cached)) {
          results = cached;
          catalogResults = const [];
          notifyListeners();
          return;
        }
      }
      final key = '${value.name}:$query';
      if (_catalogCache.containsKey(key)) {
        final cached = _catalogCache[key]!;
        if (cached.isNotEmpty) {
          catalogResults = cached;
          results = const [];
          notifyListeners();
          return;
        }
      }
      await search();
    } else {
      notifyListeners();
    }
  }

  Future<void> _prefetchCatalog(String query) async {
    for (final value in [
      SearchCategory.playlist,
      SearchCategory.artist,
      SearchCategory.album,
    ]) {
      final key = '${value.name}:$query';
      if (_catalogCache.containsKey(key)) continue;
      try {
        _catalogCache[key] = await _loadCatalog(query, value);
        unawaited(cacheService.save(_songCache, _catalogCache));
        if (category == value && keyword.trim() == query && hasSearched) {
          catalogResults = _catalogCache[key]!;
          isLoading = false;
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  Future<List<SearchCatalogItem>> _loadCatalog(
    String query,
    SearchCategory value,
  ) {
    final key = '${value.name}:$query';
    return _catalogRequests.putIfAbsent(key, () async {
      try {
        return await repository.searchCatalog(query, value);
      } finally {
        _catalogRequests.remove(key);
      }
    });
  }

  bool _usableSongCache(List<Song>? songs) {
    if (songs == null || songs.isEmpty) return false;
    return songs.any(
      (song) => song.coverUrl != null && song.coverUrl!.isNotEmpty,
    );
  }

  void clearError() {
    errorText = null;
    requiresLogin = false;
    notifyListeners();
  }

  void invalidateCachedResults() {
    _songCache.clear();
    _catalogCache.clear();
    _catalogRequests.clear();
    if (hasSearched) {
      results = const [];
      catalogResults = const [];
      errorText = null;
      requiresLogin = false;
    }
    notifyListeners();
  }

  void clearAccountState() {
    keyword = '';
    suggestions = const [];
    results = const [];
    catalogResults = const [];
    hasSearched = false;
    isLoading = false;
    errorText = null;
    requiresLogin = false;
    _songCache.clear();
    _catalogCache.clear();
    _catalogRequests.clear();
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
