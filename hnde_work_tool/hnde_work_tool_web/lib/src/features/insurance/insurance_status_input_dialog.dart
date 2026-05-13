import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../constants/firestore_paths.dart';
import '../../constants/insurance_types.dart';
import '../../constants/role_constants.dart';
import '../../models/branch_model.dart';
import '../../repositories/work_firestore_repository.dart';
import '../../utils/rrn_validation.dart';
import '../common/loading_widget.dart';
import '../common/message_alert.dart';

Future<void> showInsuranceStatusInputDialog(BuildContext context) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) =>
        _InsuranceStatusInputDialog(scaffoldMessenger: messenger),
  );
}

/// 기존 문서를 수정할 때 사용
Future<void> showInsuranceStatusEditDialog(
  BuildContext context, {
  required DocumentReference<Map<String, dynamic>> docRef,
  required Map<String, dynamic> initialData,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => _InsuranceStatusEditDialog(
      scaffoldMessenger: messenger,
      docRef: docRef,
      initialData: initialData,
    ),
  );
}

class _InsuranceStatusInputDialog extends StatefulWidget {
  const _InsuranceStatusInputDialog({this.scaffoldMessenger});

  final ScaffoldMessengerState? scaffoldMessenger;

  @override
  State<_InsuranceStatusInputDialog> createState() =>
      _InsuranceStatusInputDialogState();
}

