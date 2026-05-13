import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/firestore_paths.dart';
import '../../services/kakao_local_service.dart';
import 'address_search_dialog.dart';

const String _kGroupHdne = 'HDNE_MAIN';
const String _kGroupTheway = 'THEWAY_MAIN';

/// Firestore `branches` 문서 편집 — 주소는 카카오 검색으로 좌표 확정
class FirestoreBranchEditForm extends StatefulWidget {
  const FirestoreBranchEditForm({
    super.key,
    required this.initial,
    required this.onBack,
    required this.isNew,
  });

  final Map<String, dynamic> initial;
  final VoidCallback onBack;
  final bool isNew;

  @override
  State<FirestoreBranchEditForm> createState() =>
      _FirestoreBranchEditFormState();
}

class _FirestoreBranchEditFormState extends State<FirestoreBranchEditForm> {
  late final TextEditingController _idCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _headCtrl;

  late String _groupKey;
  double? _lat;
  double? _lng;

  bool _saving = false;
  final KakaoLocalService _kakao = KakaoLocalService();

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> d = widget.initial;
    _idCtrl = TextEditingController(text: (d['id'] as String?) ?? '');
    _nameCtrl = TextEditingController(text: (d['name'] as String?) ?? '');
    _addressCtrl = TextEditingController(text: (d['address'] as String?) ?? '');
    _phoneCtrl = TextEditingController(text: (d['phone'] as String?) ?? '');
    _headCtrl = TextEditingController(text: (d['head'] as String?) ?? '');
    final String? gk = (d['groupKey'] as String?)?.trim();
    _groupKey = (gk != null && gk.isNotEmpty) ? gk : _kGroupHdne;
    _lat = _coerceDouble(d['lat']);
    _lng = _coerceDouble(d['lng']);
  }

  static double? _coerceDouble(Object? v) {
    if (v == null) {
      return null;
    }
    if (v is num) {
      return v.toDouble();
    }
    if (v is String) {
      return double.tryParse(v.trim());
    }
    return null;
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _headCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAddressSearch() async {
    final KakaoAddressPick? pick = await showKakaoAddressSearchDialog(context);
    if (pick == null || !mounted) {
      return;
    }
    setState(() {
      _addressCtrl.text = pick.displayLine;
      _lat = pick.latitude;
      _lng = pick.longitude;
    });
  }

  /// 주소 필드 문자열로 재검색 (첫 결과 적용)
  Future<void> _geocodeAddressField() async {
    final String q = _addressCtrl.text.trim();
    if (q.length < 2) {
      _snack('주소를 두 글자 이상 입력하거나 주소 검색을 사용하세요.');
      return;
    }
    try {
      final List<KakaoAddressPick> list = await _kakao.searchAddress(q);
      if (!mounted) {
        return;
      }
      if (list.isEmpty) {
        _snack('검색 결과가 없습니다. 주소 검색으로 선택해 주세요.');
        return;
      }
      final KakaoAddressPick pick = list.first;
      setState(() {
        _addressCtrl.text = pick.displayLine;
        _lat = pick.latitude;
        _lng = pick.longitude;
      });
      _snack('좌표를 적용했습니다.');
    } on Object catch (e) {
      if (mounted) {
        _snack('$e');
      }
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save() async {
    final String id = _idCtrl.text.trim();
    final String name = _nameCtrl.text.trim();
    final String addr = _addressCtrl.text.trim();

    if (widget.isNew && id.isEmpty) {
      _snack('사업소 문서 ID를 입력하세요. (회원가입 시 선택값과 동일해야 합니다)');
      return;
    }
    if (name.isEmpty) {
      _snack('사업소명을 입력하세요.');
      return;
    }
    if (addr.isNotEmpty && (_lat == null || _lng == null)) {
      _snack('주소가 있으면 주소 검색(또는 좌표 적용)으로 위치를 확정하세요.');
      return;
    }

    final String docId = widget.isNew ? id : (widget.initial['id'] as String);

    setState(() => _saving = true);
    try {
      if (widget.isNew) {
        final DocumentSnapshot<Map<String, dynamic>> existing =
            await FirestorePaths.publicBranchesCol().doc(docId).get();
        if (existing.exists) {
          if (mounted) {
            _snack('이미 같은 ID의 사업소가 있습니다.');
          }
          return;
        }
      }

      final Map<String, dynamic> payload = <String, dynamic>{
        'name': name,
        'groupKey': _groupKey,
        'address': addr,
        'phone': _phoneCtrl.text.trim(),
        'head': _headCtrl.text.trim(),
      };

      if (addr.isNotEmpty && _lat != null && _lng != null) {
        payload['lat'] = _lat;
        payload['lng'] = _lng;
      } else {
        payload['lat'] = FieldValue.delete();
        payload['lng'] = FieldValue.delete();
      }

      await FirestorePaths.publicBranchesCol()
          .doc(docId)
          .set(payload, SetOptions(merge: true));

      if (mounted) {
        _snack('저장했습니다.');
        widget.onBack();
      }
    } on Object catch (e) {
      if (mounted) {
        _snack('저장 실패: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final String docId = (widget.initial['id'] as String?) ?? _idCtrl.text.trim();
    if (docId.isEmpty) {
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('사업소 삭제'),
        content: Text('「$docId」문서를 삭제할까요?\n연결된 사용자·요청 데이터는 자동으로 바뀌지 않습니다.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      await FirestorePaths.publicBranchesCol().doc(docId).delete();
      if (mounted) {
        _snack('삭제했습니다.');
        widget.onBack();
      }
    } on Object catch (e) {
      if (mounted) {
        _snack('삭제 실패: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color navy = Color(0xFF1E3A8A);
    const Color slate900 = Color(0xFF0F172A);
    const Color slate400 = Color(0xFF94A3B8);
    const Color slate50 = Color(0xFFF8FAFC);

    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(12, 8, 12, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
        TextButton.icon(
          onPressed: _saving ? null : widget.onBack,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('목록으로 돌아가기'),
          style: TextButton.styleFrom(foregroundColor: slate400),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(56),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.isNew ? '신규 사업소' : '사업소 편집',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 24),
              if (widget.isNew) ...<Widget>[
                _LabeledField(
                  label: '사업소 문서 ID',
                  child: TextField(
                    controller: _idCtrl,
                    decoration: _fieldDeco(slate50),
                    enabled: !_saving,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '회원가입 시 사업소 선택 목록과 동일한 값이어야 합니다.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '문서 ID: ${widget.initial['id']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              _LabeledField(
                label: '사업소명',
                child: TextField(
                  controller: _nameCtrl,
                  decoration: _fieldDeco(slate50),
                  enabled: !_saving,
                ),
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: '소속 그룹',
                child: DropdownButtonFormField<String>(
                  value: _groupKey == _kGroupTheway ? _kGroupTheway : _kGroupHdne,
                  decoration: _fieldDeco(slate50),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: _kGroupHdne,
                      child: Text('에이치앤디이 사업소'),
                    ),
                    DropdownMenuItem(
                      value: _kGroupTheway,
                      child: Text('더웨이유통 사업소'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (String? v) {
                          if (v != null) {
                            setState(() => _groupKey = v);
                          }
                        },
                ),
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: '사업소 주소',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: _addressCtrl,
                      decoration: _fieldDeco(slate50).copyWith(
                        hintText: '주소 검색으로 선택하세요',
                      ),
                      maxLines: 2,
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _openAddressSearch,
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('주소 검색'),
                        ),
                        OutlinedButton(
                          onPressed: _saving ? null : _geocodeAddressField,
                          child: const Text('입력 주소로 좌표 적용'),
                        ),
                      ],
                    ),
                    if (_lat != null && _lng != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '좌표: ${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _LabeledField(
                      label: '대표 연락처',
                      child: TextField(
                        controller: _phoneCtrl,
                        decoration: _fieldDeco(slate50),
                        enabled: !_saving,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _LabeledField(
                      label: '사업소장',
                      child: TextField(
                        controller: _headCtrl,
                        decoration: _fieldDeco(slate50),
                        enabled: !_saving,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: <Widget>[
                  if (!widget.isNew)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _delete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('사업소 삭제'),
                      ),
                    ),
                  if (!widget.isNew) const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save, size: 16),
                      label: Text(widget.isNew ? '등록' : '사업소 정보 저장'),
                      style: FilledButton.styleFrom(
                        backgroundColor: navy,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  InputDecoration _fieldDeco(Color slate50) {
    return InputDecoration(
      filled: true,
      fillColor: slate50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF94A3B8),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
