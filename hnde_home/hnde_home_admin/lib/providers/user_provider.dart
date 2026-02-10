import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

enum Role { admin, editor, viewer }

class UserAccount {
  final String id;
  final String email;
  final String displayName;
  final Role role;
  UserAccount(
      {required this.id,
      required this.email,
      required this.displayName,
      required this.role});
  factory UserAccount.fromMap(Map<String, dynamic> m) => UserAccount(
        id: m['id'] as String,
        email: m['email'] as String,
        displayName: m['display_name'] as String,
        role: Role.values.firstWhere((r) => r.name == m['role']),
      );
  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'role': role.name,
      };
}

final userListProvider =
    AsyncNotifierProvider<UserListController, List<UserAccount>>(
        UserListController.new);

class UserListController extends AsyncNotifier<List<UserAccount>> {
  @override
  Future<List<UserAccount>> build() async {
    final data = await Supabase.instance.client.from('users_admin').select();
    return (data as List<dynamic>)
        .map((e) => UserAccount.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(UserAccount u) async {
    final id = u.id.isEmpty ? const Uuid().v4() : u.id;
    final data = u.toMap();
    data['id'] = id;
    await Supabase.instance.client.from('users_admin').insert(data);
    state = AsyncData(await build());
  }

  Future<void> updateItem(UserAccount u) async {
    await Supabase.instance.client
        .from('users_admin')
        .update(u.toMap())
        .eq('id', u.id);
    state = AsyncData(await build());
  }

  Future<void> remove(String id) async {
    await Supabase.instance.client.from('users_admin').delete().eq('id', id);
    state = AsyncData(await build());
  }
}
