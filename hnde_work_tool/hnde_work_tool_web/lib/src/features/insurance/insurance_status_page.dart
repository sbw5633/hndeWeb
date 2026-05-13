import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/firestore_paths.dart';
import '../../constants/insurance_status.dart';
import '../../constants/insurance_types.dart';
import '../../constants/role_constants.dart';
import 'insurance_status_input_dialog.dart'
    show showInsuranceStatusEditDialog, showInsuranceStatusInputDialog;
import '../common/enterprise_scaffold.dart';
import '../common/loading_widget.dart';

/// 테이블 행: 라이브 스냅샷과 로컬 시드 캐시 모두에서 동일 형태로 사용
class _InsuranceRowView {
  _InsuranceRowView({
    required this.id,
    required Map<String, dynamic> data,
    required this.reference,
  }) : _data = Map<String, dynamic>.from(data);

  final String id;
  final Map<String, dynamic> _data;
  final DocumentReference<Map<String, dynamic>> reference;

  factory _InsuranceRowView.fromQueryDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> q,
  ) {
    final Map<String, dynamic>? raw = q.data();
    return _InsuranceRowView(
      id: q.id,
      data: raw ?? <String, dynamic>{},
      reference: q.reference,
    );
  }

  Map<String, dynamic> data() => _data;
}

const String _kPrefsInsurancePrefix = 'insurance_status_seed_v1_';

String _insuranceCacheSig(int roleIdx, String userBranch) {
  if (RoleConstants.isHqAdminOnly(roleIdx)) return 'hq';
  if (RoleConstants.isBranchAdminOnly(roleIdx)) {
    return 'br:${userBranch.isEmpty ? '__no_branch__' : userBranch}';
  }
  return 'all';
}

dynamic _encodePrefsValue(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) {
    return <String, dynamic>{'_fire_ts_ms': v.millisecondsSinceEpoch};
  }
  if (v is Map) {
    return v.map(
      (Object? k, Object? val) =>
          MapEntry<String, dynamic>(k.toString(), _encodePrefsValue(val)),
    );
  }
  if (v is List) {
    return v.map(_encodePrefsValue).toList();
  }
  return v;
}

dynamic _decodePrefsValue(dynamic v) {
  if (v is Map) {
    if (v.length == 1 && v['_fire_ts_ms'] != null) {
      return Timestamp.fromMillisecondsSinceEpoch(
        (v['_fire_ts_ms'] as num).toInt(),
      );
    }
    return v.map(
      (Object? k, Object? val) =>
          MapEntry<String, dynamic>(k.toString(), _decodePrefsValue(val)),
    );
  }
  if (v is List) {
    return v.map(_decodePrefsValue).toList();
  }
  return v;
}

