import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  var _loadingChapter = false;
  String? _error;
  Chapter? _chapter;

  int _flipPageIndex = 0; // current page in flip mode
  var _controlsVisible = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final book = _bookOrNull();
      if (book != null) {
        _chapterIndex = book.currentChapterIndex;
      }
      _loadChapter();
    });
  }

  @override
  void dispose() {
    _savePosition();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _savePosition() async {
    final book = _bookOrNull();
    if (book == null) return;
    final controller = ControllerScope.of(context);
    final progress = _flipPageIndex.toDouble();
    await controller.updateBook(book.copyWith(chapterProgress: progress));
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
      final shouldRestorePage = _chapterIndex == book.currentChapterIndex;
      final chapter = await controller.ensureChapterLoaded(book, _chapterIndex);
      if (!mounted) {
        return;
      }
      setState(() {
        _chapter = chapter;
        _chapterIndex = _chapterIndex
            .clamp(0, book.chapters.length - 1)
            .toInt();
        _flipPageIndex = shouldRestorePage ? book.chapterProgress.round() : 0;
      });
      // Pre-fetch next chapter in background
      controller.prefetchChapter(book, _chapterIndex + 1);
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
    if (_loadingChapter || _chapterIndex <= 0) {
      return;
    }
    _loadingChapter = true;
    try {
      await _savePosition();
      setState(() => _chapterIndex -= 1);
      await _loadChapter();
    } finally {
      _loadingChapter = false;
    }
  }

  Future<void> _goNext() async {
    if (_loadingChapter) return;

    var book = _bookOrNull();
    if (book == null || book.chapters.isEmpty) {
      return;
    }

    _loadingChapter = true;
    try {
      if (_chapterIndex < book.chapters.length - 1) {
        await _savePosition();
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
    } catch (error) {
      if (mounted) {
        setState(() => _error = '加载下一章失败：$error');
      }
    } finally {
      _loadingChapter = false;
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
                _savePosition();
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

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ControllerScope.of(context);
    final book = _bookOrNull();
    final settings = controller.readerSettings;
    final colors = _readerColors(settings.theme);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _controlsVisible
          ? AppBar(
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
            )
          : null,
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
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _loadChapter,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          : _ReaderBody(
              title: _chapter?.title ?? '',
              content: _chapter?.content ?? '',
              settings: settings,
              colors: colors,
              initialPage: _flipPageIndex,
              onFlipPageChanged: (page) => _flipPageIndex = page,
              onToggleControls: _toggleControls,
              onPrevious: _goPrevious,
              onNext: _goNext,
            ),
      bottomNavigationBar: book == null || !_controlsVisible
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
                        onPressed: (book.chapters.isEmpty || _loadingChapter)
                            ? null
                            : _goNext,
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
    required this.initialPage,
    required this.onFlipPageChanged,
    required this.onToggleControls,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final String content;
  final ReaderSettings settings;
  final _ReaderColors colors;
  final int initialPage;
  final ValueChanged<int> onFlipPageChanged;
  final VoidCallback onToggleControls;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _HorizontalReader(
      title: title,
      content: content,
      settings: settings,
      colors: colors,
      initialPage: initialPage,
      onFlipPageChanged: onFlipPageChanged,
      onToggleControls: onToggleControls,
      onPreviousChapter: onPrevious,
      onNextChapter: onNext,
    );
  }
}

// ─── Horizontal page-flip reader ─────────────────────────────────────────

class _HorizontalReader extends StatefulWidget {
  const _HorizontalReader({
    required this.title,
    required this.content,
    required this.settings,
    required this.colors,
    required this.initialPage,
    required this.onFlipPageChanged,
    required this.onToggleControls,
    required this.onPreviousChapter,
    required this.onNextChapter,
  });

  final String title;
  final String content;
  final ReaderSettings settings;
  final _ReaderColors colors;
  final int initialPage;
  final ValueChanged<int> onFlipPageChanged;
  final VoidCallback onToggleControls;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;

  @override
  State<_HorizontalReader> createState() => _HorizontalReaderState();
}

class _HorizontalReaderState extends State<_HorizontalReader> {
  static const double _horizontalPadding = 20;
  static const double _titleTopPadding = 8;
  static const double _titleGap = 12;
  static const double _pageBottomPadding = 42;

  final List<String> _pages = [];
  int _currentPage = 0;
  double _lastPageWidth = 0;
  double _lastPageHeight = 0;
  String _lastContent = '';
  double _lastFontSize = 0;
  double _lastLineHeight = 0;
  bool _scheduledUpdate = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
  }

  @override
  void didUpdateWidget(_HorizontalReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.title != widget.title ||
        oldWidget.initialPage != widget.initialPage) {
      _currentPage = widget.initialPage;
      _pages.clear();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<String> _computePages(String text, double width, double height) {
    if (text.isEmpty || height <= 0 || width <= 0) {
      return [''];
    }

    final bodyStyle = TextStyle(
      color: widget.colors.foreground,
      fontSize: widget.settings.fontSize,
      height: widget.settings.lineHeight,
    );

    final tp = TextPainter(
      text: TextSpan(text: text, style: bodyStyle),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: width);

    final pages = <String>[];
    double y = 0;

    while (y < tp.height && pages.length < 800) {
      final startPos = tp.getPositionForOffset(Offset(0, y));
      final endY = (y + height).clamp(0.0, tp.height).toDouble();
      final endPos = tp.getPositionForOffset(Offset(width, endY));

      final start = startPos.offset.clamp(0, text.length);
      final end = endPos.offset.clamp(start + 1, text.length);

      pages.add(text.substring(start, end));
      y += height;
    }

    return pages.isEmpty ? [''] : pages;
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: widget.colors.foreground,
      fontSize: widget.settings.fontSize + 4,
      fontWeight: FontWeight.w800,
      height: 1.35,
    );

    final bodyStyle = TextStyle(
      color: widget.colors.foreground,
      fontSize: widget.settings.fontSize,
      height: widget.settings.lineHeight,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth - _horizontalPadding * 2;

        // Measure title height
        final titleTP = TextPainter(
          text: TextSpan(text: widget.title, style: titleStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: pageWidth);

        final lineGuard =
            widget.settings.fontSize * widget.settings.lineHeight * 0.85;
        final pageHeight =
            (constraints.maxHeight -
                    titleTP.height -
                    _titleTopPadding -
                    _titleGap -
                    _pageBottomPadding -
                    lineGuard)
                .clamp(60.0, 4000.0);

        final needsRecompute =
            _pages.isEmpty ||
            _lastContent != widget.content ||
            _lastFontSize != widget.settings.fontSize ||
            _lastLineHeight != widget.settings.lineHeight ||
            (_lastPageWidth - pageWidth).abs() > 1.0 ||
            (_lastPageHeight - pageHeight).abs() > 2.0;

        late final List<String> displayPages;
        late final int displayPage;

        if (needsRecompute) {
          _lastContent = widget.content;
          _lastFontSize = widget.settings.fontSize;
          _lastLineHeight = widget.settings.lineHeight;
          _lastPageWidth = pageWidth;
          _lastPageHeight = pageHeight;

          final computed = _computePages(widget.content, pageWidth, pageHeight);
          displayPages = computed;
          displayPage = _currentPage.clamp(0, computed.length - 1);

          // Sync cached state after this frame (only once per change)
          if (!_scheduledUpdate) {
            _scheduledUpdate = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scheduledUpdate = false;
              if (!mounted) return;
              setState(() {
                _pages
                  ..clear()
                  ..addAll(computed);
                _currentPage = displayPage;
              });
            });
          }
        } else {
          displayPages = _pages;
          displayPage = _currentPage;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _horizontalPadding,
                _titleTopPadding,
                _horizontalPadding,
                0,
              ),
              child: Text(
                widget.title,
                style: titleStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: _titleGap),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _PageFlipper(
                      pages: displayPages,
                      currentPage: displayPage,
                      bodyStyle: bodyStyle,
                      pageBackground: widget.colors.background,
                      enableAnimation: widget.settings.enableFlipAnimation,
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                        widget.onFlipPageChanged(page);
                      },
                      onCenterTap: widget.onToggleControls,
                      onOverflowPrevious: widget.onPreviousChapter,
                      onOverflowNext: widget.onNextChapter,
                    ),
                  ),
                  Positioned(
                    left: _horizontalPadding,
                    bottom: 6,
                    child: SafeArea(
                      top: false,
                      right: false,
                      child: Text(
                        '${displayPage + 1} / ${displayPages.length}',
                        style: TextStyle(
                          color: widget.colors.foreground.withValues(
                            alpha: 0.45,
                          ),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Page flipper (with / without animation) ────────────────────────────

class _PageFlipper extends StatefulWidget {
  const _PageFlipper({
    required this.pages,
    required this.currentPage,
    required this.bodyStyle,
    required this.pageBackground,
    required this.enableAnimation,
    required this.onPageChanged,
    required this.onCenterTap,
    required this.onOverflowPrevious,
    required this.onOverflowNext,
  });

  final List<String> pages;
  final int currentPage;
  final TextStyle bodyStyle;
  final Color pageBackground;
  final bool enableAnimation;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onCenterTap;
  final VoidCallback onOverflowPrevious;
  final VoidCallback onOverflowNext;

  @override
  State<_PageFlipper> createState() => _PageFlipperState();
}

class _PageFlipperState extends State<_PageFlipper>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  AnimationController? _flipController;
  int _displayPage = 0;
  bool _flipForward = true;
  double _dragStartX = 0;
  bool _isDragging = false;

  static const double _commitThreshold = 0.35;
  static const double _maxFlipAngle = math.pi / 2.3;

  @override
  void initState() {
    super.initState();
    _displayPage = widget.currentPage;
    _pageController = PageController(initialPage: widget.currentPage);
    if (widget.enableAnimation) {
      _flipController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      )..addListener(() => setState(() {}));
    }
  }

  @override
  void didUpdateWidget(_PageFlipper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPage != oldWidget.currentPage &&
        widget.currentPage != _displayPage) {
      _displayPage = widget.currentPage;
      if (!widget.enableAnimation &&
          _pageController.hasClients &&
          _pageController.page?.round() != widget.currentPage) {
        _pageController.jumpToPage(widget.currentPage);
      }
    }
    // Toggle animation on/off
    if (widget.enableAnimation && _flipController == null) {
      _flipController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      )..addListener(() => setState(() {}));
    } else if (!widget.enableAnimation && _flipController != null) {
      _flipController!.dispose();
      _flipController = null;
      _pageController.jumpToPage(_displayPage);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flipController?.dispose();
    super.dispose();
  }

  // ── animated flip path ───────────────────────────────────────────────

  void _onDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _isDragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final delta = details.globalPosition.dx - _dragStartX;
    final screenWidth = MediaQuery.of(context).size.width;
    final fraction = (delta.abs() / screenWidth).clamp(0.0, 1.0);

    if (delta < 0 && _displayPage < widget.pages.length - 1) {
      // Swiping left → next page
      _flipForward = true;
      _flipController?.value = fraction;
    } else if (delta > 0 && _displayPage > 0) {
      // Swiping right → previous page
      _flipForward = false;
      _flipController?.value = fraction;
    } else if (delta < 0 && _displayPage >= widget.pages.length - 1) {
      // At last page, swiping left – let parent decide
      _flipForward = true;
      _flipController?.value = fraction.clamp(0.0, 0.5);
    } else if (delta > 0 && _displayPage <= 0) {
      _flipForward = false;
      _flipController?.value = fraction.clamp(0.0, 0.5);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
    final value = _flipController?.value ?? 0;

    if (value >= _commitThreshold) {
      _commitFlip();
    } else {
      _revertFlip();
    }
  }

  void _commitFlip() {
    if (_flipForward) {
      if (_displayPage < widget.pages.length - 1) {
        _flipController?.forward().then(
          (_) => _afterFlipComplete(forward: true),
        );
      } else {
        _revertFlip();
        widget.onOverflowNext();
      }
    } else {
      if (_displayPage > 0) {
        _flipController?.forward().then(
          (_) => _afterFlipComplete(forward: false),
        );
      } else {
        _revertFlip();
        widget.onOverflowPrevious();
      }
    }
  }

  void _revertFlip() {
    _flipController?.reverse();
  }

  void _afterFlipComplete({required bool forward}) {
    if (!mounted) return;
    setState(() {
      if (forward) {
        _displayPage++;
      } else {
        _displayPage--;
      }
    });
    _flipController?.value = 0;
    widget.onPageChanged(_displayPage);
  }

  void _goToPreviousPageOrChapter() {
    if (_displayPage > 0) {
      _changePage(_displayPage - 1);
    } else {
      widget.onOverflowPrevious();
    }
  }

  void _goToNextPageOrChapter() {
    if (_displayPage < widget.pages.length - 1) {
      _changePage(_displayPage + 1);
    } else {
      widget.onOverflowNext();
    }
  }

  void _changePage(int page) {
    final safePage = page.clamp(0, widget.pages.length - 1).toInt();
    if (safePage == _displayPage) return;
    setState(() => _displayPage = safePage);
    if (!widget.enableAnimation && _pageController.hasClients) {
      _pageController.animateToPage(
        safePage,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
    widget.onPageChanged(safePage);
  }

  void _onTapUp(TapUpDetails details) {
    final width = context.size?.width ?? MediaQuery.of(context).size.width;
    final x = details.localPosition.dx;
    if (x < width / 3) {
      _goToPreviousPageOrChapter();
    } else if (x > width * 2 / 3) {
      _goToNextPageOrChapter();
    } else {
      widget.onCenterTap();
    }
  }

  Widget _buildAnimated() {
    final flipValue = _flipController?.value ?? 0;
    final pageText = widget.pages[_displayPage];

    // Page underneath (revealed as top page flips away)
    Widget? underneath;
    if (flipValue > 0.001 &&
        _flipForward &&
        _displayPage < widget.pages.length - 1) {
      underneath = _pageWidget(widget.pages[_displayPage + 1]);
    } else if (flipValue > 0.001 && !_flipForward && _displayPage > 0) {
      underneath = _pageWidget(widget.pages[_displayPage - 1]);
    }

    // Top page with flip transform
    Widget topPage;
    double angle;

    if (_flipForward) {
      // Current page rotates away around left edge
      angle = flipValue * _maxFlipAngle;
      topPage = _pageWidget(pageText, rotateY: -angle);
    } else {
      // Previous page comes in from the left
      angle = (1 - flipValue) * _maxFlipAngle;
      topPage = _pageWidget(
        _displayPage > 0 ? widget.pages[_displayPage - 1] : pageText,
        rotateY: angle - _maxFlipAngle,
        alignment: Alignment.centerRight,
      );
    }

    return GestureDetector(
      onTapUp: _onTapUp,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          if (underneath != null) Positioned.fill(child: underneath),
          Positioned.fill(child: topPage),
          // Shadow gradient on the fold edge
          if (flipValue > 0.02)
            Positioned(
              left: _flipForward
                  ? (1 - flipValue) * (MediaQuery.of(context).size.width - 40)
                  : flipValue * (MediaQuery.of(context).size.width - 40),
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: _flipForward
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      end: _flipForward
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: flipValue * 0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── non-animated path (standard PageView) ─────────────────────────────

  Widget _buildPlainPageView() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: _onTapUp,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.pages.length,
        onPageChanged: (page) {
          setState(() => _displayPage = page);
          widget.onPageChanged(page);
        },
        itemBuilder: (context, index) {
          return _pageWidget(widget.pages[index]);
        },
      ),
    );
  }

  // ── shared page widget ────────────────────────────────────────────────

  Widget _pageWidget(
    String text, {
    double? rotateY,
    Alignment alignment = Alignment.centerLeft,
  }) {
    Widget child = ColoredBox(
      color: widget.pageBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          20,
          0,
          20,
          _HorizontalReaderState._pageBottomPadding,
        ),
        child: ClipRect(
          child: Text(
            text,
            style: widget.bodyStyle,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );

    if (rotateY != null && rotateY.abs() > 0.001) {
      child = Transform(
        alignment: alignment,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(rotateY),
        child: child,
      );
    }

    return child;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enableAnimation) {
      return _buildAnimated();
    }
    return _buildPlainPageView();
  }
}
// ─── Reader settings sheet ──────────────────────────────────────────────

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
          SwitchListTile(
            title: const Text('翻书动画'),
            value: settings.enableFlipAnimation,
            onChanged: (value) => controller.updateReaderSettings(
              settings.copyWith(enableFlipAnimation: value),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
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
