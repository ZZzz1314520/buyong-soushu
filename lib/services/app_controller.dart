import 'package:flutter/foundation.dart';

import '../models/novel_models.dart';
import 'local_library.dart';
import 'novel_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.library,
    required this.novelService,
    required List<Book> initialBooks,
  }) : books = initialBooks {
    sources = library.loadSources();
    readerSettings = library.loadReaderSettings();
  }

  final LocalLibrary library;
  final NovelService novelService;

  List<Book> books;
  late List<SearchSource> sources;
  late ReaderSettings readerSettings;

  Future<List<BookSearchResult>> search(String query) {
    library.searchHistory.add(query);
    return novelService.searchBooks(query, sources);
  }

  List<String> get searchHistory => library.searchHistory.load();

  Future<void> removeSearchHistoryItem(String query) =>
      library.searchHistory.remove(query);

  Future<void> clearSearchHistory() => library.searchHistory.clear();

  Future<Book> addResultToShelf(BookSearchResult result) async {
    final existing = books.where((book) => book.url == result.url).firstOrNull;
    if (existing != null) {
      return existing;
    }

    final book = await novelService.buildBookFromResult(result);
    books = [book, ...books];
    await library.saveBook(book);
    notifyListeners();
    return book;
  }

  Future<Book> refreshBookChapters(Book book) async {
    final result = BookSearchResult(
      title: book.title,
      url: book.url,
      sourceId: book.sourceId,
      sourceName: book.sourceName,
    );
    final refreshed = await novelService.buildBookFromResult(result);

    // Merge: keep cached content for chapters whose URLs match
    final merged = refreshed.chapters.map((newChapter) {
      final old = book.chapters
          .where((c) => c.url == newChapter.url)
          .firstOrNull;
      return old != null && old.content.trim().isNotEmpty
          ? newChapter.copyWith(content: old.content)
          : newChapter;
    }).toList();

    final updated = refreshed.copyWith(
      chapters: merged,
      currentChapterIndex: book.currentChapterIndex
          .clamp(0, merged.length - 1),
      lastReadAt: book.lastReadAt,
      scrollPosition: book.scrollPosition,
      chapterProgress: book.chapterProgress,
    );
    await updateBook(updated);
    return updated;
  }

  Future<void> removeBook(Book book) async {
    books = books.where((item) => item.id != book.id).toList();
    await library.deleteBook(book.id);
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

  /// Pre-fetch chapter N+1 in the background so the next page-turn is instant.
  Future<void> prefetchChapter(Book book, int chapterIndex) async {
    if (chapterIndex < 0 || chapterIndex >= book.chapters.length) return;
    final chapter = book.chapters[chapterIndex];
    if (chapter.content.trim().isNotEmpty) return; // already cached
    try {
      final loaded = await novelService.loadChapter(chapter);
      final chapters = [...book.chapters];
      chapters[chapterIndex] = loaded;
      final updated = book.copyWith(chapters: chapters);
      // Persist to file without notifying listeners (avoids UI rebuild)
      books = [
        for (final b in books)
          if (b.id == updated.id) updated else b,
      ];
      await library.saveBook(updated);
    } catch (_) {
      // Pre-fetch failure is non-critical
    }
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
    await library.saveBook(updated);
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

  Future<void> removeSource(SearchSource source) async {
    sources = sources.where((item) => item.id != source.id).toList();
    await library.saveSources(sources);
    notifyListeners();
  }

  Future<List<BookSearchResult>> testSource(SearchSource source) {
    return novelService.searchBooks('测试', [source.copyWith(enabled: true)]);
  }

  @override
  void dispose() {
    novelService.dispose();
    super.dispose();
  }
}
