import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/select_info_provider.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  @override
  void initState() {
    super.initState();
    // SelectInfoProvider에서 데이터 로드
    Future.microtask(() {
      final provider = context.read<SelectInfoProvider>();
      if (!provider.loaded) provider.loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectInfo = context.watch<SelectInfoProvider>();
    
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '사업소'),
              Tab(text: '직책'),
              Tab(text: '급수'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CrudListWidget(collection: 'branches', items: selectInfo.branches),
                _CrudListWidget(collection: 'positions', items: selectInfo.positions),
                _CrudListWidget(collection: 'ranks', items: selectInfo.ranks),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CrudListWidget extends StatelessWidget {
  final String collection;
  final List<Map<String, dynamic>> items;
  const _CrudListWidget({required this.collection, required this.items});

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: '$collection 추가',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  await FirebaseFirestore.instance.collection(collection).add({
                    'name': name,
                    'updatedAt': DateTime.now().toIso8601String(),
                  });
                  controller.clear();
                  context.read<SelectInfoProvider>().loadAll();
                },
                child: const Text('추가'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, idx) {
                final item = items[idx];
                return ListTile(
                  title: Text(item['name'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final newName = await showDialog<String>(
                            context: context,
                            builder: (context) {
                              final editController = TextEditingController(text: item['name'] ?? '');
                              return AlertDialog(
                                title: const Text('이름 수정'),
                                content: TextField(controller: editController),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('취소'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, editController.text.trim()),
                                    child: const Text('저장'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (newName != null && newName.isNotEmpty) {
                            await FirebaseFirestore.instance
                                .collection(collection)
                                .doc(item['id'])
                                .update({
                              'name': newName,
                              'updatedAt': DateTime.now().toIso8601String(),
                            });
                            context.read<SelectInfoProvider>().loadAll();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('삭제 확인'),
                              content: const Text('정말 삭제하시겠습니까?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('취소'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection(collection)
                                        .doc(item['id'])
                                        .delete();
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                    context.read<SelectInfoProvider>().loadAll();
                                  },
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
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

