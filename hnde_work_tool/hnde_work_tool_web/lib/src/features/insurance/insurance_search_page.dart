import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/firestore_paths.dart';
import '../../constants/insurance_status.dart';
import '../../constants/insurance_types.dart';
import '../../constants/role_constants.dart';
import '../common/enterprise_scaffold.dart';
import '../common/loading_widget.dart';

class InsuranceSearchPage extends StatefulWidget {
  const InsuranceSearchPage({super.key});

  @override
  State<InsuranceSearchPage> createState() => _InsuranceSearchPageState();
}

class _InsuranceSearchPageState extends State<InsuranceSearchPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rrnPrefixController = TextEditingController();

  QuerySnapshot<Map<String, dynamic>>? _result;
  bool _isSearching = false;

  @override
  void dispose() {
    _nameController.dispose();
    _rrnPrefixController.dispose();
    super.dispose();
  }

  Future<void> _search(int roleIdx, String userBranch) async {
    setState(() {
      _isSearching = true;
    });

    Query<Map<String, dynamic>> baseQuery =
        FirestorePaths.insuranceStatusCol();

    if (RoleConstants.isHqAdminOnly(roleIdx)) {
      baseQuery = baseQuery.where('branchName', isEqualTo: '본사');
    } else if (RoleConstants.isBranchAdminOnly(roleIdx)) {
      baseQuery = baseQuery.where(
        'branchName',
        isEqualTo: userBranch.isNotEmpty ? userBranch : '__no_branch__',
      );
    }

    if (_nameController.text.trim().isNotEmpty) {
      baseQuery =
          baseQuery.where('name', isEqualTo: _nameController.text.trim());
    }
    if (_rrnPrefixController.text.trim().isNotEmpty) {
      baseQuery = baseQuery.where(
        'rrnPrefix',
        isEqualTo: _rrnPrefixController.text.trim(),
      );
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await baseQuery.get();

    if (mounted) {
      setState(() {
        _result = snapshot;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final DocumentReference<Map<String, dynamic>>? profileRef =
        uid == null ? null : FirestorePaths.userProfileMainDoc(uid);

    if (profileRef == null) {
      return EnterpriseScaffold(
        title: '4대보험 · 직원 검색',
        child: const Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileRef.snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> profSnap,
      ) {
        final Map<String, dynamic> prof =
            profSnap.data?.data() ?? <String, dynamic>{};
        final int roleIdx =
            (prof['roleIdx'] as num?)?.toInt() ?? RoleConstants.unspecified;
        final String userBranch = prof['branchName'] as String? ?? '';

        return EnterpriseScaffold(
          title: '4대보험 · 직원 검색',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '직원 검색',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '성명',
                        hintText: '예) 홍길동',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _rrnPrefixController,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: '주민번호 앞 6자리',
                        hintText: '990101',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isSearching
                        ? null
                        : () => _search(roleIdx, userBranch),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('검색'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildResult(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResult() {
    if (_isSearching) {
      return const Center(child: LoadingWidget(size: 80));
    }
    if (_result == null) {
      return const Center(
        child: Text(
          '검색 조건을 입력한 후 상단의 검색 버튼을 눌러 주세요.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    if (_result!.docs.isEmpty) {
      return const Center(
        child: Text(
          '조건에 해당하는 직원이 없습니다.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> data = _result!.docs[index].data();
        final String name = data['name'] as String? ?? '-';
        final String resignation =
            (data['resignationDate'] as String?)?.trim() ?? '';
        final String status = InsuranceStatus.deriveFromMap(data);

        final List<String> dateParts = <String>[];
        for (final key in InsuranceTypes.all) {
          final String a = (data[InsuranceTypes.acquiredField(key)] as String?)?.trim() ?? '';
          final String l = (data[InsuranceTypes.lossField(key)] as String?)?.trim() ?? '';
          if (a.isNotEmpty || l.isNotEmpty) {
            dateParts.add('${InsuranceTypes.label(key)}: ${a.isEmpty ? '-' : "취득 $a"}${l.isEmpty ? '' : " 상실 $l"}');
          }
        }
        if (dateParts.isEmpty) {
          final String a = (data['acquiredDate'] as String?)?.trim() ?? '';
          final String l = (data['lossDate'] as String?)?.trim() ?? '';
          if (a.isNotEmpty || l.isNotEmpty || resignation.isNotEmpty) {
            dateParts.addAll(<String>[
              a.isEmpty ? '-' : '취득 $a',
              l.isEmpty ? '' : '상실 $l',
            ].where((s) => s.isNotEmpty));
          }
        }
        if (resignation.isNotEmpty) dateParts.add('퇴사 $resignation');
        final String dates = dateParts.join(' / ');

        Color statusColor = Colors.greenAccent;
        if (InsuranceStatus.isLost(status)) statusColor = Colors.orangeAccent;
        if (InsuranceStatus.isResigned(status)) statusColor = Colors.grey;

        return ListTile(
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(dates.isEmpty ? '(이력 없음)' : dates),
          trailing: Text(
            status,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: _result!.docs.length,
    );
  }
}

