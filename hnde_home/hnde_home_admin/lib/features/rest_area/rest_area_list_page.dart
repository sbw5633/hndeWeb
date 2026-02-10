import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/content_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/rest_area.dart';
import 'rest_area_edit_page.dart';

class RestAreaListPage extends ConsumerStatefulWidget {
  const RestAreaListPage({super.key});

  @override
  ConsumerState<RestAreaListPage> createState() => _RestAreaListPageState();
}

class _RestAreaListPageState extends ConsumerState<RestAreaListPage> {
  @override
  Widget build(BuildContext context) {
    final restAreas = ref.watch(restAreaListProvider);
    final userInfo = ref.watch(currentUserInfoProvider);

    return userInfo.when(
      data: (user) {
        final isAdmin = user?.isAdmin ?? false;
        final isRestAreaManager = user?.isRestAreaManager ?? false;
        
        return restAreas.when(
          data: (items) {
            // 휴게소 관리자인 경우 본인 소속 휴게소만 필터링
            final filteredItems = isRestAreaManager && user?.restAreaId != null
                ? items.where((item) => item.id == user!.restAreaId).toList()
                : items;

            if (filteredItems.isEmpty) {
              return const Center(child: Text('등록된 휴게소가 없습니다.'));
            }

            // 관리자인 경우에만 ReorderableListView 사용
            if (isAdmin) {
              return ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                buildDefaultDragHandles: false,
                itemCount: filteredItems.length,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  setState(() {
                    final item = filteredItems.removeAt(oldIndex);
                    filteredItems.insert(newIndex, item);
                    // 순서 업데이트
                    for (int i = 0; i < filteredItems.length; i++) {
                      final updatedItem = RestArea(
                        id: filteredItems[i].id,
                        name: filteredItems[i].name,
                        imageUrl: filteredItems[i].imageUrl,
                        description: filteredItems[i].description,
                        detail: filteredItems[i].detail,
                        order: i,
                      );
                      ref.read(restAreaControllerProvider).update(updatedItem);
                    }
                  });
                },
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return _RestAreaListItem(
                    key: ValueKey(item.id),
                    item: item,
                    user: user!,
                    isAdmin: isAdmin,
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestAreaEditPage(restArea: item),
                      ),
                    ),
                    onDelete: () => _showDeleteDialog(context, ref, item),
                  );
                },
              );
            } else {
              // 휴게소 관리자는 일반 ListView
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return _RestAreaListItem(
                    key: ValueKey(item.id),
                    item: item,
                    user: user!,
                    isAdmin: isAdmin,
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestAreaEditPage(restArea: item),
                      ),
                    ),
                    onDelete: () => _showDeleteDialog(context, ref, item),
                  );
                },
              );
            }
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('오류: $err')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => const Center(child: Text('사용자 정보를 불러올 수 없습니다.')),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, RestArea item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('${item.name}\n\n삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(restAreaControllerProvider).delete(item.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _RestAreaListItem extends StatelessWidget {
  final RestArea item;
  final dynamic user;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RestAreaListItem({
    required super.key,
    required this.item,
    required this.user,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin)
              ReorderableDragStartListener(
                index: item.order,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.drag_handle,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            item.imageUrl != null
                ? Image.network(item.imageUrl!,
                    width: 60, height: 60, fit: BoxFit.cover)
                : const Icon(Icons.restaurant, size: 40),
          ],
        ),
        title: Text(item.name),
        subtitle: Text(item.description ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

