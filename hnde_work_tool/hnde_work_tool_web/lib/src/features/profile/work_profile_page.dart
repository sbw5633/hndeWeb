import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/super_admin.dart';
import '../../repositories/work_firestore_repository.dart';
import '../../models/branch_model.dart';
import '../common/app_user_avatar.dart';
import '../common/enterprise_scaffold.dart';
import '../common/message_alert.dart';
import '../common/merged_user_profile_stream_builder.dart';

class WorkProfilePage extends StatefulWidget {
  const WorkProfilePage({super.key});

  @override
  State<WorkProfilePage> createState() => _WorkProfilePageState();
}

class _WorkProfilePageState extends State<WorkProfilePage> {
  late final WorkFirestoreRepository _repo;
  final TextEditingController _nameC = TextEditingController();
  final TextEditingController _emailC = TextEditingController();
  final TextEditingController _phoneC = TextEditingController();

  bool _init = false;
  bool _saving = false;
  String _branch = '';
  String? _pendingBranch;
  String? _pendingStatus;
  PlatformFile? _localPhoto;
  String? _photoUrl;
  late final Stream<List<BranchModel>> _branchesStream;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
    _branchesStream = _repo.watchBranches();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    setState(() => _localPhoto = r.files.single);
  }

  Future<bool> _confirmNameChangeIfNeeded(String before, String after) async {
    if (before.trim() == after.trim()) return true;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('이름 변경 확인'),
          content: const Text(
            '본명이 아닌 이름으로 변경하면 다른 직원이 알아보기 어려울 수 있습니다.\n'
            '그래도 변경할까요?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('변경'),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  Future<void> _save(String uid, Map<String, dynamic> prof) async {
    if (_saving) return;
    final String beforeName = (prof['name'] as String?) ?? '';
    final String nextName = _nameC.text.trim();
    final bool ok = await _confirmNameChangeIfNeeded(beforeName, nextName);
    if (!ok || !mounted) return;

    setState(() => _saving = true);
    try {
      String? uploadedUrl = _photoUrl;
      if (_localPhoto != null) {
        uploadedUrl = await _repo.uploadProfilePhotoAndGetUrl(_localPhoto!);
      }

      final Map<String, dynamic> patch = <String, dynamic>{
        'name': nextName,
        'displayName': nextName,
        'email': _emailC.text.trim(),
        'phone': _phoneC.text.trim(),
        if (uploadedUrl != null) 'photoUrl': uploadedUrl,
      };

      await _repo.updateUserAndProfile(uid: uid, userPatch: patch, profilePatch: patch);

      // 소속 변경은 즉시 적용하지 않고 요청만 저장
      final String selectedBranch = _branch.trim();
      final String currentBranch =
          (prof['branchName'] as String?) ?? (prof['branch'] as String?) ?? '';
      if (selectedBranch.isNotEmpty && selectedBranch != currentBranch) {
        await _repo.requestBranchChange(uid: uid, nextBranchName: selectedBranch);
      }

      if (mounted) {
        setState(() {
          _saving = false;
          _localPhoto = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessageAlert(context, message: '$e', title: '저장 실패');
      }
    }
  }

  Future<void> _cancelPendingBranch(String uid) async {
    try {
      await _repo.cancelBranchChangeRequest(uid: uid);
    } catch (e) {
      if (mounted) {
        showMessageAlert(context, message: '$e', title: '취소 실패');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const EnterpriseScaffold(
        title: '프로필',
        child: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return MergedUserProfileStreamBuilder(
      uid: user.uid,
      builder: (
        BuildContext context,
        Map<String, dynamic> d,
        bool streamsWaiting,
      ) {
        if (streamsWaiting && d.isEmpty) {
          return const EnterpriseScaffold(
            title: '프로필',
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final String nameInDb = (d['name'] as String?)?.trim() ?? '';
        final String branchInDb =
            (d['branchName'] as String?)?.trim().isNotEmpty == true
                ? (d['branchName'] as String).trim()
                : ((d['branch'] as String?)?.trim() ?? '');
        final bool mainAdmin = SuperAdmin.effectiveMainAdmin(
          profileMainAdmin: d['mainAdmin'],
          profileEmail: d['email'] as String?,
          authEmail: user.email,
          roleIdx: (d['roleIdx'] as num?)?.toInt(),
        );
        // hqViewerMode: 현재 UI/권한 분기에 사용하지 않으므로 설정에서 제거합니다.
        final String? pendingBranch = (d['pendingBranch'] as String?)?.trim();
        final String? pendingStatus = (d['pendingBranchStatus'] as String?)?.trim();
        final String photoUrl = (d['photoUrl'] as String?)?.trim() ?? '';

        if (!_init && (d.isNotEmpty || !streamsWaiting)) {
          _init = true;
          _nameC.text = nameInDb.isNotEmpty ? nameInDb : (user.email ?? '');
          _emailC.text = (d['email'] as String?)?.trim() ?? (user.email ?? '');
          _phoneC.text = (d['phone'] as String?)?.trim() ?? '';
          _branch = branchInDb.isNotEmpty ? branchInDb : '';
          _pendingBranch = pendingBranch;
          _pendingStatus = pendingStatus;
          _photoUrl = photoUrl.isEmpty ? null : photoUrl;
        } else {
          _pendingBranch = pendingBranch;
          _pendingStatus = pendingStatus;
          _photoUrl = photoUrl.isEmpty ? null : photoUrl;
          // 스냅샷이 업데이트되어도 사용자가 편집중인 값을 덮어쓰지 않음.
          // 다만 컨트롤러가 비어있고 DB 값이 있으면 최초 보정.
          if (_nameC.text.trim().isEmpty && nameInDb.isNotEmpty) {
            _nameC.text = nameInDb;
          }
          if (_branch.trim().isEmpty && branchInDb.isNotEmpty) {
            _branch = branchInDb;
          }
        }

        return EnterpriseScaffold(
          title: '프로필',
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '개인설정 변경',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _save(user.uid, d),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: const Text('저장'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _localPhoto?.bytes != null
                                ? Image.memory(
                                    _localPhoto!.bytes!,
                                    fit: BoxFit.cover,
                                  )
                                : AppUserAvatar(
                                    size: 72,
                                    photoUrl: _photoUrl,
                                    fallbackText: _nameC.text,
                                    backgroundColor: Colors.grey.shade100,
                                    foregroundColor: Colors.grey,
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _pickPhoto,
                              icon: const Icon(Icons.photo_camera_outlined, size: 18),
                              label: const Text('이미지 변경'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameC,
                        decoration: const InputDecoration(
                          labelText: '이름',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<List<BranchModel>>(
                        stream: _branchesStream,
                        builder: (context, bSnap) {
                          final List<String> branches = (bSnap.data ?? <BranchModel>[])
                              .map((b) => b.name.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          final bool loadingBranches =
                              bSnap.connectionState == ConnectionState.waiting && !bSnap.hasData;
                          final List<String> items = branches.isNotEmpty
                              ? branches
                              : (_branch.trim().isNotEmpty ? <String>[_branch.trim()] : <String>[]);

                          if (_branch.trim().isEmpty && branches.isNotEmpty) {
                            _branch = branches.first;
                          }
                          final bool hasValue = items.contains(_branch);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              DropdownButtonFormField<String>(
                                value: hasValue ? _branch : (items.isNotEmpty ? items.first : null),
                                decoration: const InputDecoration(
                                  labelText: '소속',
                                  border: OutlineInputBorder(),
                                ),
                                items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (_saving || loadingBranches || items.isEmpty)
                                    ? null
                                    : (v) => setState(() => _branch = v ?? _branch),
                              ),
                              if ((_pendingBranch ?? '').isNotEmpty &&
                                  (_pendingStatus ?? '') == 'pending') ...<Widget>[
                                const SizedBox(height: 6),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        '메인관리자의 승인 대기중입니다.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _saving ? null : () => _cancelPendingBranch(user.uid),
                                      child: const Text('변경 취소'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailC,
                        decoration: const InputDecoration(
                          labelText: '이메일',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneC,
                        decoration: const InputDecoration(
                          labelText: '연락처',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (mainAdmin)
                        ListTile(
                          leading: const Icon(Icons.settings),
                          title: const Text('시스템 설정'),
                          onTap: () => context.go('/settings'),
                        ),
                      ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: const Text('앱 설정'),
                        onTap: () => context.go('/my-settings'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('로그아웃'),
              ),
              ],
            ),
          ),
        );
      },
    );
  }
}
