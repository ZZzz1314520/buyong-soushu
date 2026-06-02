import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/main.dart';
import 'package:novel_reader/models/novel_models.dart';
import 'package:novel_reader/services/app_controller.dart';
import 'package:novel_reader/services/local_library.dart';
import 'package:novel_reader/services/novel_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const shelfTitle = '\u6211\u7684\u4e66\u67b6';
const emptyShelf = '\u4e66\u67b6\u8fd8\u662f\u7a7a\u7684';
const searchTab = '\u641c\u4e66';
const searchButton = '\u641c\u7d22';
const addButton = '\u52a0\u5165';
const settingsTab = '\u8bbe\u7f6e';
const readingPreference = '\u9605\u8bfb\u504f\u597d';
const readerSettings = '\u9605\u8bfb\u8bbe\u7f6e';
const fontSizeLabel = '\u5b57\u4f53\u5927\u5c0f';
const sourceSection = '\u641c\u7d22\u6765\u6e90';
const addSourceButton = '\u6dfb\u52a0';
const saveButton = '\u4fdd\u5b58';
const sourceNameLabel = '\u6765\u6e90\u540d\u79f0';
const customSourceName = '\u81ea\u5b9a\u4e49\u6e90';
const bookQuery = '\u6d4b\u8bd5\u5c0f\u8bf4';
const bookTitle = '\u6d4b\u8bd5\u5c0f\u8bf4\u5168\u6587\u9605\u8bfb';
const sourceName = '\u6d4b\u8bd5\u6e90';
const chapterTitle = '\u7b2c\u4e00\u7ae0 \u521d\u89c1';
const chapterContent =
    '\u8fd9\u662f\u8f6f\u4ef6\u5185\u7f6e\u683c\u5f0f\u7684\u6b63\u6587';

void main() {
  testWidgets('user can search, add a book and read it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppController(
      library: LocalLibrary(preferences),
      novelService: _FakeNovelService(),
    );

    await tester.pumpWidget(NovelReaderApp(controller: controller));

    expect(find.text(shelfTitle), findsOneWidget);
    expect(find.text(emptyShelf), findsOneWidget);

    await tester.tap(find.text(searchTab));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('book-search-field')),
      bookQuery,
    );
    await tester.tap(find.text(searchButton));
    await tester.pumpAndSettle();

    expect(find.text(bookTitle), findsOneWidget);

    await tester.tap(find.text(addButton));
    await tester.pumpAndSettle();

    expect(find.text(chapterTitle), findsWidgets);
    expect(find.textContaining(chapterContent), findsOneWidget);

    await tester.tap(find.byTooltip(readerSettings));
    await tester.pumpAndSettle();

    expect(find.text(readerSettings), findsOneWidget);
    expect(find.text(fontSizeLabel), findsOneWidget);
  });

  testWidgets('settings only exposes search source controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppController(
      library: LocalLibrary(preferences),
      novelService: _FakeNovelService(),
    );

    await tester.pumpWidget(NovelReaderApp(controller: controller));
    await tester.tap(find.text(settingsTab));
    await tester.pumpAndSettle();

    expect(find.text(readingPreference), findsNothing);
    expect(controller.sources.first.name, 'Bing');

    expect(find.text(sourceSection), findsOneWidget);

    await tester.tap(find.text(addSourceButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, sourceNameLabel),
      customSourceName,
    );
    await tester.tap(find.text(saveButton));
    await tester.pumpAndSettle();

    expect(controller.sources.last.name, customSourceName);
  });
}

class _FakeNovelService extends NovelService {
  @override
  Future<List<BookSearchResult>> searchBooks(
    String query,
    List<SearchSource> sources,
  ) async {
    return const [
      BookSearchResult(
        title: bookTitle,
        url: 'https://novel.example/book/index.html',
        sourceId: 'fake',
        sourceName: sourceName,
      ),
    ];
  }

  @override
  Future<Book> buildBookFromResult(BookSearchResult result) async {
    return Book(
      id: stableId(result.url),
      title: result.title,
      url: result.url,
      sourceId: result.sourceId,
      sourceName: result.sourceName,
      chapters: const [
        Chapter(
          title: chapterTitle,
          url: 'https://novel.example/book/1.html',
          content: '$chapterContent.\n\nSecond paragraph.',
        ),
        Chapter(
          title: '\u7b2c\u4e8c\u7ae0 \u98ce\u8d77',
          url: 'https://novel.example/book/2.html',
          content: 'Next chapter.',
        ),
      ],
    );
  }

  @override
  Future<Chapter> loadChapter(Chapter chapter) async {
    return chapter;
  }
}
