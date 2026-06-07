import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SearchHistory {
  SearchHistory(this._preferences);

  static const _key = 'search.history.v1';
  static const _maxItems = 20;

  final SharedPreferences _preferences;

  List<String> load() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final list = load()..remove(trimmed);
    list.insert(0, trimmed);
    if (list.length > _maxItems) {
      list.removeRange(_maxItems, list.length);
    }
    await _preferences.setString(_key, jsonEncode(list));
  }

  Future<void> remove(String query) async {
    final list = load()..remove(query);
    await _preferences.setString(_key, jsonEncode(list));
  }

  Future<void> clear() async {
    await _preferences.remove(_key);
  }
}
