import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/novel_models.dart';

class ParsedChapter {
  const ParsedChapter({
    required this.title,
    required this.content,
    this.nextPageUrl,
    this.nextChapterUrl,
  });

  final String title;
  final String content;
  final String? nextPageUrl;
  final String? nextChapterUrl;
}

class NovelParser {
  static const _contentSelectors = [
    'article',
    'main',
    '#content',
    '#chaptercontent',
    '#chapter-content',
    '#booktxt',
    '#BookText',
    '#read-content',
    '.content',
    '.chapter-content',
    '.chaptercontent',
    '.read-content',
    '.reading-content',
    '.novel-content',
    '.post-content',
    '.entry-content',
    '.book-content',
    '.txt',
    '.book-text',
  ];

  static final _chapterPattern = RegExp(
    '(\\u7b2c.{1,12}[\\u7ae0\\u8282\\u56de\\u5377\\u96c6\\u90e8\\u7bc7]|'
    'chapter\\s*\\d+|\\b\\d+\\s*[.\\u3001-])',
    caseSensitive: false,
  );

  ParsedChapter parseChapter(String html, Uri pageUri) {
    final document = html_parser.parse(html);
    _removeHardNoise(document);

    final title = _extractTitle(document);
    final nextPageUrl = _findDirectionalLink(
      document,
      pageUri,
      includeLabels: const [
        '\u4e0b\u4e00\u9875',
        '\u4e0b\u9875',
        'next page',
        'nextpage',
      ],
      excludeLabels: const [
        '\u4e0b\u4e00\u7ae0',
        '\u4e0b\u7ae0',
        'next chapter',
      ],
    );
    final nextChapterUrl = _findDirectionalLink(
      document,
      pageUri,
      includeLabels: const [
        '\u4e0b\u4e00\u7ae0',
        '\u4e0b\u7ae0',
        'next chapter',
      ],
      excludeLabels: const ['\u4e0b\u4e00\u9875', '\u4e0b\u9875', 'next page'],
    );

    _removeContentNoise(document);
    final contentElement = _bestContentElement(document);
    final content = _extractReadableText(contentElement, title);

    return ParsedChapter(
      title: title.isEmpty ? '\u672a\u547d\u540d\u7ae0\u8282' : title,
      content: content,
      nextPageUrl: nextPageUrl,
      nextChapterUrl: nextChapterUrl,
    );
  }

  List<Chapter> parseCatalog(String html, Uri pageUri) {
    final document = html_parser.parse(html);
    final anchors = document.querySelectorAll('a[href]');
    final seen = <String>{};
    final chapters = <Chapter>[];

    for (final anchor in anchors) {
      final title = normalizeWhitespace(anchor.text);
      final href = anchor.attributes['href'];
      if (href == null || title.length < 2 || !_looksLikeChapterTitle(title)) {
        continue;
      }
      final url = pageUri.resolve(href).toString();
      if (seen.add(url)) {
        chapters.add(Chapter(title: title, url: url));
      }
    }

    return chapters.length >= 2 ? chapters : [];
  }

  List<BookSearchResult> parseSearchResults({
    required String html,
    required Uri searchUri,
    required String sourceId,
    required String sourceName,
    required String query,
  }) {
    final document = html_parser.parse(html);
    final results = <BookSearchResult>[];
    final seen = <String>{};

    for (final anchor in document.querySelectorAll('a[href]')) {
      final title = normalizeWhitespace(anchor.text);
      final href = anchor.attributes['href'];
      if (href == null || title.length < 2 || _isNavigationText(title)) {
        continue;
      }

      final url = _unwrapSearchUrl(searchUri.resolve(href));
      if (url == null || !_isLikelyReadableUrl(url)) {
        continue;
      }

      final score = _scoreSearchTitle(title, query);
      if (score <= 0) {
        continue;
      }

      if (seen.add(url.toString())) {
        final parentText = normalizeWhitespace(anchor.parent?.text ?? '');
        results.add(
          BookSearchResult(
            title: title,
            url: url.toString(),
            sourceId: sourceId,
            sourceName: sourceName,
            snippet: parentText == title ? '' : parentText,
          ),
        );
      }
    }

    results.sort((a, b) {
      final byTitle = _scoreSearchTitle(
        b.title,
        query,
      ).compareTo(_scoreSearchTitle(a.title, query));
      return byTitle == 0 ? a.title.length.compareTo(b.title.length) : byTitle;
    });
    return results.take(30).toList();
  }

