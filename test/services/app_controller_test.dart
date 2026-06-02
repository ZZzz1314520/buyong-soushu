import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/models/novel_models.dart';
import 'package:novel_reader/services/app_controller.dart';
import 'package:novel_reader/services/local_library.dart';
import 'package:novel_reader/services/novel_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bookTitle = '\u6d4b\u8bd5\u5c0f\u8bf4';
const chapterTitle = '\u7b2c\u4e00\u7ae0 \u521d\u89c1';
const cachedContent =
    '\u7b2c\u4e00\u9875\u6b63\u6587\u3002\n\n\u7b2c\u4e8c\u9875\u6b63\u6587\u3002';

void main() {
  test('AppController persists the fully loaded chapter content', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final library = LocalLibrary(preferences);
    final book = Book(
      id: 'book-1',
      title: bookTitle,
      url: 'https://novel.example/book',
      sourceId: 'test',
      sourceName: 'test source',
      chapters: const [
        Chapter(title: chapterTitle, url: 'https://novel.example/book/1.html'),
      ],
    );
    await library.saveBooks([book]);

    final controller = AppController(
      library: library,
      novelService: _CachingNovelService(),
    );

    final loaded = await controller.ensureChapterLoaded(book, 0);

    expect(loaded.content, cachedContent);
    expect(controller.books.single.chapters.single.content, cachedContent);
    expect(library.loadBooks().single.chapters.single.content, cachedContent);
  });
}

class _CachingNovelService extends NovelService {
  @override
  Future<Chapter> loadChapter(Chapter chapter) async {
    return chapter.copyWith(content: cachedContent);
  }
}
