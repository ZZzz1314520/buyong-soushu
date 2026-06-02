import 'package:flutter/material.dart';

import '../models/novel_models.dart';
import '../services/controller_scope.dart';
import 'reader_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  var _results = <BookSearchResult>[];
  var _loading = false;
  var _addingUrl = '';
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final controller = ControllerScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await controller.search(_queryController.text);
      if (!mounted) {
        return;
      }
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '搜索失败：$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _add(BookSearchResult result) async {
    final controller = ControllerScope.of(context);
    setState(() => _addingUrl = result.url);
    try {
      final book = await controller.addResultToShelf(result);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加《${book.title}》')));
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ReaderScreen(bookId: book.id)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('添加失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _addingUrl = '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = ControllerScope.of(
      context,
    ).sources.where((source) => source.enabled).length;

    return Scaffold(
      appBar: AppBar(title: const Text('搜书')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('book-search-field'),
                    controller: _queryController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: '输入书名',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('搜索'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '当前启用 $enabledCount 个搜索来源',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _results.isEmpty && !_loading
                ? const Center(child: Text('搜索结果会显示在这里'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      final adding = _addingUrl == result.url;
                      return Card(
                        child: ListTile(
                          title: Text(
                            result.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${result.sourceName}\n${result.url}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: FilledButton.tonal(
                            onPressed: adding ? null : () => _add(result),
                            child: adding
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('加入'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
