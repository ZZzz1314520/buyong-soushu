import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_reader/models/novel_models.dart';
import 'package:novel_reader/services/novel_service.dart';

void main() {
  test(
    'NovelService searches enabled sources and de-duplicates urls',
    () async {
      const query = '\u6d4b\u8bd5\u5c0f\u8bf4';
      const title = '\u6d4b\u8bd5\u5c0f\u8bf4\u5168\u6587\u9605\u8bfb';
      const sourceName = '\u6765\u6e90\u4e00';
      final service = NovelService(
        client: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode('''
          <a href="https://novel.example/book">$title</a>
          <a href="https://novel.example/book">$query latest</a>
          '''),
            200,
            headers: const {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );

      final results = await service.searchBooks(query, const [
        SearchSource(
          id: 'one',
          name: sourceName,
          urlTemplate: 'https://search.example?q={query}',
        ),
        SearchSource(
          id: 'disabled',
          name: 'disabled',
          urlTemplate: 'https://disabled.example?q={query}',
          enabled: false,
        ),
      ]);

      expect(results, hasLength(1));
      expect(results.single.title, contains(query));
      expect(results.single.sourceName, sourceName);
    },
  );

  test('NovelService builds a book from catalog when catalog exists', () async {
    const bookTitle = '\u6d4b\u8bd5\u5c0f\u8bf4';
    const chapterOne = '\u7b2c\u4e00\u7ae0 \u521d\u89c1';
    const chapterTwo = '\u7b2c\u4e8c\u7ae0 \u98ce\u8d77';
    final service = NovelService(
      client: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode('''
          <a href="1.html">$chapterOne</a>
          <a href="2.html">$chapterTwo</a>
          '''),
          200,
          headers: const {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );

    final book = await service.buildBookFromResult(
      const BookSearchResult(
        title: bookTitle,
        url: 'https://novel.example/book/index.html',
        sourceId: 'test',
        sourceName: 'test source',
      ),
    );

    expect(book.title, bookTitle);
    expect(book.chapters, hasLength(2));
    expect(book.chapters.first.url, 'https://novel.example/book/1.html');
  });

  test(
    'NovelService follows paged catalog links when building a book',
    () async {
      const bookTitle = '\u6d4b\u8bd5\u5c0f\u8bf4';
      final requested = <Uri>[];
      final service = NovelService(
        client: MockClient((request) async {
          requested.add(request.url);
          if (request.url.path.endsWith('catalog_2.html')) {
            return http.Response.bytes(
              utf8.encode('''
            <a href="21.html">\u7b2c\u4e8c\u5341\u4e00\u7ae0 \u518d\u8d77</a>
            <a href="22.html">\u7b2c\u4e8c\u5341\u4e8c\u7ae0 \u8fdc\u884c</a>
            '''),
              200,
              headers: const {'content-type': 'text/html; charset=utf-8'},
            );
          }
          return http.Response.bytes(
            utf8.encode('''
          <a href="1.html">\u7b2c\u4e00\u7ae0 \u521d\u89c1</a>
          <a href="2.html">\u7b2c\u4e8c\u7ae0 \u98ce\u8d77</a>
          <a href="catalog_2.html">\u4e0b\u4e00\u9875</a>
          '''),
            200,
            headers: const {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );

      final book = await service.buildBookFromResult(
        const BookSearchResult(
          title: bookTitle,
          url: 'https://novel.example/book/catalog.html',
          sourceId: 'test',
          sourceName: 'test source',
        ),
      );

      expect(requested.map((uri) => uri.path), [
        '/book/catalog.html',
        '/book/catalog_2.html',
      ]);
      expect(book.chapters, hasLength(4));
      expect(book.chapters.last.url, 'https://novel.example/book/22.html');
    },
  );

  test('NovelService loads and caches all pages in one chapter', () async {
    const chapterTitle = '\u7b2c\u4e00\u7ae0 \u521d\u89c1';
    const firstPage = '\u7b2c\u4e00\u9875\u6b63\u6587\u3002';
    const secondPage = '\u7b2c\u4e8c\u9875\u6b63\u6587\u3002';
    const nextPage = '\u4e0b\u4e00\u9875';
    const nextChapter = '\u4e0b\u4e00\u7ae0';
    final requested = <Uri>[];
    final service = NovelService(
      client: MockClient((request) async {
        requested.add(request.url);
        if (request.url.path.endsWith('1.html')) {
          return http.Response.bytes(
            utf8.encode('''
            <article>
              <h1>$chapterTitle</h1>
              <p>$firstPage</p>
              <a href="1_2.html">$nextPage</a>
            </article>
            '''),
            200,
            headers: const {'content-type': 'text/html; charset=utf-8'},
          );
        }
        return http.Response.bytes(
          utf8.encode('''
          <article>
            <h1>$chapterTitle</h1>
            <p>$secondPage</p>
            <a href="2.html">$nextChapter</a>
          </article>
          '''),
          200,
          headers: const {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );

    final chapter = await service.loadChapter(
      const Chapter(
        title: chapterTitle,
        url: 'https://novel.example/book/1.html',
      ),
    );

    expect(requested, hasLength(2));
    expect(chapter.content, contains(firstPage));
    expect(chapter.content, contains(secondPage));
    expect(chapter.nextUrl, 'https://novel.example/book/2.html');
  });
}
