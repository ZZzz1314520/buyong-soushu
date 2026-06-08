import 'dart:convert';

String normalizeWhitespace(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String stableId(String value) {
  return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
}

String _safeString(dynamic value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

bool _safeBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  return fallback;
}

int _safeInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

double _safeDouble(dynamic value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return fallback;
}

class SearchSource {
  const SearchSource({
    required this.id,
    required this.name,
    required this.urlTemplate,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String urlTemplate;
  final bool enabled;

  Uri buildUri(String query) {
    final encoded = Uri.encodeComponent(query);
    return Uri.parse(urlTemplate.replaceAll('{query}', encoded));
  }

  SearchSource copyWith({
    String? id,
    String? name,
    String? urlTemplate,
    bool? enabled,
  }) {
    return SearchSource(
      id: id ?? this.id,
      name: name ?? this.name,
      urlTemplate: urlTemplate ?? this.urlTemplate,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'urlTemplate': urlTemplate,
      'enabled': enabled,
    };
  }

  factory SearchSource.fromJson(Map<String, Object?> json) {
    return SearchSource(
      id: _safeString(json['id'], 'unknown'),
      name: _safeString(json['name'], '未命名来源'),
      urlTemplate: _safeString(json['urlTemplate'], ''),
      enabled: _safeBool(json['enabled'], true),
    );
  }
}

class BookSearchResult {
  const BookSearchResult({
    required this.title,
    required this.url,
    required this.sourceId,
    required this.sourceName,
    this.snippet = '',
  });

  final String title;
  final String url;
  final String sourceId;
  final String sourceName;
  final String snippet;
}

class Chapter {
  const Chapter({
    required this.title,
    required this.url,
    this.content = '',
    this.nextUrl,
  });

  final String title;
  final String url;
  final String content;
  final String? nextUrl;

  Chapter copyWith({
    String? title,
    String? url,
    String? content,
    String? nextUrl,
  }) {
    return Chapter(
      title: title ?? this.title,
      url: url ?? this.url,
      content: content ?? this.content,
      nextUrl: nextUrl ?? this.nextUrl,
    );
  }

  Map<String, Object?> toJson() {
    return {'title': title, 'url': url, 'content': content, 'nextUrl': nextUrl};
  }

  factory Chapter.fromJson(Map<String, Object?> json) {
    return Chapter(
      title: _safeString(json['title'], '未命名章节'),
      url: _safeString(json['url'], ''),
      content: _safeString(json['content']),
      nextUrl: json['nextUrl'] is String ? json['nextUrl'] as String : null,
    );
  }
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.url,
    required this.sourceId,
    required this.sourceName,
    this.chapters = const [],
    this.currentChapterIndex = 0,
    this.lastReadAt,
    this.scrollPosition = 0,
    this.chapterProgress = 0,
  });

  final String id;
  final String title;
  final String url;
  final String sourceId;
  final String sourceName;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final DateTime? lastReadAt;
  final double scrollPosition;
  final double chapterProgress; // current page index in flip mode

  Book copyWith({
    String? id,
    String? title,
    String? url,
    String? sourceId,
    String? sourceName,
    List<Chapter>? chapters,
    int? currentChapterIndex,
    DateTime? lastReadAt,
    double? scrollPosition,
    double? chapterProgress,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      chapters: chapters ?? this.chapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      chapterProgress: chapterProgress ?? this.chapterProgress,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'sourceId': sourceId,
      'sourceName': sourceName,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
      'currentChapterIndex': currentChapterIndex,
      'lastReadAt': lastReadAt?.toIso8601String(),
      'scrollPosition': scrollPosition,
      'chapterProgress': chapterProgress,
    };
  }

  factory Book.fromJson(Map<String, Object?> json) {
    return Book(
      id: _safeString(json['id'], 'unknown'),
      title: _safeString(json['title'], '未命名书籍'),
      url: _safeString(json['url'], ''),
      sourceId: _safeString(json['sourceId'], 'unknown'),
      sourceName: _safeString(json['sourceName'], '未知来源'),
      chapters: (json['chapters'] as List<dynamic>? ?? [])
          .map((chapter) => Chapter.fromJson(chapter as Map<String, Object?>))
          .toList(),
      currentChapterIndex: _safeInt(json['currentChapterIndex']),
      lastReadAt: json['lastReadAt'] is String
          ? DateTime.tryParse(json['lastReadAt'] as String)
          : null,
      scrollPosition: _safeDouble(json['scrollPosition']),
      chapterProgress: _safeDouble(json['chapterProgress']),
    );
  }
}

enum ReaderTheme { paper, green, dark, pureWhite }

enum PageTurnMode { verticalScroll, tapSides, horizontalFlip }

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 20,
    this.lineHeight = 1.65,
    this.theme = ReaderTheme.paper,
    this.pageTurnMode = PageTurnMode.horizontalFlip,
    this.enableFlipAnimation = true,
  });

  final double fontSize;
  final double lineHeight;
  final ReaderTheme theme;
  final PageTurnMode pageTurnMode;
  final bool enableFlipAnimation;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    ReaderTheme? theme,
    PageTurnMode? pageTurnMode,
    bool? enableFlipAnimation,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      theme: theme ?? this.theme,
      pageTurnMode: pageTurnMode ?? this.pageTurnMode,
      enableFlipAnimation: enableFlipAnimation ?? this.enableFlipAnimation,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'theme': theme.name,
      'pageTurnMode': pageTurnMode.name,
      'enableFlipAnimation': enableFlipAnimation,
    };
  }

  factory ReaderSettings.fromJson(Map<String, Object?> json) {
    return ReaderSettings(
      fontSize: _safeDouble(json['fontSize'], 20),
      lineHeight: _safeDouble(json['lineHeight'], 1.65),
      theme: ReaderTheme.values.firstWhere(
        (theme) => theme.name == json['theme'],
        orElse: () => ReaderTheme.paper,
      ),
      pageTurnMode: PageTurnMode.horizontalFlip,
      enableFlipAnimation: _safeBool(json['enableFlipAnimation'], true),
    );
  }
}

