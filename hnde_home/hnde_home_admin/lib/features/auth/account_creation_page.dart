import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_provider.dart';
import '../../core/firestore_service.dart';

class AccountCreationPage extends ConsumerStatefulWidget {
  final String email;
  final bool isGoogleAccount;

  const AccountCreationPage({
    super.key,
    required this.email,
    this.isGoogleAccount = false,
  });

  @override
  ConsumerState<AccountCreationPage> createState() => _AccountCreationPageState();
}

class _AccountCreationPageState extends ConsumerState<AccountCreationPage> {
  String? _selectedRestAreaId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final restAreas = ref.watch(restAreaListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('계정 정보 입력'),
        automaticallyImplyLeading: false, // 뒤로가기 버튼 숨김
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '계정 정보를 입력해주세요',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 이메일 (비활성화)
                  TextFormField(
                    initialValue: widget.email,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      enabled: false,
                    ),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  // 비밀번호 (구글 계정인 경우 비활성화)
                  if (!widget.isGoogleAccount)
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '비밀번호',
                      ),
                      obscureText: true,
                    )
                  else
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '비밀번호',
                        enabled: false,
                        helperText: '구글 계정은 비밀번호가 필요하지 않습니다.',
                      ),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 16),
                  // 사업소 선택
                  restAreas.when(
                    data: (restAreaList) {
                      return DropdownButtonFormField<String>(
                        value: _selectedRestAreaId,
                        decoration: const InputDecoration(
                          labelText: '관리 사업소',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('선택하세요'),
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
                            _selectedRestAreaId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return '사업소를 선택해주세요';
                          }
                          return null;
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('사업소 목록을 불러올 수 없습니다.'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('계정 생성'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_selectedRestAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사업소를 선택해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestoreService = FirestoreService();
      final restAreas = await ref.read(restAreaListProvider.future);
      final selectedRestArea = restAreas.firstWhere(
        (ra) => ra.id == _selectedRestAreaId,
      );

      // 이메일을 docId로 사용 (구글 계정의 경우 이메일을 안전하게 변환)
      final docId = widget.email.replaceAll('.', '_').replaceAll('@', '_at_');

      // Firestore에 계정 정보 저장
      await firestoreService.saveDocument(
        FirestoreCollections.restAreaManagers,
        {
          'email': widget.email,
          'restAreaId': _selectedRestAreaId,
          'restAreaName': selectedRestArea.name,
          'role': 'rest_area_manager',
          'isApproved': false, // 승인 필요
          'isGoogleAccount': widget.isGoogleAccount,
          'createdAt': DateTime.now().toIso8601String(),
        },
        docId: docId,
      );

      // 사용자 정보 새로고침
      ref.invalidate(currentUserInfoProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('계정이 생성되었습니다. 관리자 승인을 기다려주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
        // 홈으로 이동
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('계정 생성 실패: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

