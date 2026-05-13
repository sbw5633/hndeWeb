import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/content_provider.dart';
import '../../models/customer_event.dart';
import 'customer_event_edit_dialog.dart';

class CustomerEventPage extends ConsumerWidget {
  const CustomerEventPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(customerEventListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('고객이벤트 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: events.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('등록된 이벤트가 없습니다.'));
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
                      : const Icon(Icons.event, size: 40),
                  title: Row(
                    children: [
                      Text(item.title),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.isActive ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.isActive ? '진행중' : '종료',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateFormat('yyyy-MM-dd').format(item.startDate)} ~ ${DateFormat('yyyy-MM-dd').format(item.endDate)}',
                      ),
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
      builder: (_) => CustomerEventEditDialog(
        onSave: (item) async {
          await ref.read(customerEventControllerProvider).add(item);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, CustomerEvent item) {
    showDialog(
      context: context,
      builder: (_) => CustomerEventEditDialog(
        initialItem: item,
        onSave: (item) async {
          await ref.read(customerEventControllerProvider).update(item);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, CustomerEvent item) {
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
              await ref.read(customerEventControllerProvider).delete(item.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