bool isDefaultSourceId(String sourceId) {
  return _defaultSourceIds.contains(sourceId);
}

List<SearchSource> mergeDefaultSources(List<SearchSource> savedSources) {
  if (savedSources.isEmpty) {
    return defaultSources;
  }

  final savedById = {
    for (final source in savedSources)
      if (source.id.trim().isNotEmpty) source.id: source,
  };
  final merged = <SearchSource>[];

  for (final source in defaultSources) {
    final saved = savedById.remove(source.id);
    merged.add(source.copyWith(enabled: saved?.enabled));
  }

  merged.addAll(
    savedById.values.where(
      (source) =>
          source.name.trim().isNotEmpty &&
          source.urlTemplate.contains('{query}'),
    ),
  );
  return merged;
}

final _defaultSourceIds = defaultSources.map((source) => source.id).toSet();

const defaultSources = [
  SearchSource(
    id: 'bing',
    name: 'Bing 小说',
    urlTemplate: 'https://www.bing.com/search?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'bing-cn',
    name: 'Bing 国内',
    urlTemplate: 'https://cn.bing.com/search?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'duckduckgo',
    name: 'DuckDuckGo 小说',
    urlTemplate: 'https://duckduckgo.com/html/?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'duckduckgo-lite',
    name: 'DuckDuckGo Lite',
    urlTemplate:
        'https://lite.duckduckgo.com/lite/?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'brave',
    name: 'Brave Search',
    urlTemplate:
        'https://search.brave.com/search?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'mojeek',
    name: 'Mojeek',
    urlTemplate: 'https://www.mojeek.com/search?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'qwant',
    name: 'Qwant',
    urlTemplate: 'https://www.qwant.com/?q={query}%20%E5%B0%8F%E8%AF%B4&t=web',
  ),
  SearchSource(
    id: 'startpage',
    name: 'Startpage',
    urlTemplate:
        'https://www.startpage.com/sp/search?query={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'ecosia',
    name: 'Ecosia',
    urlTemplate: 'https://www.ecosia.org/search?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'yep',
    name: 'Yep',
    urlTemplate: 'https://yep.com/web?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'yandex',
    name: 'Yandex',
    urlTemplate: 'https://yandex.com/search/?text={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'yahoo',
    name: 'Yahoo',
    urlTemplate:
        'https://search.yahoo.com/search?p={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'google',
    name: 'Google',
    urlTemplate: 'https://www.google.com/search?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'baidu',
    name: '百度',
    urlTemplate: 'https://www.baidu.com/s?wd={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'sogou',
    name: '搜狗',
    urlTemplate: 'https://www.sogou.com/web?query={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'so360',
    name: '360 搜索',
    urlTemplate: 'https://www.so.com/s?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'sm',
    name: '神马搜索',
    urlTemplate: 'https://yz.m.sm.cn/s?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'bing-latest',
    name: 'Bing 最新章节',
    urlTemplate:
        'https://www.bing.com/search?q={query}%20%E6%9C%80%E6%96%B0%E7%AB%A0%E8%8A%82',
  ),
  SearchSource(
    id: 'bing-fulltext',
    name: 'Bing 全文阅读',
    urlTemplate:
        'https://www.bing.com/search?q={query}%20%E5%85%A8%E6%96%87%E9%98%85%E8%AF%BB',
  ),
  SearchSource(
    id: 'bing-catalog',
    name: 'Bing 章节目录',
    urlTemplate:
        'https://www.bing.com/search?q={query}%20%E7%AB%A0%E8%8A%82%E7%9B%AE%E5%BD%95',
  ),
  SearchSource(
    id: 'duckduckgo-latest',
    name: 'DuckDuckGo 最新章节',
    urlTemplate:
        'https://duckduckgo.com/html/?q={query}%20%E6%9C%80%E6%96%B0%E7%AB%A0%E8%8A%82',
  ),
  SearchSource(
    id: 'duckduckgo-fulltext',
    name: 'DuckDuckGo 全文阅读',
    urlTemplate:
        'https://duckduckgo.com/html/?q={query}%20%E5%85%A8%E6%96%87%E9%98%85%E8%AF%BB',
  ),
  SearchSource(
    id: 'brave-latest',
    name: 'Brave 最新章节',
    urlTemplate:
        'https://search.brave.com/search?q={query}%20%E6%9C%80%E6%96%B0%E7%AB%A0%E8%8A%82',
  ),
  SearchSource(
    id: 'baidu-latest',
    name: '百度 最新章节',
    urlTemplate:
        'https://www.baidu.com/s?wd={query}%20%E6%9C%80%E6%96%B0%E7%AB%A0%E8%8A%82',
  ),
  SearchSource(
    id: 'sogou-fulltext',
    name: '搜狗 全文阅读',
    urlTemplate:
        'https://www.sogou.com/web?query={query}%20%E5%85%A8%E6%96%87%E9%98%85%E8%AF%BB',
  ),
];
