import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/select_info_provider.dart';
import '../../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSettingsPage extends StatefulWidget {
  final AppUser currentUser;
  const AdminSettingsPage({super.key, required this.currentUser});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
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
    if (!widget.currentUser.isMainAdmin) {
      return const Scaffold(
        body: Center(child: Text('접근 권한이 없습니다.')),
      );
    }
    final selectInfo = context.watch<SelectInfoProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 설정')), 
      body: selectInfo.loaded ? DefaultTabController(
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
      ) : const Center(child: CircularProgressIndicator()),
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
                  decoration: InputDecoration(labelText: '$collection 추가'),
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
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, editController.text.trim()),
                                    child: const Text('저장'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (newName != null && newName.isNotEmpty) {
                            await FirebaseFirestore.instance.collection(collection).doc(item['id']).update({
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
                          await FirebaseFirestore.instance.collection(collection).doc(item['id']).delete();
                          context.read<SelectInfoProvider>().loadAll();
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