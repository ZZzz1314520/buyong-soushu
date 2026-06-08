# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

不用搜书 (buyong-soushu) 是一个 Flutter 小说搜索与阅读 App。用户通过可配置的搜索引擎源搜索小说，解析任意小说网站的章节目录和正文，将书籍加入书架，并在可定制的阅读界面中阅读。

## Build & test commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Run all tests
flutter test

# Run a single test file
flutter test test/services/novel_parser_test.dart

# Static analysis (linting)
flutter analyze
```

## Agent skills

### Issue tracker

Issues and PRDs are tracked in GitHub Issues for `ZZzz1314520/buyong-soushu`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default five-label triage vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context Flutter app. Read root `CONTEXT.md` and `docs/adr/` if they exist, then proceed silently when they do not. See `docs/agents/domain.md`.

## Architecture

### State management

No third-party state management library. The app uses a single `AppController` (`lib/services/app_controller.dart`) that extends `ChangeNotifier`. It is provided to the widget tree via `ControllerScope` (`lib/services/controller_scope.dart`), a thin `InheritedNotifier<AppController>` wrapper. Widgets access it with `ControllerScope.of(context)`.

`AppController` owns three pieces of state:
- `books` — the user's bookshelf (list of `Book`)
- `sources` — configured search sources (list of `SearchSource`). `LocalLibrary.loadSources()` merges saved user settings with the built-in source catalog so upgrades receive newly added defaults while preserving custom sources and enabled/disabled states.
- `readerSettings` — font size, line height, theme, page-turn mode (`ReaderSettings`)

`AppController` coordinates between `LocalLibrary` (persistence) and `NovelService` (network), saving to local storage on every mutation and calling `notifyListeners()` so the UI rebuilds.

### Data flow

```
UI (Screens)
  ↓ ControllerScope.of(context)
AppController (ChangeNotifier)
  ↓                ↓
LocalLibrary      NovelService
(SharedPrefs)     (http + NovelParser)
```

- **Search**: `SearchScreen` → `controller.search(query)` → `NovelService.searchBooks()` → fetches from each enabled `SearchSource` in parallel, unwraps common search-result redirects, de-duplicates by URL, returns up to 50 results.
- **Add to shelf**: `SearchScreen._add()` → `controller.addResultToShelf()` → `NovelService.buildBookFromResult()` fetches the book page and builds a `Book` with chapter list (or a single chapter if no catalog found).
- **Read**: `ReaderScreen` → `controller.ensureChapterLoaded(book, index)` → `NovelService.loadChapter()` fetches the chapter HTML, follows "next page" links (max 8 pages), concatenates content, and persists the loaded content back to `LocalLibrary`.
- **Next chapter**: When at the last known chapter, `ReaderScreen._goNext()` calls `controller.appendNextChapter()` which uses the current chapter's `nextUrl` to discover and load the next chapter dynamically.

### HTML parsing strategy (`NovelParser`)

The parser is designed to work generically across unknown novel websites — no site-specific rules. Key behaviors:

1. **Content extraction**: Tries 15+ CSS selectors (`#content`, `#chaptercontent`, `article`, `.novel-content`, etc.), scores each candidate by text length + paragraph count − link text − ad elements, picks the best one.
2. **Noise removal**: Strips `script`, `style`, `nav`, `footer`, `header`, `.ads`, `.comments`, pagination links, etc. before extracting readable text.
3. **Pagination**: Detects "下一页" / "next page" links (distinct from "下一章" / "next chapter").
4. **Catalog parsing**: Finds all `<a>` links whose text looks like a chapter title (matches patterns like "第X章/节/回/卷"), deduplicates by resolved URL.
5. **Search parsing**: Scores links by query relevance, unwraps common search redirects (`uddg`, `q`, `url`, `u`, `to`, `target`), filters out search-engine hostnames (Bing, DuckDuckGo, Google, Baidu, Sogou, 360, Brave, Mojeek, etc.) and navigation text.
6. **Boilerplate filtering**: Removes common noise lines like "请收藏本站", "手机用户请浏览", etc.

Top-level helper functions in `novel_models.dart`:
- `normalizeWhitespace()` — collapses all whitespace, trims.
- `stableId()` — produces a URL-safe base64 ID from a string (used for book IDs from URLs).

### Models (`lib/models/novel_models.dart`)

All models are immutable with `copyWith`, have `toJson()`/`factory fromJson()` for persistence.

- `SearchSource` — search source config with `{query}` URL template and enable/disable toggle. Built-in defaults include general web engines, Chinese search engines, and novel-keyword variants such as latest-chapter/full-text/catalog searches.
- `BookSearchResult` — a single search hit (title, URL, source info).
- `Chapter` — title, URL, content (lazy-loaded), and optional `nextUrl` for dynamic discovery.
- `Book` — a saved book with chapter list, current reading position (`currentChapterIndex`), and `lastReadAt`.
- `ReaderSettings` — font size, line height, `ReaderTheme` enum (paper/green/dark/pureWhite), `PageTurnMode` enum. The only active reading mode is horizontal page turning; legacy persisted `verticalScroll` / `tapSides` values are migrated to `horizontalFlip`.
- `ReaderTheme` backgrounds: paper=warm beige, green=light green, dark=near-black, pureWhite=white.

### Screen structure

`HomeShell` is the root screen with a `NavigationBar` (3 tabs):
1. **书架** (`BookshelfScreen`) — book list with read/remove actions. Empty state prompts user to search.
2. **搜书** (`SearchScreen`) — text field + search button, result list with "加入" button per result. Shows enabled source count.
3. **设置** (`SettingsScreen`) — lists search sources with enable/disable toggles, dialog to add new sources with `{query}` URL template.

`ReaderScreen` is pushed as a full route (not a tab). It receives a `bookId`, looks up the book from the controller, loads chapters on demand, and provides:
- Reading settings bottom sheet (font size slider, line height slider, theme segments, flip animation toggle)
- Chapter catalog bottom sheet (tap to jump)
- Previous/next chapter buttons in bottom bar
- Horizontal page turns: left/right swipe changes pages; tapping the left third goes to the previous page, tapping the right third goes to the next page, and tapping the center third does nothing.

## Tests

Tests use `SharedPreferences.setMockInitialValues({})` for the persistence layer and `MockClient` from `package:http/testing.dart` for network calls.

- `test/widget_test.dart` — full integration: search → add → read, plus settings source management. Uses a `_FakeNovelService` that returns canned data.
- `test/services/novel_parser_test.dart` — HTML parsing: content extraction, noise removal, catalog parsing, search result filtering.
- `test/services/novel_service_test.dart` — HTTP-level tests: search deduplication, catalog-based book building, multi-page chapter loading.
- `test/services/app_controller_test.dart` — verifies that `ensureChapterLoaded` persists loaded content.
- `test/services/local_library_test.dart` — round-trip JSON serialization for books, sources, and reader settings.
- `test/android_manifest_test.dart` — verifies INTERNET permission and app label in AndroidManifest.xml.