class _InsuranceStatusInputDialogState extends State<_InsuranceStatusInputDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<_InputRow> _rows = <_InputRow>[];
  bool _saving = false;
  String _selectedBranch = '';
  String _effectiveBranch = '';
  final Set<String> _selectedInsurances = <String>{
    InsuranceTypes.national,
    InsuranceTypes.health,
    InsuranceTypes.employment,
    InsuranceTypes.industrial,
  };

  @override
  void initState() {
    super.initState();
    _addRow();
  }

  void _addRow() {
    setState(() => _rows.add(_InputRow()));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  @override
  void dispose() {
    for (final _InputRow r in _rows) r.dispose();
    super.dispose();
  }

  String? _parseDate(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  Future<void> _save(String branchName) async {
    if (_formKey.currentState?.validate() != true) return;
    if (branchName.isEmpty) return;

    setState(() => _saving = true);
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('로그인 필요');

      final CollectionReference<Map<String, dynamic>> col =
          FirestorePaths.insuranceStatusCol();

      // 주민번호로 기존 등록 여부 확인
      for (final _InputRow r in _rows) {
        final String rrnRaw = r.rrn.text.replaceAll(RegExp(r'\D'), '');
        if (rrnRaw.length != 13) continue;
        final String rrnFormatted = formatRrn(rrnRaw);

        final QuerySnapshot<Map<String, dynamic>> existing = await col
            .where('rrn', isEqualTo: rrnFormatted)
            .where('branchName', isEqualTo: branchName)
            .get();
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> sorted =
            existing.docs.toList()
              ..sort((a, b) {
                final at = a.data()['createdAt'] as Timestamp?;
                final bt = b.data()['createdAt'] as Timestamp?;
                if (at == null && bt == null) return 0;
                if (at == null) return 1;
                if (bt == null) return -1;
                return bt.compareTo(at);
              });

        if (sorted.isNotEmpty && mounted) {
          final bool? update = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext ctx) => _ExistingRecordDialog(
              name: r.name.text.trim(),
              rrnFormatted: rrnFormatted,
              existingDocs: sorted,
            ),
          );
          if (update == true && mounted) {
            Navigator.of(context).pop(); // 입력 다이얼로그 닫기
            final doc = sorted.first;
            if (context.mounted) {
              await showInsuranceStatusEditDialog(
                context,
                docRef: doc.reference,
                initialData: doc.data(),
              );
              // 수정 다이얼로그 내부에서 SnackBar 표시
            }
          }
          if (mounted) setState(() => _saving = false);
          return;
        }
      }

      final WriteBatch batch = FirebaseFirestore.instance.batch();
      for (final _InputRow r in _rows) {
        final String rrnRaw = r.rrn.text.replaceAll(RegExp(r'\D'), '');
        final String rrnFormatted = formatRrn(rrnRaw);
        final docRef = col.doc();

        final Map<String, dynamic> docData = <String, dynamic>{
          'name': r.name.text.trim(),
          'rrn': rrnFormatted,
          'rrnPrefix': rrnRaw.length >= 6 ? rrnRaw.substring(0, 6) : '',
          'hireDate': _parseDate(r.hireDate.text),
          'resignationDate': _parseDate(r.resignationDate.text),
          'branchName': branchName,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': uid,
        };
        for (final key in InsuranceTypes.all) {
          docData[InsuranceTypes.acquiredField(key)] =
              r.getAcquired(key) ?? '';
          docData[InsuranceTypes.lossField(key)] = r.getLoss(key) ?? '';
        }
        batch.set(docRef, docData);
      }

      await batch.commit();
      if (mounted) {
        await showMessageAlert(context, message: '저장되었습니다.');
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showMessageAlert(context, message: '저장 실패: $e', title: '저장 실패');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final DocumentReference<Map<String, dynamic>>? profileRef =
        uid == null ? null : FirestorePaths.userProfileMainDoc(uid);

    return AlertDialog(
      title: const Text('4대보험 취득 내역 신규 입력'),
      content: SizedBox(
        width: 720,
        child: profileRef == null
            ? const Center(child: LoadingWidget(size: 80))
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: profileRef.snapshots(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> profSnap,
                ) {
                  final Map<String, dynamic> prof =
                      profSnap.data?.data() ?? <String, dynamic>{};
                  final int roleIdx =
                      (prof['roleIdx'] as num?)?.toInt() ?? RoleConstants.unspecified;
                  final String userBranch =
                      prof['branchName'] as String? ?? '';

                  String effectiveBranch = _selectedBranch;
                  if (RoleConstants.canViewAllBranches(roleIdx)) {
                    effectiveBranch = userBranch.isNotEmpty ? userBranch : '본사';
                    if (_effectiveBranch != effectiveBranch) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _effectiveBranch = effectiveBranch);
                      });
                    }
                  } else if (RoleConstants.isHqAdminOnly(roleIdx)) {
                    effectiveBranch = '본사';
                  } else if (RoleConstants.isBranchAdminOnly(roleIdx)) {
                    effectiveBranch = userBranch.isNotEmpty ? userBranch : '';
                  }

                  if (_saving) {
                    return const Center(child: LoadingWidget(size: 80));
                  }

                  return Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _InsuranceTypeCheckboxes(
                            selected: _selectedInsurances,
                            onChanged: (String key, bool value) {
                              setState(() {
                                if (value) {
                                  _selectedInsurances.add(key);
                                } else {
                                  _selectedInsurances.remove(key);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          if (RoleConstants.canViewAllBranches(roleIdx))
                            _BranchSelector(
                              selected: _selectedBranch.isEmpty
                                  ? effectiveBranch
                                  : _selectedBranch,
                              onChanged: (String v) =>
                                  setState(() => _selectedBranch = v),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                '사업소: $effectiveBranch',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ...List<Widget>.generate(_rows.length, (int i) {
                            return _InputRowWidget(
                              row: _rows[i],
                              index: i,
                              selectedInsurances: _selectedInsurances,
                              onRemove: _rows.length > 1
                                  ? () => _removeRow(i)
                                  : null,
                            );
                          }),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _addRow,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('행 추가'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        Builder(
          builder: (BuildContext ctx) {
            final String? uid2 = FirebaseAuth.instance.currentUser?.uid;
            final docRef =
                uid2 == null ? null : FirestorePaths.userProfileMainDoc(uid2);
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: docRef?.snapshots(),
              builder: (
                BuildContext context,
                AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> ps,
              ) {
                final Map<String, dynamic> p = ps.data?.data() ?? {};
                final int ri =
                    (p['roleIdx'] as num?)?.toInt() ?? RoleConstants.unspecified;
                final String ub = p['branchName'] as String? ?? '';
                String saveBranch = RoleConstants.canViewAllBranches(ri)
                    ? (_selectedBranch.isNotEmpty ? _selectedBranch : _effectiveBranch)
                    : (RoleConstants.isHqAdminOnly(ri) ? '본사' : ub);
                return FilledButton.icon(
                  onPressed: _saving || saveBranch.isEmpty
                      ? null
                      : () => _save(saveBranch),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('저장'),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ExistingRecordDialog extends StatelessWidget {
  const _ExistingRecordDialog({
    required this.name,
    required this.rrnFormatted,
    required this.existingDocs,
  });

  final String name;
  final String rrnFormatted;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> existingDocs;

  @override
  Widget build(BuildContext context) {
    final String maskedRrn = rrnFormatted.length >= 7
        ? '${rrnFormatted.substring(0, 6)}-*******'
        : rrnFormatted;
    return AlertDialog(
      title: const Text('이미 등록된 인원'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '$name 님($maskedRrn)은(는) 이미 등록되어 있습니다.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              '기존 내역:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 12,
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  dataTextStyle: const TextStyle(fontSize: 11),
                  columns: <DataColumn>[
                    const DataColumn(label: Text('입사일')),
                    const DataColumn(label: Text('퇴사일')),
                    ...InsuranceTypes.all.expand((k) => <DataColumn>[
                          DataColumn(
                            label: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    InsuranceTypes.fullLabel(k),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '취득일',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  const SizedBox(height: 22),
                                  Text(
                                    '상실일',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]),
                    const DataColumn(label: Text('사업소')),
                  ],
                  rows: existingDocs.map((doc) {
                    final d = doc.data();
                    String getDate(String key, bool acquired) {
                      final f = acquired
                          ? InsuranceTypes.acquiredField(key)
                          : InsuranceTypes.lossField(key);
                      final v = d[f] as String?;
                      return (v != null && v.isNotEmpty) ? v : '-';
                    }
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(Text((d['hireDate'] as String?) ?? '-')),
                        DataCell(Text((d['resignationDate'] as String?) ?? '-')),
                        ...InsuranceTypes.all.map(
                          (k) => DataCell(Text(getDate(k, true))),
                        ),
                        ...InsuranceTypes.all.map(
                          (k) => DataCell(Text(getDate(k, false))),
                        ),
                        DataCell(Text((d['branchName'] as String?) ?? '-')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '기존 내역을 업데이트하시겠습니까?',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('아니오'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('예, 업데이트'),
        ),
      ],
    );
  }
}

class _InsuranceStatusEditDialog extends StatefulWidget {
  const _InsuranceStatusEditDialog({
    this.scaffoldMessenger,
    required this.docRef,
    required this.initialData,
  });

  final ScaffoldMessengerState? scaffoldMessenger;
  final DocumentReference<Map<String, dynamic>> docRef;
  final Map<String, dynamic> initialData;

  @override
  State<_InsuranceStatusEditDialog> createState() =>
      _InsuranceStatusEditDialogState();
}

class _InsuranceStatusEditDialogState extends State<_InsuranceStatusEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _rrn;
  late final TextEditingController _hireDate;
  late final TextEditingController _resignationDate;
  final Map<String, TextEditingController> _acquired = {};
  final Map<String, TextEditingController> _loss = {};
  bool _saving = false;
  bool _deleting = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static String _str(dynamic v) =>
      (v is String && v.trim().isNotEmpty) ? v.trim() : '';

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _name = TextEditingController(text: d['name'] as String? ?? '');
    _rrn = TextEditingController(text: d['rrn'] as String? ?? '');
    _hireDate = TextEditingController(text: d['hireDate'] as String? ?? '');
    _resignationDate =
        TextEditingController(text: d['resignationDate'] as String? ?? '');
    for (final key in InsuranceTypes.all) {
      String a = _str(d[InsuranceTypes.acquiredField(key)]);
      String l = _str(d[InsuranceTypes.lossField(key)]);
      if (a.isEmpty && key == InsuranceTypes.national) {
        a = _str(d['acquiredDate']);
      }
      if (l.isEmpty && key == InsuranceTypes.national) {
        l = _str(d['lossDate']);
      }
      _acquired[key] = TextEditingController(text: a);
      _loss[key] = TextEditingController(text: l);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _rrn.dispose();
    _hireDate.dispose();
    _resignationDate.dispose();
    for (final c in _acquired.values) c.dispose();
    for (final c in _loss.values) c.dispose();
    super.dispose();
  }

  String? _parseDate(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  Future<void> _save() async {
    final formState = _formKey.currentState;
    if (formState?.validate() != true) return;

    setState(() => _saving = true);
    try {
      final String rrnRaw = _rrn.text.replaceAll(RegExp(r'\D'), '');
      final String rrnFormatted = formatRrn(rrnRaw);
      final Map<String, dynamic> updates = <String, dynamic>{
        'name': _name.text.trim(),
        'rrn': rrnFormatted,
        'rrnPrefix': rrnRaw.length >= 6 ? rrnRaw.substring(0, 6) : '',
        'hireDate': _parseDate(_hireDate.text),
        'resignationDate': _parseDate(_resignationDate.text),
      };
      for (final key in InsuranceTypes.all) {
        updates[InsuranceTypes.acquiredField(key)] =
            _parseDate(_acquired[key]!.text) ?? '';
        updates[InsuranceTypes.lossField(key)] =
            _parseDate(_loss[key]!.text) ?? '';
      }
      await widget.docRef.update(updates);
      if (mounted) {
        await showMessageAlert(context, message: '수정되었습니다.');
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showMessageAlert(context, message: '수정 실패: $e', title: '수정 실패');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmPermanentDelete() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('완전 삭제'),
        content: const Text(
          '이 취득 내역을 데이터베이스에서 완전히 삭제합니다. 되돌릴 수 없습니다. 진행할까요?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('아니오'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('예, 삭제'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _performPermanentDelete();
  }

  Future<void> _performPermanentDelete() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final DocumentSnapshot<Map<String, dynamic>> profSnap =
        await FirestorePaths.userProfileMainDoc(uid).get();
    final Map<String, dynamic> prof =
        profSnap.data() ?? <String, dynamic>{};
    final int roleIdx =
        (prof['roleIdx'] as num?)?.toInt() ?? RoleConstants.unspecified;
    if (roleIdx != RoleConstants.mainAdmin) {
      if (mounted) {
        await showMessageAlert(
          context,
          message:
              '완전 삭제는 프로필의 roleIdx가 메인관리자(0)인 계정만 가능합니다.',
          title: '권한 없음',
        );
      }
      return;
    }

    setState(() => _deleting = true);
    try {
      await widget.docRef.delete();
      if (mounted) {
        await showMessageAlert(context, message: '삭제되었습니다.');
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        await showMessageAlert(context, message: '삭제 실패: $e', title: '삭제 실패');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _editFormFields() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: '홍길동',
            ),
            validator: (String? v) =>
                (v == null || v.trim().isEmpty) ? '이름을 입력해 주세요.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _rrn,
            decoration: const InputDecoration(
              labelText: '주민등록번호',
              hintText: '900101-1234567',
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            maxLength: 14,
            inputFormatters: digitHyphenFormatters,
            validator: validateRrn,
            onChanged: (String v) {
              if (v.length == 6 && !v.contains('-')) {
                _rrn.text = '$v-';
                _rrn.selection = const TextSelection.collapsed(offset: 7);
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: _hireDate,
                  decoration: const InputDecoration(
                    labelText: '입사일',
                    hintText: 'YYYY-MM-DD',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: digitHyphenFormatters,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _resignationDate,
                  decoration: const InputDecoration(
                    labelText: '퇴사일',
                    hintText: 'YYYY-MM-DD',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: digitHyphenFormatters,
                ),
              ),
            ],
          ),
          ...InsuranceTypes.all.map((String key) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      InsuranceTypes.fullLabel(key),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _acquired[key],
                            decoration: const InputDecoration(
                              labelText: '취득일',
                              hintText: 'YYYY-MM-DD',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: digitHyphenFormatters,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _loss[key],
                            decoration: const InputDecoration(
                              labelText: '상실일',
                              hintText: 'YYYY-MM-DD',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: digitHyphenFormatters,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEditFooter(
    BuildContext context,
    DocumentReference<Map<String, dynamic>>? profileRef,
  ) {
    if (profileRef == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          TextButton(
            onPressed:
                _saving || _deleting ? null : () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _saving || _deleting ? null : _save,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('저장'),
          ),
        ],
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
        final bool canPermanentDelete =
            roleIdx == RoleConstants.mainAdmin;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (canPermanentDelete)
              TextButton(
                onPressed:
                    _saving || _deleting ? null : _confirmPermanentDelete,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: _deleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('완전삭제'),
              )
            else
              const SizedBox.shrink(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextButton(
                  onPressed: _saving || _deleting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving || _deleting ? null : _save,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('저장'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenH = MediaQuery.sizeOf(context).height;
    final double dialogH = (screenH * 0.88).clamp(320.0, screenH - 24);
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final DocumentReference<Map<String, dynamic>>? profileRef =
        uid == null ? null : FirestorePaths.userProfileMainDoc(uid);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 520,
        height: dialogH,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '4대보험 내역 수정',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: _editFormFields(),
                ),
              ),
              const SizedBox(height: 16),
              _buildEditFooter(context, profileRef),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  const _BranchSelector({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final WorkFirestoreRepository _repo = context.read<WorkFirestoreRepository>();
    return StreamBuilder<List<BranchModel>>(
      stream: _repo.watchBranches(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<BranchModel>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 56,
              child: Center(child: LoadingWidget(size: 24)),
            ),
          );
        }
        final List<BranchModel> branches = snapshot.data ?? <BranchModel>[];
        final List<String> names =
            branches.map((BranchModel b) => b.name).toList();
        if (names.isEmpty) names.add('본사');
        final String currentValue =
            names.contains(selected) ? selected : (names.isNotEmpty ? names.first : '본사');
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: currentValue,
            decoration: const InputDecoration(
              labelText: '사업소',
              border: OutlineInputBorder(),
            ),
            items: names
                .map((String n) => DropdownMenuItem<String>(
                      value: n,
                      child: Text(n),
                    ))
                .toList(),
            onChanged: (String? v) {
              if (v != null) onChanged(v);
            },
          ),
        );
      },
    );
  }
}

class _InputRow {
  _InputRow() {
    name = TextEditingController();
    rrn = TextEditingController();
    hireDate = TextEditingController();
    resignationDate = TextEditingController();
    for (final key in InsuranceTypes.all) {
      acquiredControllers[key] = TextEditingController();
      lossControllers[key] = TextEditingController();
    }
  }

  late final TextEditingController name;
  late final TextEditingController rrn;
  late final TextEditingController hireDate;
  late final TextEditingController resignationDate;
  final Map<String, TextEditingController> acquiredControllers = {};
  final Map<String, TextEditingController> lossControllers = {};

  String? getAcquired(String key) => _parse(acquiredControllers[key]?.text);
  String? getLoss(String key) => _parse(lossControllers[key]?.text);
  static String? _parse(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  void dispose() {
    name.dispose();
    rrn.dispose();
    hireDate.dispose();
    resignationDate.dispose();
    for (final c in acquiredControllers.values) c.dispose();
    for (final c in lossControllers.values) c.dispose();
  }
}

class _InsuranceTypeCheckboxes extends StatelessWidget {
  const _InsuranceTypeCheckboxes({
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final void Function(String key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            const Text(
              '4대보험 선택:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 16),
            ...InsuranceTypes.all.map((key) {
              final isSelected = selected.contains(key);
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: () => onChanged(key, !isSelected),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Checkbox(
                        value: isSelected,
                        onChanged: (bool? v) =>
                            onChanged(key, v ?? false),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      Text(InsuranceTypes.label(key)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _InputRowWidget extends StatelessWidget {
  const _InputRowWidget({
    required this.row,
    required this.index,
    required this.selectedInsurances,
    this.onRemove,
  });

  final _InputRow row;
  final int index;
  final Set<String> selectedInsurances;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${index + 1}행',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: '행 삭제',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: row.name,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      hintText: '홍길동',
                    ),
                    validator: (String? v) =>
                        (v == null || v.trim().isEmpty) ? '이름을 입력해 주세요.' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: row.rrn,
                    decoration: const InputDecoration(
                      labelText: '주민등록번호',
                      hintText: '900101-1234567',
                      counterText: '',
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 14,
                    inputFormatters: digitHyphenFormatters,
                    validator: validateRrn,
                    onChanged: (String v) {
                      if (v.length == 6 && !v.contains('-')) {
                        row.rrn.text = '$v-';
                        row.rrn.selection = TextSelection.fromPosition(
                          const TextPosition(offset: 7),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: row.hireDate,
                    decoration: const InputDecoration(
                      labelText: '입사일',
                      hintText: 'YYYY-MM-DD',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: digitHyphenFormatters,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: row.resignationDate,
                    decoration: const InputDecoration(
                      labelText: '퇴사일',
                      hintText: 'YYYY-MM-DD',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: digitHyphenFormatters,
                  ),
                ),
              ],
            ),
            ...selectedInsurances.isEmpty
                ? <Widget>[]
                : InsuranceTypes.all
                    .where(selectedInsurances.contains)
                    .map((key) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            InsuranceTypes.fullLabel(key),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: TextFormField(
                                  controller: row.acquiredControllers[key],
                                  decoration: const InputDecoration(
                                    labelText: '취득일',
                                    hintText: 'YYYY-MM-DD',
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: digitHyphenFormatters,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: row.lossControllers[key],
                                  decoration: const InputDecoration(
                                    labelText: '상실일',
                                    hintText: 'YYYY-MM-DD',
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: digitHyphenFormatters,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
          ],
        ),
      ),
    );
  }
}
