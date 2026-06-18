import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const _storageKey = 'music_search_history';
  static const maxItems = 8;

  Future<List<String>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_storageKey) ?? const [];
  }

  Future<void> save(List<String> values) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      values.take(maxItems).toList(),
    );
  }
}
