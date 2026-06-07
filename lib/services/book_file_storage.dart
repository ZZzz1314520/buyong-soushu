import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/novel_models.dart';

class BookFileStorage {
  BookFileStorage({
    required this.preferences,
    this.testDir,
  });

  final SharedPreferences preferences;
  final Directory? testDir;

  static const _oldBooksKey = 'bookshelf.books.v1';
  static const _migrationDoneKey = 'bookshelf.migrated.v1';

  Future<Directory> get _booksDir async {
    final testDirLocal = testDir;
    if (testDirLocal != null) {
      return testDirLocal;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/books');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _bookPath(String bookId) => 'books/$bookId.json';

  /// One-time migration from SharedPreferences to file storage.
  /// Returns the migrated books.
  Future<List<Book>> migrateIfNeeded() async {
    final alreadyMigrated = preferences.getBool(_migrationDoneKey) ?? false;
    if (alreadyMigrated) {
      return [];
    }

    final oldRaw = preferences.getString(_oldBooksKey);
    if (oldRaw == null || oldRaw.isEmpty) {
      await preferences.setBool(_migrationDoneKey, true);
      return [];
    }

    List<Book> books;
    try {
      final decoded = jsonDecode(oldRaw) as List<dynamic>;
      books = decoded
          .map((book) => Book.fromJson(book as Map<String, Object?>))
          .toList();
    } catch (_) {
      // Corrupted old data – clear it and move on
      await preferences.remove(_oldBooksKey);
      await preferences.setBool(_migrationDoneKey, true);
      return [];
    }

    // Write each book to its own file
    for (final book in books) {
      await _writeBookFile(book);
    }

    // Clean up old SharedPreferences data
    await preferences.remove(_oldBooksKey);
    await preferences.setBool(_migrationDoneKey, true);

    return books;
  }

  Future<Book?> loadBook(String bookId) async {
    final dir = await _booksDir;
    final file = File('${dir.path}/${_bookPath(bookId).split('/').last}');
    if (!await file.exists()) {
      return null;
    }
    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, Object?>;
      return Book.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<List<Book>> loadAllBooks() async {
    final dir = await _booksDir;
    final books = <Book>[];
    if (!await dir.exists()) {
      return books;
    }
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final raw = await entity.readAsString();
          final json = jsonDecode(raw) as Map<String, Object?>;
          books.add(Book.fromJson(json));
        } catch (_) {
          // Skip corrupted files
        }
      }
    }
    return books;
  }

  Future<void> saveBook(Book book) async {
    await _writeBookFile(book);
  }

  Future<void> saveAllBooks(List<Book> books) async {
    for (final book in books) {
      await _writeBookFile(book);
    }
  }

  Future<void> deleteBook(String bookId) async {
    final dir = await _booksDir;
    final file = File('${dir.path}/${_bookPath(bookId).split('/').last}');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _writeBookFile(Book book) async {
    final dir = await _booksDir;
    final file = File('${dir.path}/${_bookPath(book.id).split('/').last}');
    final json = book.toJson();
    json['formatVersion'] = 1;
    await file.writeAsString(jsonEncode(json));
  }
}
