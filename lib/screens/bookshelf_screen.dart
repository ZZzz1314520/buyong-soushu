import 'package:flutter/material.dart';

import '../models/novel_models.dart';
import '../services/controller_scope.dart';
import 'book_detail_screen.dart';
import 'reader_screen.dart';

enum _BookshelfSort { lastRead, recentlyAdded, title }

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  var _sort = _BookshelfSort.lastRead;

  List<Book> _sorted(List<Book> books) {
    switch (_sort) {
      case _BookshelfSort.lastRead:
        return [...books]..sort(
            (a, b) => (b.lastReadAt ?? DateTime(2000))
                .compareTo(a.lastReadAt ?? DateTime(2000)),
          );
      case _BookshelfSort.recentlyAdded:
        return books; // already in add-order
      case _BookshelfSort.title:
        return [...books]..sort(
            (a, b) => a.title.compareTo(b.title),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ControllerScope.of(context);
    final books = _sorted(controller.books);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        actions: [
          PopupMenuButton<_BookshelfSort>(
            tooltip: '排序方式',
            icon: const Icon(Icons.sort),
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _BookshelfSort.lastRead,
                child: Text('最近阅读'),
              ),
              const PopupMenuItem(
                value: _BookshelfSort.recentlyAdded,
                child: Text('最近添加'),
              ),
              const PopupMenuItem(
                value: _BookshelfSort.title,
                child: Text('书名'),
              ),
            ],
          ),
        ],
      ),
      body: books.isEmpty
          ? const _EmptyShelf()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: books.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final book = books[index];
                return _BookCard(
                  book: book,
                  onRead: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReaderScreen(bookId: book.id),
                    ),
                  ),
                  onDetail: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookDetailScreen(bookId: book.id),
                    ),
                  ),
                  onRemove: () => controller.removeBook(book),
                );
              },
            ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_library_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              '书架还是空的',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '去搜书页输入书名，选择来源后添加到书架。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.onRead,
    required this.onDetail,
    required this.onRemove,
  });

  final Book book;
  final VoidCallback onRead;
  final VoidCallback onDetail;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final chapter = book.chapters.isEmpty
        ? '暂无章节'
        : book.chapters[book.currentChapterIndex].title;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onRead,
        onLongPress: onDetail,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xffffeee4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.auto_stories, color: Color(0xfffb5b21)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      chapter,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 4),
                    if (book.chapters.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: (book.currentChapterIndex + 1) /
                                    book.chapters.length,
                                minHeight: 3,
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${book.currentChapterIndex + 1}/${book.chapters.length}章',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      book.sourceName,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '移出书架',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
