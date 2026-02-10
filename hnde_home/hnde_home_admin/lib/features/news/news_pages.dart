import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/news_provider.dart';

class NewsListPage extends ConsumerWidget {
  const NewsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('공지/뉴스 관리')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showDialog(
              context: context, builder: (_) => const _NewsEditDialog());
        },
        child: const Icon(Icons.add),
      ),
      body: newsAsync.when(
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final item = items[i];
            return Card(
              child: ListTile(
                title: Text(item.title),
                subtitle: Text(
                    '${item.category} · ${item.date.toIso8601String().substring(0, 10)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => showDialog(
                          context: context,
                          builder: (_) => _NewsEditDialog(item: item)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          ref.read(newsListProvider.notifier).remove(item.id),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }
}

class _NewsEditDialog extends ConsumerStatefulWidget {
  final NewsItem? item;
  const _NewsEditDialog({this.item});

  @override
  ConsumerState<_NewsEditDialog> createState() => _NewsEditDialogState();
}

class _NewsEditDialogState extends ConsumerState<_NewsEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.item?.title ?? '');
  late final TextEditingController _content =
      TextEditingController(text: widget.item?.content ?? '');
  String _category = '공지사항';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? '새 공지/뉴스' : '수정'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: '제목'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? '제목을 입력하세요' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: widget.item?.category ?? _category,
                  items: const [
                    DropdownMenuItem(value: '공지사항', child: Text('공지사항')),
                    DropdownMenuItem(value: '뉴스', child: Text('뉴스')),
                    DropdownMenuItem(value: '채용', child: Text('채용')),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? '공지사항'),
                  decoration: const InputDecoration(labelText: '카테고리'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _content,
                  decoration: const InputDecoration(labelText: '내용'),
                  maxLines: 6,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? '내용을 입력하세요' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final notifier = ref.read(newsListProvider.notifier);
            if (widget.item == null) {
              await notifier.add(NewsItem(
                id: '',
                title: _title.text.trim(),
                content: _content.text.trim(),
                date: DateTime.now(),
                category: _category,
              ));
            } else {
              await notifier.updateItem(NewsItem(
                id: widget.item!.id,
                title: _title.text.trim(),
                content: _content.text.trim(),
                date: widget.item!.date,
                category: _category,
              ));
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