Future<List<_InsuranceRowView>?> _loadInsuranceSeedFromPrefs({
  required String uid,
  required String sig,
}) async {
  try {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String? raw = p.getString('$_kPrefsInsurancePrefix${uid}_$sig');
    if (raw == null || raw.trim().isEmpty) return null;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    final CollectionReference<Map<String, dynamic>> col =
        FirestorePaths.insuranceStatusCol();
    final List<_InsuranceRowView> out = <_InsuranceRowView>[];
    for (final Object? e in decoded) {
      if (e is! Map) continue;
      final Map<String, dynamic> m = e.cast<String, dynamic>();
      final String id = (m['id'] as String?) ?? '';
      if (id.isEmpty) continue;
      final Object? rawData = _decodePrefsValue(m['data']);
      if (rawData is! Map) continue;
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(rawData);
      out.add(
        _InsuranceRowView(
          id: id,
          data: data,
          reference: col.doc(id),
        ),
      );
    }
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}

Future<void> _saveInsuranceSeedToPrefs({
  required String uid,
  required String sig,
  required List<_InsuranceRowView> rows,
}) async {
  try {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> encoded =
        rows.map((_InsuranceRowView r) {
      return <String, dynamic>{
        'id': r.id,
        'data': _encodePrefsValue(r.data()),
      };
    }).toList();
    await p.setString(
      '$_kPrefsInsurancePrefix${uid}_$sig',
      jsonEncode(encoded),
    );
  } catch (_) {
    return;
  }
}

class InsuranceStatusPage extends StatefulWidget {
  const InsuranceStatusPage({super.key});

  @override
  State<InsuranceStatusPage> createState() => _InsuranceStatusPageState();
}

enum _DateFilterCriteria { all, acquired, loss, hire, resignation }

class _InsuranceStatusPageState extends State<InsuranceStatusPage> {
  bool _showLost = false;
  final Set<String> _visibleInsurances = <String>{
    InsuranceTypes.national,
    InsuranceTypes.health,
    InsuranceTypes.employment,
    InsuranceTypes.industrial,
  };
  _DateFilterCriteria _filterCriteria = _DateFilterCriteria.all;
  int _filterStartYear = DateTime.now().year;
  int _filterStartMonth = DateTime.now().month;
  int _filterEndYear = DateTime.now().year;
  int _filterEndMonth = DateTime.now().month;
  late final ScrollController _horizontalScroll;
  late final ScrollController _toolbarHScroll;

  /// 프로필 빌드마다 새 Query.snapshots()를 만들면 재구독 → 리사이즈 때마다 로딩 깜빡임
  Stream<QuerySnapshot<Map<String, dynamic>>>? _memoInsuranceSnapStream;
  String _memoInsuranceSnapSig = '';

  List<_InsuranceRowView>? _seedRowsCache;
  String? _hydratedSeedSig;
  String? _hydrateBusySig;
  String _lastPersistedPayload = '';
  String _lastPersistCacheSig = '';

  @override
  void initState() {
    super.initState();
    _horizontalScroll = ScrollController();
    _toolbarHScroll = ScrollController();
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _toolbarHScroll.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _memoInsuranceSnapshots(
    Query<Map<String, dynamic>> q,
    String sig,
  ) {
    if (_memoInsuranceSnapStream != null && _memoInsuranceSnapSig == sig) {
      return _memoInsuranceSnapStream!;
    }
    _memoInsuranceSnapSig = sig;
    _memoInsuranceSnapStream = q.snapshots();
    return _memoInsuranceSnapStream!;
  }

  void _ensureHydrateSeed(String uid, String sig) {
    if (_hydratedSeedSig == sig) return;
    if (_hydrateBusySig == sig) return;
    _hydrateBusySig = sig;
    _loadInsuranceSeedFromPrefs(uid: uid, sig: sig).then(
      (List<_InsuranceRowView>? rows) {
        if (!mounted) return;
        setState(() {
          _hydrateBusySig = null;
          _seedRowsCache = rows;
          _hydratedSeedSig = sig;
        });
      },
    );
  }

  void _maybePersistSnapshot({
    required String uid,
    required String sig,
    required List<_InsuranceRowView> rows,
  }) {
    try {
      if (_lastPersistCacheSig != sig) {
        _lastPersistCacheSig = sig;
        _lastPersistedPayload = '';
      }
      final String payload = jsonEncode(
        rows.map((_InsuranceRowView r) {
          return <String, dynamic>{
            'id': r.id,
            'data': _encodePrefsValue(r.data()),
          };
        }).toList(),
      );
      if (payload == _lastPersistedPayload) return;
      _lastPersistedPayload = payload;
      unawaited(
        _saveInsuranceSeedToPrefs(uid: uid, sig: sig, rows: rows),
      );
    } catch (_) {}
  }

  List<_InsuranceRowView> _materializeRows(List<_InsuranceRowView> allRows) {
    List<_InsuranceRowView> rows = _showLost
        ? List<_InsuranceRowView>.from(allRows)
        : allRows
            .where((_InsuranceRowView doc) {
              final String st =
                  InsuranceStatus.deriveFromMap(doc.data());
              return InsuranceStatus.isAcquired(st);
            })
            .toList();
    if (_showLost) {
      rows = _applyDateFilter(rows);
    }
    return rows;
  }

  List<int> _getYearOptions() {
    final int y = DateTime.now().year;
    return List<int>.generate(5, (int i) => y - i);
  }

  bool _isInRange(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return false;
    DateTime? dt;
    try {
      final List<String> parts = dateStr.trim().split(RegExp(r'[-/.\s]'));
      if (parts.length >= 3 && parts[0].length == 4) {
        final int y = int.parse(parts[0]);
        final int m = int.parse(parts[1]);
        final int d = int.parse(parts[2]);
        dt = DateTime(y, m, d);
      } else if (RegExp(r'^\d{8}$').hasMatch(dateStr.trim())) {
        final String t = dateStr.trim();
        dt = DateTime(
          int.parse(t.substring(0, 4)),
          int.parse(t.substring(4, 6)),
          int.parse(t.substring(6, 8)),
        );
      }
    } catch (_) {}
    if (dt == null) return false;
    final DateTime rangeStart = DateTime(_filterStartYear, _filterStartMonth, 1);
    final DateTime rangeEnd = DateTime(
      _filterEndYear,
      _filterEndMonth + 1,
      0,
    ); // last day of month
    return (dt.isAtSameMomentAs(rangeStart) || dt.isAfter(rangeStart)) &&
        (dt.isAtSameMomentAs(rangeEnd) || dt.isBefore(rangeEnd));
  }

  static const double _wideFlex = 1.2; // 성명, 주민번호, 입사일, 퇴사일
  static const double _dateFlex = 1.35; // 취득일, 상실일
  static const double _editFlex = 0.7; // 수정 아이콘

  double _totalTableFlex(int visibleInsuranceCount) {
    return (4 * _wideFlex) + (visibleInsuranceCount * 2 * _dateFlex) + _editFlex;
  }

  double _minScrollableTableWidth(int visibleInsuranceCount) {
    // 1 flex당 약 72px 기준으로 최소 너비를 만들고,
    // 너무 좁은 값은 방지합니다.
    return (_totalTableFlex(visibleInsuranceCount) * 72).clamp(980, 2200);
  }

  Widget _buildInsuranceTable(
    List<_InsuranceRowView> rows,
    double tableWidth,
  ) {
    final visible = InsuranceTypes.all.where(_visibleInsurances.contains).toList();

    final Map<int, TableColumnWidth> widths = <int, TableColumnWidth>{
      for (int i = 0; i < 4; i++) i: const FlexColumnWidth(_wideFlex),
    };
    int idx = 4;
    for (int i = 0; i < visible.length; i++) {
      widths[idx++] = const FlexColumnWidth(_dateFlex);
      widths[idx++] = const FlexColumnWidth(_dateFlex);
    }
    widths[idx] = const FlexColumnWidth(_editFlex);

    const double borderW = 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: tableWidth,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: borderW),
                left: BorderSide(color: Colors.grey.shade300, width: borderW),
                right: BorderSide(color: Colors.grey.shade300, width: borderW),
                top: BorderSide(color: Colors.grey.shade300, width: borderW),
              ),
            ),
            child: SizedBox(
              height: 40,
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < 4; i++)
                    _mergedCellFlex('', _wideFlex, hasRightBorder: true),
                  ...visible.map((String key) => _mergedCellFlex(
                        InsuranceTypes.fullLabel(key),
                        _dateFlex * 2,
                        hasRightBorder: true,
                      )),
                  _mergedCellFlex('', _editFlex, hasRightBorder: false),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: tableWidth,
          child: ClipRect(
            child: Table(
              columnWidths: widths,
              border: TableBorder.all(
                color: Colors.grey.shade300,
                width: borderW,
              ),
              children: <TableRow>[
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: <Widget>[
                    _th('성명'),
                    _th('주민번호'),
                    _th('입사일'),
                    _th('퇴사일'),
                    ...visible.expand((_) => <Widget>[_th('취득일'), _th('상실일')]),
                    _th('수정'),
                  ],
                ),
                ...rows.map((_InsuranceRowView doc) {
                  final Map<String, dynamic> data = doc.data();
                  final String name = data['name'] as String? ?? '-';
                  final String rrn = data['rrn'] as String? ?? '';
                  final String maskedRrn =
                      rrn.length >= 7 ? '${rrn.substring(0, 6)}-*******' : rrn;
                  String getDate(String key, bool acquired) {
                    final f = acquired
                        ? InsuranceTypes.acquiredField(key)
                        : InsuranceTypes.lossField(key);
                    final v = data[f] as String?;
                    if (v != null && v.isNotEmpty) return v;
                    if (key == InsuranceTypes.national) {
                      return acquired
                          ? (data['acquiredDate'] as String? ?? '')
                          : (data['lossDate'] as String? ?? '');
                    }
                    return '';
                  }

                  final String hireDate = (data['hireDate'] as String?) ?? '-';
                  final String resignationDate =
                      (data['resignationDate'] as String?) ?? '';

                  return TableRow(
                    key: ValueKey<String>(doc.id),
                    children: <Widget>[
                      _td(name),
                      _td(maskedRrn),
                      _tdDate(hireDate),
                      _tdDate(resignationDate.isEmpty ? '-' : resignationDate),
                      ...visible.expand((String key) => <Widget>[
                            _tdDate(getDate(key, true).isEmpty
                                ? '-'
                                : getDate(key, true)),
                            _tdDate(getDate(key, false).isEmpty
                                ? '-'
                                : getDate(key, false)),
                          ]),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: '수정',
                          onPressed: () => showInsuranceStatusEditDialog(
                            context,
                            docRef: doc.reference,
                            initialData: data,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mergedCellFlex(String text, double flex, {required bool hasRightBorder}) {
    return Expanded(
      flex: (flex * 1000).round(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: hasRightBorder
              ? Border(
                  right: BorderSide(color: Colors.grey.shade300, width: 0.5),
                )
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: text.isEmpty ? Colors.transparent : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  TableCell _th(String text) => TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),
      );

  TableCell _td(String text) => TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Center(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ),
      );

  TableCell _tdDate(String text) => TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ),
        ),
      );

  List<_InsuranceRowView> _applyDateFilter(List<_InsuranceRowView> list) {
    if (_filterCriteria == _DateFilterCriteria.all) return list;
    return list.where((_InsuranceRowView doc) {
      final Map<String, dynamic> d = doc.data();
      List<String?> dateStrs = <String?>[];
      switch (_filterCriteria) {
        case _DateFilterCriteria.acquired:
          for (final k in InsuranceTypes.all) {
            dateStrs.add(d[InsuranceTypes.acquiredField(k)] as String?);
          }
          dateStrs.add(d['acquiredDate'] as String?);
          break;
        case _DateFilterCriteria.loss:
          for (final k in InsuranceTypes.all) {
            dateStrs.add(d[InsuranceTypes.lossField(k)] as String?);
          }
          dateStrs.add(d['lossDate'] as String?);
          break;
        case _DateFilterCriteria.hire:
          dateStrs.add(d['hireDate'] as String?);
          break;
        case _DateFilterCriteria.resignation:
          dateStrs.add(d['resignationDate'] as String?);
          break;
        default:
          return true;
      }
      return dateStrs.any((String? s) => _isInRange(s));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? uidOrNull = user?.uid;
    if (uidOrNull == null) {
      return EnterpriseScaffold(
        title: '4대보험 · 전체 현황',
        child: const Center(child: Text('로그인이 필요합니다.')),
      );
    }
    final String uid = uidOrNull;
    final DocumentReference<Map<String, dynamic>> profileRef =
        FirestorePaths.userProfileMainDoc(uid);

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

        Query<Map<String, dynamic>> baseQuery =
            FirestorePaths.insuranceStatusCol();
        if (RoleConstants.isHqAdminOnly(roleIdx)) {
          baseQuery = baseQuery.where('branchName', isEqualTo: '본사');
        } else if (RoleConstants.isBranchAdminOnly(roleIdx)) {
          if (userBranch.isEmpty) {
            baseQuery = baseQuery.where('branchName', isEqualTo: '__no_branch__');
          } else {
            baseQuery = baseQuery.where('branchName', isEqualTo: userBranch);
          }
        }
        final Query<Map<String, dynamic>> query =
            baseQuery.orderBy('createdAt', descending: true);
        final String cacheSig = _insuranceCacheSig(roleIdx, userBranch);
        _ensureHydrateSeed(uid, cacheSig);

        return EnterpriseScaffold(
      title: '4대보험 · 전체 현황',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Scrollbar(
            controller: _toolbarHScroll,
            thumbVisibility: false,
            notificationPredicate: (ScrollNotification n) =>
                n.depth == 0,
            child: SingleChildScrollView(
              controller: _toolbarHScroll,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const Text(
                      '전체 현황보기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => setState(() => _showLost = !_showLost),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Checkbox(
                              value: _showLost,
                              onChanged: (bool? v) =>
                                  setState(() => _showLost = v ?? false),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '상실자 보기',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ...InsuranceTypes.all.map((String key) {
                      final bool v = _visibleInsurances.contains(key);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() {
                            if (v) {
                              _visibleInsurances.remove(key);
                            } else {
                              _visibleInsurances.add(key);
                            }
                          }),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Checkbox(
                                value: v,
                                onChanged: (bool? val) => setState(() {
                                  if (val == true) {
                                    _visibleInsurances.add(key);
                                  } else {
                                    _visibleInsurances.remove(key);
                                  }
                                }),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              Text(InsuranceTypes.label(key)),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          showInsuranceStatusInputDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('신규 입력'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        // 엑셀 다운로드 로직은 이후 SheetJS(Web) 연동 시 확장
                      },
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('엑셀 다운로드'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showLost) ...[
            const SizedBox(height: 12),
            _DateFilterBar(
              criteria: _filterCriteria,
              onCriteriaChanged: (_DateFilterCriteria v) =>
                  setState(() => _filterCriteria = v),
              startYear: _filterStartYear,
              startMonth: _filterStartMonth,
              endYear: _filterEndYear,
              endMonth: _filterEndMonth,
              onStartChanged: (int y, int m) =>
                  setState(() {
                    _filterStartYear = y;
                    _filterStartMonth = m;
                  }),
              onEndChanged: (int y, int m) =>
                  setState(() {
                    _filterEndYear = y;
                    _filterEndMonth = m;
                  }),
              yearOptions: _getYearOptions(),
            ),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (
                    BuildContext context,
                    BoxConstraints outerConstraints,
                  ) {
                    return SizedBox(
                      width: outerConstraints.maxWidth,
                      height: outerConstraints.maxHeight,
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _memoInsuranceSnapshots(query, cacheSig),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                      ) {
                        final List<_InsuranceRowView>? liveRows =
                            snapshot.hasData
                                ? snapshot.data!.docs
                                    .map(_InsuranceRowView.fromQueryDoc)
                                    .toList()
                                : null;

                        if (liveRows != null) {
                          _maybePersistSnapshot(
                            uid: uid,
                            sig: cacheSig,
                            rows: liveRows,
                          );
                        }

                        final bool waitingFirst =
                            snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData;

                        final List<_InsuranceRowView>? seedRows =
                            (_hydratedSeedSig == cacheSig)
                                ? _seedRowsCache
                                : null;

                        if (waitingFirst &&
                            (seedRows == null || seedRows.isEmpty)) {
                          return SizedBox(
                            height: outerConstraints.maxHeight,
                            child: const Center(
                              child: LoadingWidget(size: 80),
                            ),
                          );
                        }

                        final List<_InsuranceRowView> baseRows =
                            liveRows ??
                            seedRows ??
                            <_InsuranceRowView>[];

                        if (liveRows != null && liveRows.isEmpty) {
                          return SizedBox(
                            height: outerConstraints.maxHeight,
                            child: const Center(
                              child: Text(
                                '등록된 취득 내역이 없습니다.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        final List<_InsuranceRowView> rowsUi =
                            _materializeRows(baseRows);

                        if (rowsUi.isEmpty) {
                          return SizedBox(
                            height: outerConstraints.maxHeight,
                            child: Center(
                              child: Text(
                                _showLost
                                    ? '등록된 취득 내역이 없습니다.'
                                    : '상실자를 제외한 취득 내역이 없습니다.',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        final int visibleInsuranceCount = InsuranceTypes.all
                            .where(_visibleInsurances.contains)
                            .length;
                        final double layoutW = outerConstraints.maxWidth;
                        final double minScrollableW =
                            _minScrollableTableWidth(visibleInsuranceCount);
                        final double contentW =
                            layoutW < minScrollableW ? minScrollableW : layoutW;

                        return RepaintBoundary(
                          child: Scrollbar(
                            controller: _horizontalScroll,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalScroll,
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: contentW,
                                    minHeight: outerConstraints.maxHeight,
                                  ),
                                  child: _buildInsuranceTable(rowsUi, contentW),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _DateFilterBar extends StatelessWidget {
  const _DateFilterBar({
    required this.criteria,
    required this.onCriteriaChanged,
    required this.startYear,
    required this.startMonth,
    required this.endYear,
    required this.endMonth,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.yearOptions,
  });

  final _DateFilterCriteria criteria;
  final ValueChanged<_DateFilterCriteria> onCriteriaChanged;
  final int startYear;
  final int startMonth;
  final int endYear;
  final int endMonth;
  final void Function(int year, int month) onStartChanged;
  final void Function(int year, int month) onEndChanged;
  final List<int> yearOptions;

  @override
  Widget build(BuildContext context) {
    final bool showRange = criteria != _DateFilterCriteria.all;
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            const Text(
              '검색 기간',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<_DateFilterCriteria>(
              value: criteria,
              items: const <DropdownMenuItem<_DateFilterCriteria>>[
                DropdownMenuItem<_DateFilterCriteria>(
                  value: _DateFilterCriteria.all,
                  child: Text('전체'),
                ),
                DropdownMenuItem<_DateFilterCriteria>(
                  value: _DateFilterCriteria.acquired,
                  child: Text('취득일 기준'),
                ),
                DropdownMenuItem<_DateFilterCriteria>(
                  value: _DateFilterCriteria.loss,
                  child: Text('상실일 기준'),
                ),
                DropdownMenuItem<_DateFilterCriteria>(
                  value: _DateFilterCriteria.hire,
                  child: Text('입사일 기준'),
                ),
                DropdownMenuItem<_DateFilterCriteria>(
                  value: _DateFilterCriteria.resignation,
                  child: Text('퇴사일 기준'),
                ),
              ],
              onChanged: (v) {
                if (v != null) onCriteriaChanged(v);
              },
            ),
            if (showRange) ...[
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: yearOptions.contains(startYear) ? startYear : yearOptions.first,
                items: yearOptions
                    .map((int y) => DropdownMenuItem<int>(
                          value: y,
                          child: Text('$y년'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onStartChanged(v, startMonth);
                },
              ),
              const SizedBox(width: 4),
              DropdownButton<int>(
                value: startMonth,
                items: List<int>.generate(12, (i) => i + 1)
                    .map((int m) => DropdownMenuItem<int>(
                          value: m,
                          child: Text('$m월'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onStartChanged(startYear, v);
                },
              ),
              const Text('  ~  '),
              DropdownButton<int>(
                value: yearOptions.contains(endYear) ? endYear : yearOptions.first,
                items: yearOptions
                    .map((int y) => DropdownMenuItem<int>(
                          value: y,
                          child: Text('$y년'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onEndChanged(v, endMonth);
                },
              ),
              const SizedBox(width: 4),
              DropdownButton<int>(
                value: endMonth,
                items: List<int>.generate(12, (i) => i + 1)
                    .map((int m) => DropdownMenuItem<int>(
                          value: m,
                          child: Text('$m월'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onEndChanged(endYear, v);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
