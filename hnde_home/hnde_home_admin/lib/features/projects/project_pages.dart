import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/project_provider.dart';

class ProjectListPage extends ConsumerWidget {
  const ProjectListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(projectListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('프로젝트 관리')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
            context: context, builder: (_) => const _ProjectEditDialog()),
        child: const Icon(Icons.add),
      ),
      body: itemsAsync.when(
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
                    '${item.category} · ${item.location} · ${item.completedDate.toIso8601String().substring(0, 10)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => showDialog(
                          context: context,
                          builder: (_) => _ProjectEditDialog(item: item)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => ref
                          .read(projectListProvider.notifier)
                          .remove(item.id),
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

class _ProjectEditDialog extends ConsumerStatefulWidget {
  final ProjectItem? item;
  const _ProjectEditDialog({this.item});

  @override
  ConsumerState<_ProjectEditDialog> createState() => _ProjectEditDialogState();
}

class _ProjectEditDialogState extends ConsumerState<_ProjectEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.item?.title ?? '');
  late final TextEditingController _desc =
      TextEditingController(text: widget.item?.description ?? '');
  late final TextEditingController _category =
      TextEditingController(text: widget.item?.category ?? '인테리어');
  late final TextEditingController _location =
      TextEditingController(text: widget.item?.location ?? '');
  DateTime _completed = DateTime.now();
  late final TextEditingController _tags =
      TextEditingController(text: widget.item?.tags.join(',') ?? '');

  @override
  void initState() {
    super.initState();
    _completed = widget.item?.completedDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? '새 프로젝트' : '프로젝트 수정'),
      content: SizedBox(
        width: 520,
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
                        (v == null || v.isEmpty) ? '제목 입력' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _desc,
                    decoration: const InputDecoration(labelText: '설명'),
                    maxLines: 5,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '설명 입력' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _category,
                    decoration: const InputDecoration(labelText: '카테고리')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(labelText: '위치')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: Text(
                          '완료일: ${_completed.toIso8601String().substring(0, 10)}')),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: _completed,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100));
                      if (picked != null) setState(() => _completed = picked);
                    },
                    child: const Text('날짜 선택'),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _tags,
                    decoration:
                        const InputDecoration(labelText: '태그 (쉼표로 구분)')),
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
            final notifier = ref.read(projectListProvider.notifier);
            final tags = _tags.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            if (widget.item == null) {
              await notifier.add(ProjectItem(
                  id: '',
                  title: _title.text.trim(),
                  description: _desc.text.trim(),
                  category: _category.text.trim(),
                  location: _location.text.trim(),
                  completedDate: _completed,
                  tags: tags));
            } else {
              await notifier.updateItem(ProjectItem(
                  id: widget.item!.id,
                  title: _title.text.trim(),
                  description: _desc.text.trim(),
                  category: _category.text.trim(),
                  location: _location.text.trim(),
                  completedDate: _completed,
                  tags: tags));
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
