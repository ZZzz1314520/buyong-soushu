import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/novel_models.dart';

class LocalLibrary {
  LocalLibrary(this._preferences);

  static const _booksKey = 'bookshelf.books.v1';
  static const _sourcesKey = 'search.sources.v1';
  static const _readerSettingsKey = 'reader.settings.v1';

  final SharedPreferences _preferences;

  List<Book> loadBooks() {
    final raw = _preferences.getString(_booksKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((book) => Book.fromJson(book as Map<String, Object?>))
        .toList();
  }

  Future<void> saveBooks(List<Book> books) {
    final raw = jsonEncode(books.map((book) => book.toJson()).toList());
    return _preferences.setString(_booksKey, raw);
  }

  List<SearchSource> loadSources() {
    final raw = _preferences.getString(_sourcesKey);
    if (raw == null || raw.isEmpty) {
      return defaultSources;
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((source) => SearchSource.fromJson(source as Map<String, Object?>))
        .toList();
  }

  Future<void> saveSources(List<SearchSource> sources) {
    final raw = jsonEncode(sources.map((source) => source.toJson()).toList());
    return _preferences.setString(_sourcesKey, raw);
  }

  ReaderSettings loadReaderSettings() {
    final raw = _preferences.getString(_readerSettingsKey);
    if (raw == null || raw.isEmpty) {
      return const ReaderSettings();
    }
    return ReaderSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  Future<void> saveReaderSettings(ReaderSettings settings) {
    return _preferences.setString(
      _readerSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }
}
