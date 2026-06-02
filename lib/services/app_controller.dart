import 'package:flutter/foundation.dart';

import '../models/novel_models.dart';
import 'local_library.dart';
import 'novel_service.dart';

class AppController extends ChangeNotifier {
  AppController({required this.library, required this.novelService}) {
    books = library.loadBooks();
    sources = library.loadSources();
    readerSettings = library.loadReaderSettings();
  }

  final LocalLibrary library;
  final NovelService novelService;

  late List<Book> books;
  late List<SearchSource> sources;
  late ReaderSettings readerSettings;

  Future<List<BookSearchResult>> search(String query) {
    return novelService.searchBooks(query, sources);
  }

  Future<Book> addResultToShelf(BookSearchResult result) async {
    final existing = books.where((book) => book.url == result.url).firstOrNull;
    if (existing != null) {
      return existing;
    }

    final book = await novelService.buildBookFromResult(result);
    books = [book, ...books];
    await library.saveBooks(books);
    notifyListeners();
    return book;
  }

  Future<void> removeBook(Book book) async {
    books = books.where((item) => item.id != book.id).toList();
    await library.saveBooks(books);
    notifyListeners();
  }

  Future<Chapter> ensureChapterLoaded(Book book, int chapterIndex) async {
    if (book.chapters.isEmpty) {
      throw Exception('这本书还没有可阅读章节');
    }
    final safeIndex = chapterIndex.clamp(0, book.chapters.length - 1).toInt();
    final chapter = await novelService.loadChapter(book.chapters[safeIndex]);
    final chapters = [...book.chapters];
    chapters[safeIndex] = chapter;
    await updateBook(
      book.copyWith(
        chapters: chapters,
        currentChapterIndex: safeIndex,
        lastReadAt: DateTime.now(),
      ),
    );
    return chapter;
  }

  Future<Book?> appendNextChapter(Book book) async {
    if (book.chapters.isEmpty) {
      return null;
    }
    final current = book.chapters[book.currentChapterIndex];
    final next = await novelService.loadNextFromLink(current);
    if (next == null) {
      return null;
    }
    final updated = book.copyWith(chapters: [...book.chapters, next]);
    await updateBook(updated);
    return updated;
  }

  Future<void> updateBook(Book updated) async {
    books = [
      for (final book in books)
        if (book.id == updated.id) updated else book,
    ];
    await library.saveBooks(books);
    notifyListeners();
  }

  Future<void> updateReaderSettings(ReaderSettings settings) async {
    readerSettings = settings;
    await library.saveReaderSettings(settings);
    notifyListeners();
  }

  Future<void> addSource(String name, String urlTemplate) async {
    final source = SearchSource(
      id: stableId('$name-$urlTemplate'),
      name: name.trim(),
      urlTemplate: urlTemplate.trim(),
    );
    sources = [...sources, source];
    await library.saveSources(sources);
    notifyListeners();
  }

  Future<void> toggleSource(SearchSource source, bool enabled) async {
    sources = [
      for (final item in sources)
        if (item.id == source.id) item.copyWith(enabled: enabled) else item,
    ];
    await library.saveSources(sources);
    notifyListeners();
  }
}
