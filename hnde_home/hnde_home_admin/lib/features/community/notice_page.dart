import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/content_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/notice.dart';
import 'notice_edit_dialog.dart';

class NoticePage extends ConsumerWidget {
  const NoticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(noticeListProvider);
    final userInfo = ref.watch(currentUserInfoProvider);

    return userInfo.when(
      data: (user) {
        final isAdmin = user?.isAdmin ?? false;
        
        return notices.when(
          data: (items) {
            if (items.isEmpty) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('공지사항 관리'),
                  actions: [
                    if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddDialog(context, ref),
                      ),
                  ],
                ),
                body: const Center(child: Text('등록된 공지사항이 없습니다.')),
              );
            }
            return Scaffold(
              appBar: AppBar(
                title: const Text('공지사항 관리'),
                actions: [
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _showAddDialog(context, ref),
                    ),
                ],
              ),
              body: Column(
                children: [
                  if (!isAdmin)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.orange[50],
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '휴게소 관리자는 공지사항을 조회만 할 수 있습니다.',
                              style: TextStyle(color: Colors.orange[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(child: Text(item.title)),
                                if (item.isImportant)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      '중요',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('yyyy-MM-dd').format(item.date)),
                                if (item.author != null) Text('작성자: ${item.author}'),
                              ],
                            ),
                            trailing: isAdmin
                                ? Row(
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
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('공지사항 관리')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (err, stack) => Scaffold(
            appBar: AppBar(title: const Text('공지사항 관리')),
            body: Center(child: Text('오류: $err')),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('공지사항 관리')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('공지사항 관리')),
        body: const Center(child: Text('사용자 정보를 불러올 수 없습니다.')),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => NoticeEditDialog(
        onSave: (item) async {
          await ref.read(noticeControllerProvider).add(item);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Notice item) {
    showDialog(
      context: context,
      builder: (_) => NoticeEditDialog(
        initialItem: item,
        onSave: (item) async {
          await ref.read(noticeControllerProvider).update(item);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Notice item) {
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
              await ref.read(noticeControllerProvider).delete(item.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

