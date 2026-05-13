import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_provider.dart';

class AccountManagementPage extends ConsumerStatefulWidget {
  const AccountManagementPage({super.key});

  @override
  ConsumerState<AccountManagementPage> createState() =>
      _AccountManagementPageState();
}

class _AccountManagementPageState
    extends ConsumerState<AccountManagementPage> {
  final Map<String, TextEditingController> _managerNameControllers = {};
  final Map<String, String?> _selectedRestAreaIds = {};
  bool _hasChanges = false;

  @override
  void dispose() {
    for (var controller in _managerNameControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = ref.watch(currentUserInfoProvider);
    final accounts = ref.watch(accountListProvider);
    final restAreas = ref.watch(restAreaListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('계정관리')),
      body: userInfo.when(
        data: (currentUser) {
          final isAdmin = currentUser?.isAdmin ?? false;
          final canEdit = currentUser?.isApproved ?? false;

          // 일반 관리자인 경우: 자신의 정보만 표시
          if (!isAdmin) {
            return accounts.when(
              data: (allAccounts) {
                final myAccount = allAccounts.firstWhere(
                  (account) => account.email == currentUser?.email,
                  orElse: () => AccountInfo(
                    id: currentUser?.email.split('@')[0] ?? '',
                    email: currentUser?.email ?? '',
                    restAreaId: currentUser?.restAreaId,
                    restAreaName: currentUser?.restAreaName,
                    managerName: null,
                    role: 'rest_area_manager',
                  ),
                );

                if (!_managerNameControllers.containsKey(myAccount.id)) {
                  _managerNameControllers[myAccount.id] =
                      TextEditingController(text: myAccount.managerName ?? '');
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildReadOnlyField('아이디', myAccount.email),
                          const SizedBox(height: 16),
                          _buildReadOnlyField(
                            '관리사업장',
                            myAccount.restAreaName ?? myAccount.restAreaId ?? '미설정',
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _managerNameControllers[myAccount.id],
                            decoration: const InputDecoration(
                              labelText: '담당자명',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: !canEdit,
                            onChanged: (_) {
                              setState(() => _hasChanges = true);
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: canEdit && _hasChanges
                                ? () => _saveMyAccount(myAccount)
                                : null,
                            child: const Text('저장'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('오류: $err')),
            );
          }

          // 전체 관리자인 경우: 모든 계정 표시
          return accounts.when(
            data: (allAccounts) {
              return restAreas.when(
                data: (restAreaList) {
                  // 초기화
                  for (var account in allAccounts) {
                    if (!_managerNameControllers.containsKey(account.id)) {
                      _managerNameControllers[account.id] =
                          TextEditingController(text: account.managerName ?? '');
                    }
                    if (!_selectedRestAreaIds.containsKey(account.id)) {
                      _selectedRestAreaIds[account.id] = account.restAreaId;
                    }
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: allAccounts.length,
                          itemBuilder: (context, index) {
                            final account = allAccounts[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildReadOnlyField('아이디', account.email),
                                    const SizedBox(height: 16),
                                    if (account.role == 'rest_area_manager') ...[
                                      Builder(
                                        builder: (context) {
                                          final currentValue = _selectedRestAreaIds[account.id];
                                          // value가 items에 있는지 확인
                                          final validValue = currentValue != null &&
                                                  restAreaList.any((ra) => ra.id == currentValue)
                                              ? currentValue
                                              : null;
                                          
                                          return DropdownButtonFormField<String>(
                                            value: validValue,
                                            decoration: const InputDecoration(
                                              labelText: '관리사업장',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: [
                                              const DropdownMenuItem<String>(
                                                value: null,
                                                child: Text('미선택'),
                                              ),
                                              ...restAreaList.map((restArea) {
                                                return DropdownMenuItem<String>(
                                                  value: restArea.id,
                                                  child: Text(restArea.name),
                                                );
                                              }),
                                            ],
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedRestAreaIds[account.id] =
                                                    value;
                                                _hasChanges = true;
                                              });
                                            },
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                    ] else
                                      _buildReadOnlyField(
                                        '관리사업장',
                                        account.restAreaName ??
                                            account.restAreaId ??
                                            '미설정',
                                      ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller:
                                          _managerNameControllers[account.id],
                                      decoration: const InputDecoration(
                                        labelText: '담당자명',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (_) {
                                        setState(() => _hasChanges = true);
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    // 승인 상태 표시 및 승인 버튼
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: account.isApproved
                                                  ? Colors.green[50]
                                                  : Colors.orange[50],
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: account.isApproved
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  account.isApproved
                                                      ? Icons.check_circle
                                                      : Icons.pending,
                                                  color: account.isApproved
                                                      ? Colors.green
                                                      : Colors.orange,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  account.isApproved
                                                      ? '승인됨'
                                                      : '승인 대기',
                                                  style: TextStyle(
                                                    color: account.isApproved
                                                        ? Colors.green[900]
                                                        : Colors.orange[900],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (!account.isApproved) ...[
                                          const SizedBox(width: 8),
                                          FilledButton.icon(
                                            onPressed: () => _approveAccount(account),
                                            icon: const Icon(Icons.check),
                                            label: const Text('승인'),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (account.role != 'admin') ...[
                                      const SizedBox(height: 12),
                                      FilledButton.tonalIcon(
                                        onPressed: () => _promoteToMainAdmin(account),
                                        icon: const Icon(Icons.admin_panel_settings),
                                        label: const Text('메인관리자로 지정'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.indigo[50],
                                          foregroundColor: Colors.indigo[900],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _sendPasswordReset(account.email),
                                      icon: const Icon(Icons.lock_reset),
                                      label: const Text('비밀번호 재설정 이메일 보내기'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_hasChanges)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: FilledButton(
                            onPressed: () => _saveAllAccounts(allAccounts),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('모든 변경사항 저장'),
                          ),
                        ),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('오류: $err')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('오류: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            const Center(child: Text('사용자 정보를 불러올 수 없습니다.')),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Future<void> _saveMyAccount(AccountInfo account) async {
    final controller = _managerNameControllers[account.id];
    if (controller == null) return;

    try {
      final updated = AccountInfo(
        id: account.id,
        email: account.email,
        restAreaId: account.restAreaId,
        restAreaName: account.restAreaName,
        managerName: controller.text.trim().isEmpty
            ? null
            : controller.text.trim(),
        role: account.role,
      );

      await ref.read(accountControllerProvider).updateAccount(updated);
      setState(() => _hasChanges = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveAllAccounts(List<AccountInfo> accounts) async {
    try {
      final restAreas = await ref.read(restAreaListProvider.future);
      
      for (var account in accounts) {
        final controller = _managerNameControllers[account.id];
        final selectedRestAreaId = _selectedRestAreaIds[account.id];

        if (controller == null) continue;

        // restAreaId가 변경된 경우, restAreaName도 업데이트
        String? restAreaName = account.restAreaName;
        if (account.role == 'rest_area_manager') {
          if (selectedRestAreaId != null && selectedRestAreaId != account.restAreaId) {
            // 선택된 restAreaId로 이름 찾기
            try {
              final selectedRestArea = restAreas.firstWhere(
                (ra) => ra.id == selectedRestAreaId,
              );
              restAreaName = selectedRestArea.name;
            } catch (e) {
              // 찾지 못한 경우 기존 이름 유지
              restAreaName = account.restAreaName;
            }
          } else if (selectedRestAreaId == null && account.restAreaId != null) {
            // 선택이 해제된 경우
            restAreaName = null;
          }
        }

        final updated = AccountInfo(
          id: account.id,
          email: account.email,
          restAreaId: selectedRestAreaId ?? account.restAreaId,
          restAreaName: restAreaName,
          managerName: controller.text.trim().isEmpty
              ? null
              : controller.text.trim(),
          role: account.role,
        );

        await ref.read(accountControllerProvider).updateAccount(updated);
      }

      setState(() => _hasChanges = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 변경사항이 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendPasswordReset(String email) async {
    try {
      await ref.read(accountControllerProvider).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('비밀번호 재설정 이메일이 $email 로 전송되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이메일 전송 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveAccount(AccountInfo account) async {
    try {
      final updated = AccountInfo(
        id: account.id,
        email: account.email,
        restAreaId: account.restAreaId,
        restAreaName: account.restAreaName,
        managerName: account.managerName,
        role: account.role,
        isApproved: true,
        isGoogleAccount: account.isGoogleAccount,
      );

      await ref.read(accountControllerProvider).updateAccount(updated);
      
      // 사용자 정보 새로고침
      ref.invalidate(currentUserInfoProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('계정이 승인되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('승인 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _promoteToMainAdmin(AccountInfo account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메인관리자 지정'),
        content: Text(
          '${account.email} 계정을 메인관리자로 지정하시겠습니까?\n해당 계정은 모든 메뉴와 계정관리(승인, 메인관리자 지정 등)를 사용할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지정'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref.read(accountControllerProvider).promoteToMainAdmin(account);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('메인관리자로 지정되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('지정 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