  void _removeHardNoise(dom.Document document) {
    for (final element in document.querySelectorAll(
      'script,style,noscript,iframe,svg,canvas',
    )) {
      element.remove();
    }
  }

  void _removeContentNoise(dom.Document document) {
    for (final element in document.querySelectorAll(
      [
        'header',
        'footer',
        'nav',
        'form',
        'button',
        'select',
        'option',
        'input',
        'textarea',
        'aside',
        'a',
        '.ads',
        '.ad',
        '.advertisement',
        '.comment',
        '#comments',
        '.comments',
        '.footer',
        '.header',
        '.breadcrumb',
        '.book-nav',
        '.chapter-nav',
        '.page-nav',
        '.pagination',
        '.pager',
        '.share',
        '.recommend',
        '.related',
        '.tips',
        '.notice',
        '.copyright',
      ].join(','),
    )) {
      element.remove();
    }
  }

  String _extractTitle(dom.Document document) {
    for (final selector in [
      'h1',
      '.chapter-title',
      '.chaptername',
      '.bookname h1',
      '.title',
      'h2',
      'title',
    ]) {
      final text = normalizeWhitespace(
        document.querySelector(selector)?.text ?? '',
      );
      if (text.isNotEmpty && !_isNavigationText(text)) {
        return _cleanTitle(text);
      }
    }
    return '';
  }

  String _cleanTitle(String text) {
    return normalizeWhitespace(
      text.replaceAll(
        RegExp(
          '\\s*[|_]\\s*.*(\\u5c0f\\u8bf4|\\u9605\\u8bfb|\\u4e2d\\u6587).*\$',
        ),
        '',
      ),
    );
  }

  dom.Element _bestContentElement(dom.Document document) {
    final candidates = <dom.Element>[];
    for (final selector in _contentSelectors) {
      candidates.addAll(document.querySelectorAll(selector));
    }
    final root = document.body ?? document.documentElement;
    if (root != null) {
      candidates.add(root);
    }

    if (candidates.isEmpty) {
      final fallback = document.body ?? document.documentElement;
      if (fallback != null) return fallback;
      // Last resort: wrap raw text in a synthetic element
      final wrapper = document.createElement('div');
      wrapper.text = document.body?.text ?? '';
      return wrapper;
    }
    candidates.sort((a, b) {
      return _readableScore(b).compareTo(_readableScore(a));
    });
    return candidates.first;
  }

  int _readableScore(dom.Element element) {
    final text = normalizeWhitespace(element.text);
    final paragraphCount = element.querySelectorAll('p,br').length;
    final linkTextLength = element
        .querySelectorAll('a')
        .fold<int>(
          0,
          (sum, link) => sum + normalizeWhitespace(link.text).length,
        );
    final noisePenalty = element
        .querySelectorAll(
          '.ads,.ad,.comment,.recommend,.related,.footer,.header,.pagination',
        )
        .length;
    return text.length +
        paragraphCount * 150 -
        linkTextLength * 3 -
        noisePenalty * 300;
  }

  String _extractReadableText(dom.Element element, String title) {
    final raw = _textWithBreaks(element);
    final normalized = raw
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u3000', ' ')
        .replaceAll(RegExp('[ \\t]+'), ' ')
        .replaceAll(RegExp('\\n[ \\t]+'), '\n')
        .trim();
    final lines = normalized
        .split(RegExp('(?:\\r?\\n)+'))
        .expand(_splitOverlongLine)
        .map(normalizeWhitespace)
        .map((line) => _stripTitle(line, title))
        .where((line) => line.length >= 2)
        .where((line) => !_isBoilerplateLine(line))
        .toList();

    final deduped = <String>[];
    for (final line in lines) {
      if (deduped.isEmpty || deduped.last != line) {
        deduped.add(line);
      }
    }
    return deduped.join('\n\n');
  }

