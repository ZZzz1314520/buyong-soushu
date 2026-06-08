import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/models/novel_models.dart';
import 'package:novel_reader/services/local_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('LocalLibrary persists books, sources and reader settings', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final tempDir = await Directory.systemTemp.createTemp('book_test_');
    final library = LocalLibrary(preferences, testBooksDir: tempDir);

    final book = Book(
      id: 'book-1',
      title: '测试小说',
      url: 'https://novel.example/book',
      sourceId: 'test',
      sourceName: '测试源',
      chapters: const [
        Chapter(title: '第一章', url: 'https://novel.example/1.html'),
      ],
    );
    await library.saveBook(book);

    await library.saveSources(const [
      SearchSource(
        id: 'custom',
        name: '自定义',
        urlTemplate: 'https://example.com/search?q={query}',
      ),
    ]);

    await library.saveReaderSettings(
      const ReaderSettings(
        fontSize: 24,
        theme: ReaderTheme.dark,
        pageTurnMode: PageTurnMode.horizontalFlip,
      ),
    );

    expect((await library.loadBooks()).single.title, '测试小说');
    final sources = library.loadSources();
    expect(sources.length, defaultSources.length + 1);
    expect(sources.first.id, defaultSources.first.id);
    expect(sources.last.name, '自定义');
    expect(library.loadReaderSettings().fontSize, 24);
    expect(library.loadReaderSettings().theme, ReaderTheme.dark);
    expect(
      library.loadReaderSettings().pageTurnMode,
      PageTurnMode.horizontalFlip,
    );
  });

  test(
    'LocalLibrary migrates removed page turn modes to horizontal flip',
    () async {
      SharedPreferences.setMockInitialValues({
        'reader.settings.v1': jsonEncode({
          'fontSize': 24,
          'lineHeight': 1.7,
          'theme': 'dark',
          'pageTurnMode': 'verticalScroll',
          'enableFlipAnimation': false,
        }),
      });
      final preferences = await SharedPreferences.getInstance();
      final library = LocalLibrary(preferences);

      final settings = library.loadReaderSettings();

      expect(settings.fontSize, 24);
      expect(settings.theme, ReaderTheme.dark);
      expect(settings.pageTurnMode, PageTurnMode.horizontalFlip);
      expect(settings.enableFlipAnimation, isFalse);
    },
  );

  test(
    'LocalLibrary merges new default sources into saved source settings',
    () async {
      SharedPreferences.setMockInitialValues({
        'search.sources.v1': jsonEncode([
          {
            'id': 'bing',
            'name': 'Old Bing',
            'urlTemplate': 'https://old.example?q={query}',
            'enabled': false,
          },
          {
            'id': 'custom',
            'name': '自定义',
            'urlTemplate': 'https://example.com/search?q={query}',
            'enabled': true,
          },
        ]),
      });
      final preferences = await SharedPreferences.getInstance();
      final library = LocalLibrary(preferences);

      final sources = library.loadSources();

      expect(sources.length, defaultSources.length + 1);
      expect(sources.first.id, 'bing');
      expect(sources.first.name, 'Bing 小说');
      expect(sources.first.enabled, isFalse);
      expect(sources.any((source) => source.id == 'duckduckgo-lite'), isTrue);
      expect(sources.last.id, 'custom');
    },
  );

  test('default search source catalog has many unique query templates', () {
    expect(defaultSources.length, greaterThanOrEqualTo(20));
    expect(
      defaultSources.map((source) => source.id).toSet(),
      hasLength(defaultSources.length),
    );
    expect(
      defaultSources.every((source) => source.urlTemplate.contains('{query}')),
      isTrue,
    );
  });
}
