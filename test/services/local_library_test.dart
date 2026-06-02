import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/models/novel_models.dart';
import 'package:novel_reader/services/local_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('LocalLibrary persists books, sources and reader settings', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final library = LocalLibrary(preferences);

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
    await library.saveBooks([book]);

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
        pageTurnMode: PageTurnMode.tapSides,
      ),
    );

    expect(library.loadBooks().single.title, '测试小说');
    expect(library.loadSources().single.name, '自定义');
    expect(library.loadReaderSettings().fontSize, 24);
    expect(library.loadReaderSettings().theme, ReaderTheme.dark);
    expect(library.loadReaderSettings().pageTurnMode, PageTurnMode.tapSides);
  });
}
