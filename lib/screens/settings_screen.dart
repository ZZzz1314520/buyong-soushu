import 'package:flutter/material.dart';

import '../models/novel_models.dart';
import '../services/app_controller.dart';
import '../services/controller_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ControllerScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── Reader defaults ──
          const _SectionTitle(title: '阅读偏好'),
          ListTile(
            title: const Text('字体大小'),
            subtitle: Slider(
              min: 16,
              max: 30,
              divisions: 14,
              value: controller.readerSettings.fontSize,
              label: controller.readerSettings.fontSize.round().toString(),
              onChanged: (value) => controller.updateReaderSettings(
                controller.readerSettings.copyWith(fontSize: value),
              ),
            ),
            trailing: Text('${controller.readerSettings.fontSize.round()}'),
          ),
          ListTile(
            title: const Text('行间距'),
            subtitle: Slider(
              min: 1.3,
              max: 2,
              divisions: 7,
              value: controller.readerSettings.lineHeight,
              label: controller.readerSettings.lineHeight.toStringAsFixed(1),
              onChanged: (value) => controller.updateReaderSettings(
                controller.readerSettings.copyWith(lineHeight: value),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ReaderTheme>(
              segments: const [
                ButtonSegment(value: ReaderTheme.paper, label: Text('米黄')),
                ButtonSegment(value: ReaderTheme.green, label: Text('护眼')),
                ButtonSegment(value: ReaderTheme.pureWhite, label: Text('白天')),
                ButtonSegment(value: ReaderTheme.dark, label: Text('夜间')),
              ],
              selected: {controller.readerSettings.theme},
              onSelectionChanged: (selected) => controller.updateReaderSettings(
                controller.readerSettings.copyWith(theme: selected.first),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('翻书动画'),
            value: controller.readerSettings.enableFlipAnimation,
            onChanged: (value) => controller.updateReaderSettings(
              controller.readerSettings.copyWith(enableFlipAnimation: value),
            ),
          ),
          const Divider(height: 32),

          // ── Search sources ──
          _SectionTitle(
            title: '搜索来源',
            action: FilledButton.icon(
              onPressed: () => _showAddSourceDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('添加'),
            ),
          ),
          ...controller.sources.map(
            (source) => Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: source.enabled,
                    onChanged: (value) =>
                        controller.toggleSource(source, value),
                    title: Text(source.name),
                    subtitle: Text(
                      source.urlTemplate,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  OverflowBar(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            final results = await controller.testSource(source);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    results.isEmpty
                                        ? '测试未获得结果'
                                        : '找到 ${results.length} 条结果',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('测试失败：$e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('测试'),
                      ),
                      if (!isDefaultSourceId(source.id))
                        TextButton.icon(
                          onPressed: () => controller.removeSource(source),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          label: const Text(
                            '删除',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSourceDialog(BuildContext context) async {
    final controller = ControllerScope.of(context);

    await showDialog<void>(
      context: context,
      builder: (context) => _AddSourceDialog(controller: controller),
    );
  }
}

class _AddSourceDialog extends StatefulWidget {
  const _AddSourceDialog({required this.controller});

  final AppController controller;

  @override
  State<_AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends State<_AddSourceDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _urlController = TextEditingController(
      text: 'https://example.com/search?q={query}',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    if (name.isEmpty || !url.contains('{query}')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('名称不能为空，URL 必须包含 {query}')));
      return;
    }
    await widget.controller.addSource(name, url);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加搜索来源'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '来源名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '搜索 URL 模板',
                helperText: '用 {query} 表示书名',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          action ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}
