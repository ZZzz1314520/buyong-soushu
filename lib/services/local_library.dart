import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/novel_models.dart';
import 'book_file_storage.dart';
import 'search_history.dart';

class LocalLibrary {
  LocalLibrary(this._preferences, {Directory? testBooksDir})
    : _bookStorage = BookFileStorage(
        preferences: _preferences,
        testDir: testBooksDir,
      ),
      searchHistory = SearchHistory(_preferences);

  static const _sourcesKey = 'search.sources.v1';
  static const _readerSettingsKey = 'reader.settings.v1';

  final SharedPreferences _preferences;
  final BookFileStorage _bookStorage;
  final SearchHistory searchHistory;

  /// Run the one-time migration from old SharedPreferences books → files.
  Future<List<Book>> migrateBooks() => _bookStorage.migrateIfNeeded();

  Future<List<Book>> loadBooks() => _bookStorage.loadAllBooks();

  Future<void> saveBooks(List<Book> books) => _bookStorage.saveAllBooks(books);

  Future<void> saveBook(Book book) => _bookStorage.saveBook(book);

  Future<void> deleteBook(String bookId) => _bookStorage.deleteBook(bookId);

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
