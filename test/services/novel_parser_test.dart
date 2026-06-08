import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/services/novel_parser.dart';

const chapterTitle = '\u7b2c\u4e00\u7ae0 \u521d\u89c1';
const firstParagraph = '\u8fd9\u662f\u7b2c\u4e00\u6bb5\u6b63\u6587\u3002';
const secondParagraph = '\u8fd9\u662f\u7b2c\u4e8c\u6bb5\u6b63\u6587\uff01';
const nextPage = '\u4e0b\u4e00\u9875';
const nextChapter = '\u4e0b\u4e00\u7ae0';
const catalog = '\u76ee\u5f55';
const adText =
    '\u5e7f\u544a\uff1a\u8bf7\u4e0b\u8f7dAPP\u7ee7\u7eed\u9605\u8bfb';
const bookmarkTip = '\u8bf7\u6536\u85cf\u672c\u7ad9';

void main() {
  group('NovelParser', () {
    test('extracts clean chapter content and separates page/chapter links', () {
      final parser = NovelParser();
      final parsed = parser.parseChapter('''
        <html>
          <body>
            <nav>\u9996\u9875 \u767b\u5f55</nav>
            <article>
              <h1>$chapterTitle</h1>
              <p>$firstParagraph</p>
              <p>$secondParagraph</p>
              <p>$bookmarkTip</p>
              <div class="ad">$adText</div>
              <a href="/book/1_2.html">$nextPage</a>
              <a href="/book/2.html">$nextChapter</a>
            </article>
            <script>bad()</script>
          </body>
        </html>
        ''', Uri.parse('https://novel.example/book/1.html'));

      expect(parsed.title, chapterTitle);
      expect(parsed.content, contains(firstParagraph));
      expect(parsed.content, contains(secondParagraph));
      expect(parsed.content, isNot(contains(bookmarkTip)));
      expect(parsed.content, isNot(contains(adText)));
      expect(parsed.content, isNot(contains(nextPage)));
      expect(parsed.content, isNot(contains(nextChapter)));
      expect(parsed.content, isNot(contains('bad')));
      expect(parsed.nextPageUrl, 'https://novel.example/book/1_2.html');
      expect(parsed.nextChapterUrl, 'https://novel.example/book/2.html');
    });

    test('extracts catalog links and resolves relative urls', () {
      final parser = NovelParser();
      final chapters = parser.parseCatalog('''
        <a href="1.html">$chapterTitle</a>
        <a href="/book/2.html">\u7b2c2\u7ae0 \u98ce\u8d77</a>
        <a href="/about.html">\u5173\u4e8e\u6211\u4eec</a>
        ''', Uri.parse('https://novel.example/book/index.html'));

      expect(chapters, hasLength(2));
      expect(chapters.first.title, chapterTitle);
      expect(chapters.last.url, 'https://novel.example/book/2.html');
    });

    test('extracts catalog page links for paged chapter lists', () {
      final parser = NovelParser();
      final catalogPage = parser.parseCatalogPage('''
        <a href="1.html">$chapterTitle</a>
        <a href="2.html">\u7b2c\u4e8c\u7ae0 \u98ce\u8d77</a>
        <a href="catalog_2.html">\u4e0b\u4e00\u9875</a>
        ''', Uri.parse('https://novel.example/book/catalog.html'));

      expect(catalogPage.chapters, hasLength(2));
      expect(
        catalogPage.nextPageUrl,
        'https://novel.example/book/catalog_2.html',
      );
    });

    test('filters search results by query and blocked hosts', () {
      final parser = NovelParser();
      final results = parser.parseSearchResults(
        html: '''
        <a href="https://site.example/book">\u6d4b\u8bd5\u5c0f\u8bf4\u5168\u6587\u9605\u8bfb</a>
        <a href="https://www.bing.com/preferences">\u8bbe\u7f6e</a>
        <a href="https://other.example/book">\u65e0\u5173\u6807\u9898</a>
        ''',
        searchUri: Uri.parse('https://www.bing.com/search?q=test'),
        sourceId: 'bing',
        sourceName: 'Bing',
        query: '\u6d4b\u8bd5\u5c0f\u8bf4',
      );

      expect(results, hasLength(1));
      expect(results.single.url, 'https://site.example/book');
    });

    test('unwraps common search redirects before filtering results', () {
      final parser = NovelParser();
      final target = Uri.encodeComponent('https://novel.example/book/1.html');
      final results = parser.parseSearchResults(
        html:
            '''
        <a href="/url?q=$target">\u6d4b\u8bd5\u5c0f\u8bf4\u5168\u6587\u9605\u8bfb</a>
        <a href="https://www.google.com/search?q=again">\u6d4b\u8bd5\u5c0f\u8bf4\u641c\u7d22</a>
        ''',
        searchUri: Uri.parse('https://www.google.com/search?q=test'),
        sourceId: 'google',
        sourceName: 'Google',
        query: '\u6d4b\u8bd5\u5c0f\u8bf4',
      );

      expect(results, hasLength(1));
      expect(results.single.url, 'https://novel.example/book/1.html');
    });
  });
}
