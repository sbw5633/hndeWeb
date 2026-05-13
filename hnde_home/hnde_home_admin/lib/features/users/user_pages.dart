import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';

class UserListPage extends ConsumerWidget {
  const UserListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUsers = ref.watch(userListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('사용자/권한 관리')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
            context: context, builder: (_) => const _UserEditDialog()),
        child: const Icon(Icons.add),
      ),
      body: asyncUsers.when(
        data: (users) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final u = users[i];
            return Card(
              child: ListTile(
                title: Text(u.displayName),
                subtitle: Text('${u.email} · ${u.role.name}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => showDialog(
                            context: context,
                            builder: (_) => _UserEditDialog(user: u))),
                    IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () =>
                            ref.read(userListProvider.notifier).remove(u.id)),
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

class _UserEditDialog extends ConsumerStatefulWidget {
  final UserAccount? user;
  const _UserEditDialog({this.user});

  @override
  ConsumerState<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends ConsumerState<_UserEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.user?.email ?? '');
  late final TextEditingController _name =
      TextEditingController(text: widget.user?.displayName ?? '');
  Role _role = Role.editor;

  @override
  void initState() {
    super.initState();
    _role = widget.user?.role ?? Role.editor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? '새 사용자' : '사용자 수정'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: '이메일'),
                  validator: (v) => (v == null || v.isEmpty) ? '이메일 입력' : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: '이름'),
                  validator: (v) => (v == null || v.isEmpty) ? '이름 입력' : null),
              const SizedBox(height: 12),
              DropdownButtonFormField<Role>(
                value: _role,
                items: const [
                  DropdownMenuItem(value: Role.admin, child: Text('관리자')),
                  DropdownMenuItem(value: Role.editor, child: Text('에디터')),
                  DropdownMenuItem(value: Role.viewer, child: Text('뷰어')),
                ],
                onChanged: (v) => setState(() => _role = v ?? Role.editor),
                decoration: const InputDecoration(labelText: '권한'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final notifier = ref.read(userListProvider.notifier);
            if (widget.user == null) {
              await notifier.add(UserAccount(
                  id: '',
                  email: _email.text.trim(),
                  displayName: _name.text.trim(),
                  role: _role));
            } else {
              await notifier.updateItem(UserAccount(
                  id: widget.user!.id,
                  email: _email.text.trim(),
                  displayName: _name.text.trim(),
                  role: _role));
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
