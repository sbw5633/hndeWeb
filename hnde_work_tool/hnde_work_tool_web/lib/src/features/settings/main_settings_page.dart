import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/enterprise_scaffold.dart';
import '../common/loading_widget.dart';
import '../common/merged_user_profile_stream_builder.dart';
import '../../constants/firestore_paths.dart';
import '../../constants/super_admin.dart';
import '../../models/branch_model.dart';
import '../../repositories/work_firestore_repository.dart';

class MainSettingsPage extends StatefulWidget {
  const MainSettingsPage({super.key});

  @override
  State<MainSettingsPage> createState() => _MainSettingsPageState();
}

class _MainSettingsPageState extends State<MainSettingsPage> {
  String _group1Key = 'HDNE_MAIN';
  String _group2Key = 'THEWAY_MAIN';

  List<String> _group1Selected = <String>[];
  List<String> _group2Selected = <String>[];

  bool _savingGroups = false;
  String? _groupsError;

  bool _toggleSaving = false;

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const EnterpriseScaffold(
        title: '설정',
        child: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return EnterpriseScaffold(
      title: '설정',
      child: MergedUserProfileStreamBuilder(
        uid: user.uid,
        builder: (
          BuildContext context,
          Map<String, dynamic> data,
          bool streamsWaiting,
        ) {
          final bool mainAdmin = SuperAdmin.effectiveMainAdmin(
            profileMainAdmin: data['mainAdmin'],
            profileEmail: data['email'] as String?,
            authEmail: user.email,
            roleIdx: (data['roleIdx'] as num?)?.toInt(),
          );

          if (!mainAdmin) {
            return const Center(
                child: Text(
                  '접근 권한이 없습니다.',
                  style: TextStyle(color: Colors.grey),
                ),
            );
          }

          return _SettingsBody(
            group1Key: _group1Key,
            group2Key: _group2Key,
            group1Selected: _group1Selected,
            group2Selected: _group2Selected,
            savingGroups: _savingGroups,
            groupsError: _groupsError,
            onGroupsStateChanged: (List<String> g1, List<String> g2) {
              if (!mounted) return;
              setState(() {
                _group1Selected = g1;
                _group2Selected = g2;
              });
            },
            onSaveGroups: () async {
              await _saveGroups();
            },
            toggleSaving: _toggleSaving,
            onToggleSavingChanged: (bool v) {
              if (!mounted) return;
              setState(() => _toggleSaving = v);
            },
          );
        },
      ),
    );
  }

  Future<void> _saveGroups() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _savingGroups = true;
      _groupsError = null;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> branchSnap =
          await FirestorePaths.publicBranchesCol().get();
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> branchDocs =
          branchSnap.docs;

      final Set<String> group1Names = _group1Selected.toSet();
      final Set<String> group2Names = _group2Selected.toSet();

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // branch_groups 문서 업데이트
      batch.set(
        FirestorePaths.publicBranchGroupsCol().doc(_group1Key),
        <String, dynamic>{
          'label': '에이치앤디이 사업소',
          'branchNames': _group1Selected,
        },
        SetOptions(merge: true),
      );
      batch.set(
        FirestorePaths.publicBranchGroupsCol().doc(_group2Key),
        <String, dynamic>{
          'label': '더웨이유통 사업소',
          'branchNames': _group2Selected,
        },
        SetOptions(merge: true),
      );

      // branches 문서의 groupKey 동기화(드롭다운 데이터도 유지)
      for (final QueryDocumentSnapshot<Map<String, dynamic>> b in branchDocs) {
        final String branchName = (b.data()['name'] as String?) ?? '';
        final String newGroupKey =
            group1Names.contains(branchName)
                ? _group1Key
                : group2Names.contains(branchName)
                    ? _group2Key
                    : '';

        batch.set(
          FirestorePaths.publicBranchesCol().doc(b.id),
          <String, dynamic>{
            'name': branchName,
            'groupKey': newGroupKey,
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (e) {
      setState(() {
        _groupsError = '그룹 저장 실패: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingGroups = false;
        });
      }
    }
  }
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody({
    required this.group1Key,
    required this.group2Key,
    required this.group1Selected,
    required this.group2Selected,
    required this.savingGroups,
    required this.groupsError,
    required this.onGroupsStateChanged,
    required this.onSaveGroups,
    required this.toggleSaving,
    required this.onToggleSavingChanged,
  });

  final String group1Key;
  final String group2Key;
  final List<String> group1Selected;
  final List<String> group2Selected;
  final bool savingGroups;
  final String? groupsError;

  final void Function(List<String> g1, List<String> g2) onGroupsStateChanged;
  final Future<void> Function() onSaveGroups;

  final bool toggleSaving;
  final void Function(bool v) onToggleSavingChanged;

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  List<String> _allBranches = <String>[];
  late final WorkFirestoreRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
  }

