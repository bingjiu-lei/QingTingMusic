import 'app_preferences_service.dart';

class SearchHistoryService {
  static const _storageKey = 'music_search_history';
  static const maxItems = 8;
  final AppPreferencesService _preferences = AppPreferencesService();

  Future<List<String>> load() async {
    final value = await _preferences.read(_storageKey);
    return value is List
        ? value.map((item) => item.toString()).toList()
        : const [];
  }

  Future<void> save(List<String> values) async {
    await _preferences.write(_storageKey, values.take(maxItems).toList());
  }
}
