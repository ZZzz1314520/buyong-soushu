import 'package:flutter/material.dart';

import '../models/novel_models.dart';
import '../services/controller_scope.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  var _chapterIndex = 0;
  var _loading = true;
  String? _error;
  Chapter? _chapter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final book = _bookOrNull();
      if (book != null) {
        _chapterIndex = book.currentChapterIndex;
      }
      _loadChapter();
    });
  }

  Book? _bookOrNull() {
    final controller = ControllerScope.of(context);
    for (final book in controller.books) {
      if (book.id == widget.bookId) {
        return book;
      }
    }
    return null;
  }

  Future<void> _loadChapter() async {
    final controller = ControllerScope.of(context);
    final book = _bookOrNull();
    if (book == null) {
      setState(() {
        _loading = false;
        _error = '书籍不在书架中';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final chapter = await controller.ensureChapterLoaded(book, _chapterIndex);
      if (!mounted) {
        return;
      }
      setState(() {
        _chapter = chapter;
        _chapterIndex = _chapterIndex
            .clamp(0, book.chapters.length - 1)
            .toInt();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _goPrevious() async {
    if (_chapterIndex <= 0) {
      return;
    }
    setState(() => _chapterIndex -= 1);
    await _loadChapter();
  }

  Future<void> _goNext() async {
    var book = _bookOrNull();
    if (book == null || book.chapters.isEmpty) {
      return;
    }

    if (_chapterIndex < book.chapters.length - 1) {
      setState(() => _chapterIndex += 1);
      await _loadChapter();
      return;
    }

    final controller = ControllerScope.of(context);
    final appended = await controller.appendNextChapter(book);
    if (appended != null) {
      book = appended;
      setState(() => _chapterIndex = book!.chapters.length - 1);
      await _loadChapter();
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已经是最后一章')));
    }
  }

  void _showCatalog(Book book) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView.builder(
          itemCount: book.chapters.length,
          itemBuilder: (context, index) {
            final chapter = book.chapters[index];
            return ListTile(
              selected: index == _chapterIndex,
              title: Text(
                chapter.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _chapterIndex = index);
                _loadChapter();
              },
            );
          },
        );
      },
    );
  }

  void _showReaderSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _ReaderSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ControllerScope.of(context);
    final book = _bookOrNull();
    final settings = controller.readerSettings;
    final colors = _readerColors(settings.theme);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        title: Text(
          book?.title ?? '阅读',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '阅读设置',
            onPressed: _showReaderSettings,
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: '目录',
            onPressed: book == null || book.chapters.isEmpty
                ? null
                : () => _showCatalog(book),
            icon: const Icon(Icons.format_list_bulleted),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('正在缓存本章内容...'),
                ],
              ),
            )
          : _error != null
          ? Center(child: Text(_error!))
          : _ReaderBody(
              title: _chapter?.title ?? '',
              content: _chapter?.content ?? '',
              settings: settings,
              colors: colors,
              onPrevious: _goPrevious,
              onNext: _goNext,
            ),
      bottomNavigationBar: book == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _chapterIndex <= 0 ? null : _goPrevious,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('上一章'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_chapterIndex + 1}/${book.chapters.length}',
                      style: TextStyle(
                        color: colors.foreground.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _goNext,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('下一章'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({
    required this.title,
    required this.content,
    required this.settings,
    required this.colors,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final String content;
  final ReaderSettings settings;
  final _ReaderColors colors;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.foreground,
              fontSize: settings.fontSize + 4,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          SelectableText(
            content.isEmpty ? '正文解析为空，请尝试在目录中选择其他章节。' : content,
            style: TextStyle(
              color: colors.foreground,
              fontSize: settings.fontSize,
              height: settings.lineHeight,
            ),
          ),
        ],
      ),
    );

    if (settings.pageTurnMode != PageTurnMode.tapSides) {
      return body;
    }

    return Stack(
      children: [
        body,
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onPrevious,
                child: const SizedBox.expand(),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onNext,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReaderSettingsSheet extends StatelessWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final controller = ControllerScope.of(context);
    final settings = controller.readerSettings;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '阅读设置',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    controller.updateReaderSettings(const ReaderSettings()),
                icon: const Icon(Icons.restart_alt),
                label: const Text('重置'),
              ),
            ],
          ),
          ListTile(
            title: const Text('字体大小'),
            subtitle: Slider(
              min: 16,
              max: 30,
              divisions: 14,
              value: settings.fontSize,
              label: settings.fontSize.round().toString(),
              onChanged: (value) => controller.updateReaderSettings(
                settings.copyWith(fontSize: value),
              ),
            ),
            trailing: Text('${settings.fontSize.round()}'),
          ),
          ListTile(
            title: const Text('行间距'),
            subtitle: Slider(
              min: 1.3,
              max: 2,
              divisions: 7,
              value: settings.lineHeight,
              label: settings.lineHeight.toStringAsFixed(1),
              onChanged: (value) => controller.updateReaderSettings(
                settings.copyWith(lineHeight: value),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ReaderTheme>(
            segments: const [
              ButtonSegment(value: ReaderTheme.paper, label: Text('米黄')),
              ButtonSegment(value: ReaderTheme.green, label: Text('护眼')),
              ButtonSegment(value: ReaderTheme.pureWhite, label: Text('白天')),
              ButtonSegment(value: ReaderTheme.dark, label: Text('夜间')),
            ],
            selected: {settings.theme},
            onSelectionChanged: (selected) => controller.updateReaderSettings(
              settings.copyWith(theme: selected.first),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<PageTurnMode>(
            segments: const [
              ButtonSegment(
                value: PageTurnMode.verticalScroll,
                label: Text('滚动'),
              ),
              ButtonSegment(value: PageTurnMode.tapSides, label: Text('点击翻章')),
            ],
            selected: {settings.pageTurnMode},
            onSelectionChanged: (selected) => controller.updateReaderSettings(
              settings.copyWith(pageTurnMode: selected.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderColors {
  const _ReaderColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

_ReaderColors _readerColors(ReaderTheme theme) {
  switch (theme) {
    case ReaderTheme.green:
      return const _ReaderColors(Color(0xffeef7e8), Color(0xff20281f));
    case ReaderTheme.dark:
      return const _ReaderColors(Color(0xff11100f), Color(0xffd8d0c7));
    case ReaderTheme.pureWhite:
      return const _ReaderColors(Colors.white, Color(0xff181614));
    case ReaderTheme.paper:
      return const _ReaderColors(Color(0xfffff3df), Color(0xff221914));
  }
}