  Future<void> _initGroupsIfNeeded({
    required List<String> allBranchNames,
    required DocumentSnapshot<Map<String, dynamic>> group1Snap,
    required DocumentSnapshot<Map<String, dynamic>> group2Snap,
  }) async {
    final List<String> g1 = (group1Snap.data()?['branchNames'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        <String>[];
    final List<String> g2 = (group2Snap.data()?['branchNames'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        <String>[];

    if (!mounted) return;
    if (widget.group1Selected.isEmpty && g1.isNotEmpty) {
      widget.onGroupsStateChanged(g1, g2);
    }
    if (_allBranches.isEmpty) {
      setState(() {
        _allBranches = allBranchNames;
      });
    } else {
      _allBranches = allBranchNames;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BranchModel>>(
      stream: _repo.watchBranches(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<BranchModel>> branchSnap,
      ) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirestorePaths.publicBranchGroupsCol().doc(widget.group1Key).snapshots(),
          builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> group1Snap) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirestorePaths.publicBranchGroupsCol().doc(widget.group2Key).snapshots(),
              builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> group2Snap) {
                if (branchSnap.connectionState == ConnectionState.waiting ||
                    group1Snap.connectionState == ConnectionState.waiting ||
                    group2Snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: LoadingWidget(size: 80));
                }

                final List<String> allBranchNames = (branchSnap.data ?? <BranchModel>[])
                    .map((BranchModel b) => b.name)
                    .where((String s) => s.trim().isNotEmpty)
                    .toList();

                final DocumentSnapshot<Map<String, dynamic>> g1Doc = group1Snap.data!;
                final DocumentSnapshot<Map<String, dynamic>> g2Doc = group2Snap.data!;

                // 초기값 동기화
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _initGroupsIfNeeded(
                    allBranchNames: allBranchNames,
                    group1Snap: g1Doc,
                    group2Snap: g2Doc,
                  );
                });

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '설정',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                '사업소 그룹 관리',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              if (widget.groupsError != null)
                                Text(widget.groupsError!, style: const TextStyle(color: Colors.redAccent)),
                              const SizedBox(height: 10),
                              _GroupEditorCard(
                                title: '에이치앤디이 사업소',
                                branches: _allBranches,
                                selected: widget.group1Selected.toSet(),
                                onChanged: (String branchName, bool checked) {
                                  final Set<String> next = widget.group1Selected.toSet();
                                  if (checked) {
                                    next.add(branchName);
                                  } else {
                                    next.remove(branchName);
                                  }
                                  widget.onGroupsStateChanged(next.toList(), widget.group2Selected);
                                },
                              ),
                              const SizedBox(height: 12),
                              _GroupEditorCard(
                                title: '더웨이유통 사업소',
                                branches: _allBranches,
                                selected: widget.group2Selected.toSet(),
                                onChanged: (String branchName, bool checked) {
                                  final Set<String> next = widget.group2Selected.toSet();
                                  if (checked) {
                                    next.add(branchName);
                                  } else {
                                    next.remove(branchName);
                                  }
                                  widget.onGroupsStateChanged(widget.group1Selected, next.toList());
                                },
                              ),
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: widget.savingGroups
                                      ? null
                                      : widget.onSaveGroups,
                                  child: widget.savingGroups
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: LoadingWidget(size: 16, duration: Duration(milliseconds: 1000)),
                                        )
                                      : const Text('그룹 저장'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '메인관리자 권한',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      _UserRoleTable(
                        toggleSaving: widget.toggleSaving,
                        onToggleSavingChanged: widget.onToggleSavingChanged,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _GroupEditorCard extends StatelessWidget {
  const _GroupEditorCard({
    required this.title,
    required this.branches,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<String> branches;
  final Set<String> selected;
  final void Function(String branchName, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (branches.isEmpty)
              const Text('데이터가 없습니다.', style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: branches.map((String b) {
                  final bool checked = selected.contains(b);
                  return FilterChip(
                    label: Text(b),
                    selected: checked,
                    onSelected: (bool value) => onChanged(b, value),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserRoleTable extends StatelessWidget {
  const _UserRoleTable({
    required this.toggleSaving,
    required this.onToggleSavingChanged,
  });

  final bool toggleSaving;
  final void Function(bool v) onToggleSavingChanged;

  @override
  Widget build(BuildContext context) {
    final Query<Map<String, dynamic>> query = FirestorePaths.usersCol()
        .orderBy('createdAt', descending: true)
        .limit(30);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget(size: 80));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('사용자 데이터가 없습니다.');
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs;

        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('이메일')),
                DataColumn(label: Text('UID')),
                DataColumn(label: Text('메인관리자')),
              ],
              rows: docs.map((d) {
                final Map<String, dynamic> data = d.data();
                final String email = data['email'] as String? ?? '-';
                final String uid = data['uid'] as String? ?? d.id;
                final bool mainAdmin = (data['mainAdmin'] as bool?) ?? false;
                final bool lockedSuper = SuperAdmin.isSuperAdminEmail(email);

                return DataRow(
                  cells: <DataCell>[
                    DataCell(Text(email)),
                    DataCell(Text(uid)),
                    DataCell(
                      Checkbox(
                        value: lockedSuper ? true : mainAdmin,
                        onChanged: toggleSaving || lockedSuper
                            ? null
                            : (bool? v) async {
                                if (v == null) return;
                                onToggleSavingChanged(true);
                                try {
                                  final bool next = v;
                                  final int nextRoleIdx = next ? 0 : 1;

                                  await FirestorePaths.usersCol().doc(uid).set(
                                    <String, dynamic>{
                                      'uid': uid,
                                      'mainAdmin': next,
                                      'roleIdx': nextRoleIdx,
                                    },
                                    SetOptions(merge: true),
                                  );

                                  await FirestorePaths.userProfileMainDoc(uid).set(
                                    <String, dynamic>{
                                      'uid': uid,
                                      'mainAdmin': next,
                                      'roleIdx': nextRoleIdx,
                                    },
                                    SetOptions(merge: true),
                                  );
                                } finally {
                                  onToggleSavingChanged(false);
                                }
                              },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

