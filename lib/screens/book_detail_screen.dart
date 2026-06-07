import 'package:flutter/material.dart';

import '../models/novel_models.dart';
import '../services/controller_scope.dart';
import 'reader_screen.dart';

class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  Book? _book(BuildContext context) {
    final controller = ControllerScope.of(context);
    for (final book in controller.books) {
      if (book.id == bookId) return book;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ControllerScope.of(context);
    final book = _book(context);
    if (book == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('书籍详情')),
        body: const Center(child: Text('书籍不在书架中')),
      );
    }

    final progress = book.chapters.isEmpty
        ? 0.0
        : (book.currentChapterIndex + 1) / book.chapters.length;

    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Cover placeholder
          Center(
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xffffeee4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_stories,
                size: 52,
                color: Color(0xfffb5b21),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            book.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),

          // Source
          Text(
            book.sourceName,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Chapter count
          _InfoRow(
            icon: Icons.list_alt,
            label: '章节目录',
            value: '${book.chapters.length} 章',
          ),
          const SizedBox(height: 10),

          // Reading progress
          _InfoRow(
            icon: Icons.trending_up,
            label: '阅读进度',
            value: '${book.currentChapterIndex + 1}/${book.chapters.length} 章',
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toStringAsFixed(1)}%',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),

          if (book.lastReadAt != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.access_time,
              label: '上次阅读',
              value: _formatTime(book.lastReadAt!),
            ),
          ],

          const SizedBox(height: 32),

          // Action buttons
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ReaderScreen(bookId: book.id),
                ),
              );
            },
            icon: const Icon(Icons.menu_book),
            label: const Text('继续阅读'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: book.chapters.isEmpty
                ? null
                : () => _showCatalogSheet(context, book),
            icon: const Icon(Icons.format_list_bulleted),
            label: const Text('查看目录'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final updated = await controller.refreshBookChapters(book);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已刷新，共 ${updated.chapters.length} 章'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('刷新失败：$e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('刷新目录'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              controller.removeBook(book);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text(
              '移出书架',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showCatalogSheet(BuildContext context, Book book) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView.builder(
          itemCount: book.chapters.length,
          itemBuilder: (context, index) {
            final chapter = book.chapters[index];
            return ListTile(
              selected: index == book.currentChapterIndex,
              title: Text(
                chapter.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(context); // close sheet
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _ReaderFromDetail(
                      bookId: book.id,
                      chapterIndex: index,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// A light wrapper that opens the ReaderScreen at a specific chapter.
class _ReaderFromDetail extends StatelessWidget {
  const _ReaderFromDetail({
    required this.bookId,
    required this.chapterIndex,
  });

  final String bookId;
  final int chapterIndex;

  @override
  Widget build(BuildContext context) {
    final controller = ControllerScope.of(context);
    // Set the reading position before opening the reader
    for (final book in controller.books) {
      if (book.id == bookId) {
        controller.updateBook(
          book.copyWith(currentChapterIndex: chapterIndex),
        );
        break;
      }
    }
    return ReaderScreen(bookId: bookId);
  }
}
