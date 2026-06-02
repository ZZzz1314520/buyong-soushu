import 'package:http/http.dart' as http;

import '../models/novel_models.dart';
import 'novel_parser.dart';

class NovelService {
  NovelService({http.Client? client, NovelParser? parser})
    : _client = client ?? http.Client(),
      _parser = parser ?? NovelParser();

  final http.Client _client;
  final NovelParser _parser;

  Future<List<BookSearchResult>> searchBooks(
    String query,
    List<SearchSource> sources,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return [];
    }

    final enabledSources = sources.where((source) => source.enabled).toList();
    final searches = enabledSources.map((source) async {
      final uri = source.buildUri(trimmed);
      try {
        final response = await _client
            .get(uri, headers: const {'User-Agent': _userAgent})
            .timeout(const Duration(seconds: 12));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return <BookSearchResult>[];
        }
        return _parser.parseSearchResults(
          html: response.body,
          searchUri: uri,
          sourceId: source.id,
          sourceName: source.name,
          query: trimmed,
        );
      } catch (_) {
        return <BookSearchResult>[];
      }
    });

    final grouped = await Future.wait(searches);
    final seen = <String>{};
    return grouped
        .expand((result) => result)
        .where((result) => seen.add(result.url))
        .take(50)
        .toList();
  }

  Future<Book> buildBookFromResult(BookSearchResult result) async {
    final uri = Uri.parse(result.url);
    final response = await _client.get(
      uri,
      headers: const {'User-Agent': _userAgent},
    );
    final catalog = _parser.parseCatalog(response.body, uri);

    if (catalog.isNotEmpty) {
      return Book(
        id: stableId(result.url),
        title: result.title,
        url: result.url,
        sourceId: result.sourceId,
        sourceName: result.sourceName,
        chapters: catalog,
      );
    }

    final chapter = await loadChapter(
      Chapter(title: result.title, url: result.url),
    );
    return Book(
      id: stableId(result.url),
      title: result.title,
      url: result.url,
      sourceId: result.sourceId,
      sourceName: result.sourceName,
      chapters: [chapter],
    );
  }

  Future<Chapter> loadChapter(Chapter chapter) async {
    if (chapter.content.trim().isNotEmpty) {
      return chapter;
    }

    final visited = <String>{};
    final parts = <ParsedChapter>[];
    var uri = Uri.parse(chapter.url);

    for (var page = 0; page < 8; page += 1) {
      if (!visited.add(uri.toString())) {
        break;
      }

      final response = await _client.get(
        uri,
        headers: const {'User-Agent': _userAgent},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          '\u7ae0\u8282\u52a0\u8f7d\u5931\u8d25\uff1aHTTP ${response.statusCode}',
        );
      }

      final parsed = _parser.parseChapter(response.body, uri);
      parts.add(parsed);

      final nextPageUrl = parsed.nextPageUrl;
      if (nextPageUrl == null || nextPageUrl.isEmpty) {
        break;
      }
      uri = Uri.parse(nextPageUrl);
    }

    if (parts.isEmpty) {
      throw Exception('\u7ae0\u8282\u52a0\u8f7d\u5931\u8d25');
    }

    final content = parts
        .map((part) => part.content.trim())
        .where((part) => part.isNotEmpty)
        .join('\n\n');
    final nextChapterUrl = parts
        .map((part) => part.nextChapterUrl)
        .whereType<String>()
        .lastOrNull;

    return chapter.copyWith(
      title: parts.first.title.trim().isEmpty
          ? chapter.title
          : parts.first.title,
      content: content,
      nextUrl: nextChapterUrl ?? chapter.nextUrl,
    );
  }

  Future<Chapter?> loadNextFromLink(Chapter chapter) async {
    final nextUrl = chapter.nextUrl;
    if (nextUrl == null || nextUrl.isEmpty) {
      return null;
    }
    return loadChapter(Chapter(title: '\u4e0b\u4e00\u7ae0', url: nextUrl));
  }

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 NovelReader/1.0';
}
