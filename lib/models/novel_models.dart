import 'dart:convert';

String normalizeWhitespace(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String stableId(String value) {
  return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
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
      id: json['id'] as String,
      name: json['name'] as String,
      urlTemplate: json['urlTemplate'] as String,
      enabled: json['enabled'] as bool? ?? true,
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
      title: json['title'] as String,
      url: json['url'] as String,
      content: json['content'] as String? ?? '',
      nextUrl: json['nextUrl'] as String?,
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
  });

  final String id;
  final String title;
  final String url;
  final String sourceId;
  final String sourceName;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final DateTime? lastReadAt;

  Book copyWith({
    String? id,
    String? title,
    String? url,
    String? sourceId,
    String? sourceName,
    List<Chapter>? chapters,
    int? currentChapterIndex,
    DateTime? lastReadAt,
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
    };
  }

  factory Book.fromJson(Map<String, Object?> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      sourceId: json['sourceId'] as String,
      sourceName: json['sourceName'] as String,
      chapters: (json['chapters'] as List<dynamic>? ?? [])
          .map((chapter) => Chapter.fromJson(chapter as Map<String, Object?>))
          .toList(),
      currentChapterIndex: json['currentChapterIndex'] as int? ?? 0,
      lastReadAt: json['lastReadAt'] == null
          ? null
          : DateTime.parse(json['lastReadAt'] as String),
    );
  }
}

enum ReaderTheme { paper, green, dark, pureWhite }

enum PageTurnMode { verticalScroll, tapSides }

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 20,
    this.lineHeight = 1.65,
    this.theme = ReaderTheme.paper,
    this.pageTurnMode = PageTurnMode.verticalScroll,
  });

  final double fontSize;
  final double lineHeight;
  final ReaderTheme theme;
  final PageTurnMode pageTurnMode;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    ReaderTheme? theme,
    PageTurnMode? pageTurnMode,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      theme: theme ?? this.theme,
      pageTurnMode: pageTurnMode ?? this.pageTurnMode,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'theme': theme.name,
      'pageTurnMode': pageTurnMode.name,
    };
  }

  factory ReaderSettings.fromJson(Map<String, Object?> json) {
    return ReaderSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 20,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.65,
      theme: ReaderTheme.values.firstWhere(
        (theme) => theme.name == json['theme'],
        orElse: () => ReaderTheme.paper,
      ),
      pageTurnMode: PageTurnMode.values.firstWhere(
        (mode) => mode.name == json['pageTurnMode'],
        orElse: () => PageTurnMode.verticalScroll,
      ),
    );
  }
}

const defaultSources = [
  SearchSource(
    id: 'bing',
    name: 'Bing',
    urlTemplate: 'https://www.bing.com/search?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
  SearchSource(
    id: 'duckduckgo',
    name: 'DuckDuckGo',
    urlTemplate: 'https://duckduckgo.com/html/?q={query}%20%E5%B0%8F%E8%AF%B4',
  ),
];