  Iterable<String> _splitOverlongLine(String line) {
    if (line.length < 180) {
      return [line];
    }
    return line
        .split(RegExp('(?<=[\\u3002\\uff01\\uff1f])'))
        .where((part) => part.trim().isNotEmpty);
  }

  String _stripTitle(String line, String title) {
    if (title.isEmpty) {
      return line;
    }
    if (line == title) {
      return '';
    }
    if (line.startsWith(title) && line.length - title.length < 12) {
      return '';
    }
    return line;
  }

  String _textWithBreaks(dom.Node node) {
    final buffer = StringBuffer();
    void visit(dom.Node current) {
      if (current is dom.Text) {
        buffer.write(current.text);
        return;
      }
      if (current is! dom.Element) {
        for (final child in current.nodes) {
          visit(child);
        }
        return;
      }

      final tag = current.localName?.toLowerCase() ?? '';
      if (const {
        'script',
        'style',
        'noscript',
        'iframe',
        'svg',
        'canvas',
        'a',
        'button',
        'select',
        'option',
        'input',
        'textarea',
        'h1',
        'h2',
        'h3',
        'nav',
        'footer',
        'header',
        'aside',
      }.contains(tag)) {
        return;
      }
      if (tag == 'br') {
        buffer.write('\n');
        return;
      }
      if (_isBlockTag(tag)) {
        buffer.write('\n');
      }
      for (final child in current.nodes) {
        visit(child);
      }
      if (_isBlockTag(tag)) {
        buffer.write('\n');
      }
    }

    visit(node);
    return buffer.toString();
  }

  bool _isBlockTag(String tag) {
    return const {
      'article',
      'main',
      'section',
      'div',
      'p',
      'li',
      'tr',
      'blockquote',
    }.contains(tag);
  }

  String? _findDirectionalLink(
    dom.Document document,
    Uri pageUri, {
    required List<String> includeLabels,
    List<String> excludeLabels = const [],
  }) {
    for (final anchor in document.querySelectorAll('a[href]')) {
      final text = normalizeWhitespace(anchor.text).toLowerCase();
      if (text.isEmpty || _isDisabledLink(anchor)) {
        continue;
      }
      final hasIncluded = includeLabels.any(
        (label) => text.contains(label.toLowerCase()),
      );
      final hasExcluded = excludeLabels.any(
        (label) => text.contains(label.toLowerCase()),
      );
      if (hasIncluded && !hasExcluded) {
        return pageUri.resolve(anchor.attributes['href']!).toString();
      }
    }
    return null;
  }

  bool _isDisabledLink(dom.Element anchor) {
    final href = anchor.attributes['href'] ?? '';
    final className = anchor.attributes['class'] ?? '';
    return href == '#' ||
        href.toLowerCase().startsWith('javascript:') ||
        className.toLowerCase().contains('disabled');
  }

  bool _looksLikeChapterTitle(String title) {
    if (title.length > 60) {
      return false;
    }
    return _chapterPattern.hasMatch(title) ||
        title.contains('\u5e8f\u7ae0') ||
        title.contains('\u6954\u5b50') ||
        title.contains('\u756a\u5916');
  }

  bool _isNavigationText(String title) {
    const blocked = [
      '\u56fe\u7247',
      '\u89c6\u9891',
      '\u767b\u5f55',
      '\u6ce8\u518c',
      '\u7f13\u5b58',
      '\u5e7f\u544a',
      '\u9996\u9875',
      '\u8bbe\u7f6e',
      '\u76ee\u5f55',
    ];
    return blocked.any(title.contains);
  }

