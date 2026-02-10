import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/content_provider.dart';
import '../../models/press_release.dart';
import 'press_release_edit_dialog.dart';

class PressReleasePage extends ConsumerWidget {
  const PressReleasePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pressReleases = ref.watch(pressReleaseListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('보도자료 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: pressReleases.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('등록된 보도자료가 없습니다.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: item.imageUrl != null
                      ? Image.network(item.imageUrl!,
                          width: 60, height: 60, fit: BoxFit.cover)
                      : const Icon(Icons.article, size: 40),
                  title: Text(item.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('yyyy-MM-dd').format(item.date)),
                      if (item.author != null) Text('작성자: ${item.author}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditDialog(context, ref, item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _showDeleteDialog(context, ref, item),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류: $err')),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => PressReleaseEditDialog(
        onSave: (item) async {
          await ref.read(pressReleaseControllerProvider).add(item);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, PressRelease item) {
    showDialog(
      context: context,
      builder: (_) => PressReleaseEditDialog(
        initialItem: item,
        onSave: (item) async {
          await ref.read(pressReleaseControllerProvider).update(item);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, PressRelease item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('${item.title}\n\n삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(pressReleaseControllerProvider).delete(item.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