  bool _isBoilerplateLine(String line) {
    final lower = line.toLowerCase();
    const blocked = [
      '\u4e0a\u4e00\u7ae0',
      '\u4e0b\u4e00\u7ae0',
      '\u4e0b\u4e00\u9875',
      '\u4e0a\u4e00\u9875',
      '\u8fd4\u56de\u76ee\u5f55',
      '\u7ae0\u8282\u76ee\u5f55',
      '\u70b9\u51fb\u4e0b\u4e00\u9875',
      '\u672c\u7ae0\u672a\u5b8c',
      '\u8bf7\u6536\u85cf',
      '\u52a0\u5165\u4e66\u7b7e',
      '\u6700\u65b0\u7f51\u5740',
      '\u8bf7\u8bb0\u4f4f',
      '\u624b\u673a\u7528\u6237',
      '\u4e66\u53cb\u7fa4',
      '\u63a8\u8350\u9605\u8bfb',
      '\u76f8\u5173\u63a8\u8350',
      '\u70ed\u95e8\u63a8\u8350',
      '\u4f5c\u8005\u6709\u8bdd\u8bf4',
      '\u6e29\u99a8\u63d0\u793a',
      '\u6295\u7968',
      '\u6253\u8d4f',
      '\u8bc4\u8bba',
      '\u62a5\u9519',
      '\u5e7f\u544a',
      '\u5929\u624d\u4e00\u79d2\u8bb0\u4f4f',
      'advertisement',
      'chapter list',
      'bookmarks',
    ];
    if (blocked.any(line.contains)) {
      return true;
    }
    if (lower.contains('http://') || lower.contains('https://')) {
      return true;
    }
    return line.length <= 10 &&
        (line.contains('\u76ee\u5f55') ||
            line.contains('\u9996\u9875') ||
            line.contains('\u4e66\u67b6'));
  }

  Uri? _unwrapSearchUrl(Uri uri) {
    if (uri.host.contains('bing.com') && uri.path == '/ck/a') {
      final target = uri.queryParameters['u'];
      if (target != null) {
        return Uri.tryParse(target);
      }
    }
    if (uri.host.contains('duckduckgo.com') &&
        uri.queryParameters['uddg'] != null) {
      return Uri.tryParse(uri.queryParameters['uddg']!);
    }
    if (uri.host.contains('google.') && uri.path == '/url') {
      final target = uri.queryParameters['q'];
      if (target != null) {
        return Uri.tryParse(target);
      }
    }
    for (final parameter in const ['url', 'u', 'to', 'target']) {
      final target = uri.queryParameters[parameter];
      if (target == null || !target.startsWith(RegExp('https?://'))) {
        continue;
      }
      final parsed = Uri.tryParse(target);
      if (parsed != null && !_isSearchHost(parsed.host)) {
        return parsed;
      }
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return uri;
    }
    return null;
  }

  bool _isLikelyReadableUrl(Uri uri) {
    if (uri.host.isEmpty) {
      return false;
    }
    return !_isSearchHost(uri.host) && !_isBlockedReadableHost(uri.host);
  }

  bool _isSearchHost(String host) {
    const blockedHosts = [
      'bing.com',
      'duckduckgo.com',
      'google.com',
      'google.com.hk',
      'baidu.com',
      'sogou.com',
      'so.com',
      'sm.cn',
      'brave.com',
      'mojeek.com',
      'qwant.com',
      'startpage.com',
      'ecosia.org',
      'yep.com',
      'yandex.com',
      'yahoo.com',
    ];
    return blockedHosts.any((blocked) => _hostMatches(host, blocked));
  }

  bool _isBlockedReadableHost(String host) {
    const blockedHosts = ['wikipedia.org'];
    return blockedHosts.any((blocked) => _hostMatches(host, blocked));
  }

  bool _hostMatches(String host, String blocked) {
    final lowerHost = host.toLowerCase();
    final lowerBlocked = blocked.toLowerCase();
    return lowerHost == lowerBlocked || lowerHost.endsWith('.$lowerBlocked');
  }

  int _scoreSearchTitle(String title, String query) {
    final lowerTitle = title.toLowerCase();
    final lowerQuery = query.toLowerCase();
    var score = 0;
    if (lowerTitle.contains(lowerQuery)) {
      score += 10;
    }
    if (title.contains('\u5c0f\u8bf4') ||
        title.contains('\u7ae0\u8282') ||
        title.contains('\u5168\u6587')) {
      score += 3;
    }
    if (_looksLikeChapterTitle(title)) {
      score += 1;
    }
    return score;
  }
}
