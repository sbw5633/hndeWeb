import 'dart:collection';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/firestore_paths.dart';
import '../../constants/role_constants.dart';
import '../../constants/super_admin.dart';
import '../../models/branch_model.dart';
import '../../repositories/work_firestore_repository.dart';
import '../../utils/browser_download.dart';
import '../../utils/rrn_validation.dart';
import '../../utils/save_xlsx.dart';
import '../common/enterprise_scaffold.dart';
import '../common/message_alert.dart';
import '../common/merged_user_profile_stream_builder.dart';

/// 테스트/더미용: 숫자만 모아 13자리 저장 키로 맞춤(체크섬 검증 없음). Firestore·캐시는 13자리만 수용합니다.
String _normalizeDummyRrnToKey(String raw) {
  final String digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 13) {
    return formatRrn(digits.substring(0, 13));
  }
  String pad = digits;
  if (pad.isEmpty) {
    final String t = DateTime.now().microsecondsSinceEpoch.abs().toString();
    pad = (t + '0000000000000').substring(0, 13);
  } else {
    while (pad.length < 13) {
      pad = '${pad}0';
    }
    pad = pad.substring(0, 13);
  }
  return formatRrn(pad);
}

/// 근무일 확인 다이얼로그에서 «전체 사업소» 필터용.
const String _kAllBranchesMonthlyFilter = '__ALL_BRANCHES__';

/// Excel 1-based column index (A=1, B=2, …, K=11) → column letters (…, Z, AA, …).
String _excelColumnLettersFromIndex1Based(int col1Based) {
  final StringBuffer buf = StringBuffer();
  int n = col1Based;
  while (n > 0) {
    final int rem = (n - 1) % 26;
    buf.writeCharCode(65 + rem);
    n = (n - 1) ~/ 26;
  }
  return buf.toString().split('').reversed.join();
}

/// 25.05.29 이후 전자신고용 근로내용확인신고 양식(사용자 제공 2025년 5월본 기준).
const String _kDailyWorkerElectroTemplateAsset =
    'assets/insurance/daily_worker_electronic_template.xlsx';

class DailyWorkerPage extends StatefulWidget {
  const DailyWorkerPage({super.key});

  @override
  State<DailyWorkerPage> createState() => _DailyWorkerPageState();
}

class _DailyWorkerPageState extends State<DailyWorkerPage> {
  final List<_DailyWorkerRow> _rows = <_DailyWorkerRow>[];
  late final ScrollController _horizontalScroll;
  DateTime _attributionMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  bool _checkingDates = false;
  static const String _kDailyHistoryCacheKey = 'daily_worker_history_cache_v2';
  /// 귀속·저장에 사용하는 사업소명 (`BranchModel.name`과 동일 문자열 권장).
  String _workBranchName = '';
  bool _branchLocked = false;
  String? _branchContextSyncSig;
  /// `branchName` → `rrn` → `yyyyMM` → 근무일.
  final Map<String, Map<String, Map<int, Set<int>>>> _dailyHistoryByBranch =
      <String, Map<String, Map<int, Set<int>>>>{};
  final Map<String, Map<String, String>> _workerNameByBranch =
      <String, Map<String, String>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _dailyWorkersSub;
  bool _dailyCacheReady = false;

  @override
  void initState() {
    super.initState();
    _horizontalScroll = ScrollController();
    _rows.add(_DailyWorkerRow());
    _warmDailyHistoryCache();
  }

  @override
  void dispose() {
    _dailyWorkersSub?.cancel();
    _horizontalScroll.dispose();
    super.dispose();
  }

  Map<String, Map<int, Set<int>>> _historySliceFor(String branch) =>
      _dailyHistoryByBranch[branch] ?? <String, Map<int, Set<int>>>{};

  void _scheduleBranchContextSync(
    Map<String, dynamic> merged,
    List<BranchModel> branches,
  ) {
    final String sig =
        '${merged['roleIdx']}|${merged['branchName']}|${merged['mainAdmin']}|${branches.map((BranchModel b) => b.name).join('\u241e')}';
    if (_branchContextSyncSig == sig) {
      return;
    }
    _branchContextSyncSig = sig;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final bool changed = _applyBranchSelection(merged, branches);
      if (changed) {
        setState(() {});
      }
    });
  }

  bool _applyBranchSelection(
    Map<String, dynamic> merged,
    List<BranchModel> branches,
  ) {
    final int roleIdx =
        (merged['roleIdx'] as num?)?.toInt() ?? RoleConstants.unspecified;
    final String profileEmail = (merged['email'] as String? ?? '').trim();
    final String authEmail =
        (FirebaseAuth.instance.currentUser?.email ?? '').trim();
    final bool mainLike = SuperAdmin.effectiveMainAdmin(
      profileMainAdmin: merged['mainAdmin'],
      profileEmail: profileEmail,
      authEmail: authEmail,
      roleIdx: roleIdx,
    );
    final bool locked =
        RoleConstants.isBranchAdminOnly(roleIdx) && !mainLike;
    final List<String> names = branches
        .map((BranchModel b) => b.name.trim())
        .where((String n) => n.isNotEmpty)
        .toList();
    final String profileBranch =
        (merged['branchName'] as String? ?? '').trim();

    bool changed = false;
    if (locked) {
      final String forced = profileBranch.isNotEmpty
          ? profileBranch
          : (names.isNotEmpty ? names.first : '');
      if (_branchLocked != locked) {
        _branchLocked = locked;
        changed = true;
      }
      if (_workBranchName != forced) {
        _workBranchName = forced;
        changed = true;
      }
      return changed;
    }
    if (_branchLocked != locked) {
      _branchLocked = locked;
      changed = true;
    }
    if (_workBranchName.isEmpty && names.isNotEmpty) {
      final String pick =
          names.contains(profileBranch) ? profileBranch : names.first;
      if (pick.isNotEmpty && _workBranchName != pick) {
        _workBranchName = pick;
        changed = true;
      }
    } else if (_workBranchName.isNotEmpty &&
        names.isNotEmpty &&
        !names.contains(_workBranchName)) {
      final String pick =
          names.contains(profileBranch) ? profileBranch : names.first;
      if (_workBranchName != pick) {
        _workBranchName = pick;
        changed = true;
      }
    }
    return changed;
  }

  List<int> _getYearOptions() {
    final int currentYear = DateTime.now().year;
    return List<int>.generate(5, (int i) => currentYear - i);
  }

  void _onAttributionChanged(int year, int month) {
    final DateTime now = DateTime.now();
    final DateTime selected = DateTime(year, month, 1);
    final DateTime currentFirst = DateTime(now.year, now.month, 1);
    if (selected.isAfter(currentFirst)) {
      showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('귀속월 선택'),
          content: const Text('귀속월은 미래일 수 없습니다.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      ).then((_) {
        setState(() {
          _attributionMonth = DateTime(now.year, now.month, 1);
        });
      });
    } else {
      setState(() => _attributionMonth = DateTime(year, month, 1));
    }
  }

  Future<void> _save() async {
    if (_workBranchName.trim().isEmpty) {
      await showMessageAlert(
        context,
        title: '사업소 미선택',
        message: '상단에서 저장할 사업소(소속)를 선택해 주세요.',
      );
      return;
    }
    for (int i = 0; i < _rows.length; i++) {
      final _DailyWorkerRow row = _rows[i];
      final String? err = validateRrn(row.rrn);
      if (err != null) {
        final String label =
            row.name.isNotEmpty ? row.name : '${i + 1}행';
        showMessageAlert(context, message: '$label 주민번호: $err', title: '입력 오류');
        return;
      }
    }
    await _persistToFirestore();
    await _exportExcel();
  }

  Future<void> _persistToFirestore() async {
    final String branch = _workBranchName.trim();
    if (branch.isEmpty) {
      return;
    }
    final CollectionReference<Map<String, dynamic>> col =
        FirestorePaths.dailyWorkersCol();
    final int daysInMonth = _daysInMonth(_attributionMonth);

    final List<Map<String, dynamic>> payload =
        _rows.map((_DailyWorkerRow row) => row.toJson(daysInMonth)).toList();
    await col.add(<String, dynamic>{
      'createdAt': FieldValue.serverTimestamp(),
      'attributionYear': _attributionMonth.year,
      'attributionMonth': _attributionMonth.month,
      'branchName': branch,
      'rows': payload,
    });
    // 저장 직후 로컬 캐시를 먼저 갱신해, 다음 판정은 즉시 캐시 기반으로 처리
    final int key = _attributionMonth.year * 100 + _attributionMonth.month;
    final Map<String, Map<int, Set<int>>> slice =
        _dailyHistoryByBranch.putIfAbsent(
      branch,
      () => <String, Map<int, Set<int>>>{},
    );
    for (final _DailyWorkerRow row in _rows) {
      final String rrnRaw = row.rrn.replaceAll(RegExp(r'\D'), '');
      if (rrnRaw.length != 13) continue;
      final String rrn = formatRrn(rrnRaw);
      final String name = row.name.trim();
      if (name.isNotEmpty) {
        final Map<String, String> nm =
            _workerNameByBranch.putIfAbsent(branch, () => <String, String>{});
        nm[rrn] = name;
      }
      final Map<int, Set<int>> byMonth =
          slice.putIfAbsent(rrn, () => <int, Set<int>>{});
      byMonth[key] = _workedDaysFromRow(row, daysInMonth);
    }
    unawaited(_saveDailyHistoryCacheToPrefs());
  }

  int _monthKey(DateTime d) => d.year * 100 + d.month;

  DateTime _firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  DateTime _addMonths(DateTime d, int months) =>
      DateTime(d.year, d.month + months, d.day);

  int _daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

  Future<void> _warmDailyHistoryCache() async {
    await _loadDailyHistoryCacheFromPrefs();
    await _dailyWorkersSub?.cancel();
    _dailyWorkersSub = FirestorePaths.dailyWorkersCol().snapshots().listen((
      QuerySnapshot<Map<String, dynamic>> snap,
    ) {
      _rebuildDailyHistoryCacheFromSnapshot(snap.docs);
      unawaited(_saveDailyHistoryCacheToPrefs());
      if (mounted && !_dailyCacheReady) {
        setState(() => _dailyCacheReady = true);
      } else {
        _dailyCacheReady = true;
      }
    });
  }

  void _rebuildDailyHistoryCacheFromSnapshot(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    _dailyHistoryByBranch
      ..clear();
    _workerNameByBranch.clear();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> d = doc.data();
      final String branch =
          (d['branchName'] as String? ?? d['branch'] as String? ?? '')
              .trim();
      final int? y = (d['attributionYear'] as num?)?.toInt();
      final int? m = (d['attributionMonth'] as num?)?.toInt();
      if (y == null || m == null || m < 1 || m > 12) continue;
      final int key = y * 100 + m;
      final Object? rows = d['rows'];
      if (rows is! List) continue;
      final Map<String, Map<int, Set<int>>> slice =
          _dailyHistoryByBranch.putIfAbsent(
        branch,
        () => <String, Map<int, Set<int>>>{},
      );
      final Map<String, String> nameSlice =
          _workerNameByBranch.putIfAbsent(branch, () => <String, String>{});
      for (final Object? obj in rows) {
        if (obj is! Map) continue;
        final Map<String, dynamic> row = obj.cast<String, dynamic>();
        final String rrnRaw =
            (row['rrn'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
        if (rrnRaw.length != 13) continue;
        final String rrn = formatRrn(rrnRaw);
        final String name = (row['name'] as String? ?? '').trim();
        if (name.isNotEmpty) {
          nameSlice[rrn] = name;
        }
        final Set<int> days = _workedDaysFromAny(row['days']);
        final Map<int, Set<int>> byMonth =
            slice.putIfAbsent(rrn, () => <int, Set<int>>{});
        final Set<int> existing = byMonth.putIfAbsent(key, () => <int>{});
        existing.addAll(days);
      }
    }
  }

  Future<void> _loadDailyHistoryCacheFromPrefs() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final String? raw = p.getString(_kDailyHistoryCacheKey);
      if (raw == null || raw.trim().isEmpty) return;
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final Map<String, dynamic> root = decoded.cast<String, dynamic>();
      _dailyHistoryByBranch
        ..clear();
      _workerNameByBranch.clear();

      if (root['v'] == 2) {
        final Object? branchesObj = root['branches'];
        if (branchesObj is! Map) return;
        for (final MapEntry<Object?, Object?> be in branchesObj.entries) {
          final String branch = be.key.toString();
          final Object? rrnMapObj = be.value;
          if (rrnMapObj is! Map) continue;
          final Map<String, Map<int, Set<int>>> slice =
              _dailyHistoryByBranch.putIfAbsent(
            branch,
            () => <String, Map<int, Set<int>>>{},
          );
          final Map<String, String> nameSlice =
              _workerNameByBranch.putIfAbsent(branch, () => <String, String>{});
          for (final MapEntry<Object?, Object?> rrnEntry in rrnMapObj.entries) {
            final String rrn = rrnEntry.key.toString();
            final Object? monthObj = rrnEntry.value;
            if (monthObj is! Map) continue;
            final String name = (monthObj['name'] as String? ?? '').trim();
            if (name.isNotEmpty) {
              nameSlice[rrn] = name;
            }
            final Object? monthMapObj = monthObj['months'] ?? monthObj;
            if (monthMapObj is! Map) continue;
            final Map<int, Set<int>> byMonth = <int, Set<int>>{};
            for (final MapEntry<Object?, Object?> monthEntry
                in monthMapObj.entries) {
              final int? monthKey = int.tryParse(monthEntry.key.toString());
              if (monthKey == null) continue;
              final Object? dayObj = monthEntry.value;
              if (dayObj is! List) continue;
              final Set<int> days = dayObj
                  .map((e) => e is num ? e.toInt() : int.tryParse('$e'))
                  .whereType<int>()
                  .where((d) => d >= 1 && d <= 31)
                  .toSet();
              byMonth[monthKey] = days;
            }
            if (byMonth.isNotEmpty) {
              slice[rrn] = byMonth;
            }
          }
        }
      } else {
        const String legacyBranch = '';
        final Map<String, Map<int, Set<int>>> slice =
            _dailyHistoryByBranch.putIfAbsent(
          legacyBranch,
          () => <String, Map<int, Set<int>>>{},
        );
        final Map<String, String> nameSlice =
            _workerNameByBranch.putIfAbsent(legacyBranch, () => <String, String>{});
        for (final MapEntry<Object?, Object?> rrnEntry in root.entries) {
          if (rrnEntry.key == 'v') continue;
          final String rrn = rrnEntry.key.toString();
          final Object? monthObj = rrnEntry.value;
          if (monthObj is! Map) continue;
          final String name = (monthObj['name'] as String? ?? '').trim();
          if (name.isNotEmpty) {
            nameSlice[rrn] = name;
          }
          final Object? monthMapObj = monthObj['months'] ?? monthObj;
          if (monthMapObj is! Map) continue;
          final Map<int, Set<int>> byMonth = <int, Set<int>>{};
          for (final MapEntry<Object?, Object?> monthEntry
              in monthMapObj.entries) {
            final int? monthKey = int.tryParse(monthEntry.key.toString());
            if (monthKey == null) continue;
            final Object? dayObj = monthEntry.value;
            if (dayObj is! List) continue;
            final Set<int> days = dayObj
                .map((e) => e is num ? e.toInt() : int.tryParse('$e'))
                .whereType<int>()
                .where((d) => d >= 1 && d <= 31)
                .toSet();
            byMonth[monthKey] = days;
          }
          if (byMonth.isNotEmpty) {
            slice[rrn] = byMonth;
          }
        }
      }
      _dailyCacheReady = _dailyHistoryByBranch.isNotEmpty;
    } catch (_) {
      return;
    }
  }

  Future<void> _saveDailyHistoryCacheToPrefs() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final Map<String, dynamic> branchesOut = <String, dynamic>{};
      _dailyHistoryByBranch.forEach(
        (String branch, Map<String, Map<int, Set<int>>> byRrn) {
          final Map<String, dynamic> rrnOut = <String, dynamic>{};
          byRrn.forEach((String rrn, Map<int, Set<int>> byMonth) {
            final Map<String, List<int>> mm = <String, List<int>>{};
            byMonth.forEach((int monthKey, Set<int> days) {
              final List<int> sorted = days.toList()..sort();
              mm['$monthKey'] = sorted;
            });
            final String nm =
                _workerNameByBranch[branch]?[rrn] ?? '';
            rrnOut[rrn] = <String, dynamic>{
              'name': nm,
              'months': mm,
            };
          });
          branchesOut[branch] = rrnOut;
        },
      );
      await p.setString(
        _kDailyHistoryCacheKey,
        jsonEncode(<String, dynamic>{
          'v': 2,
          'branches': branchesOut,
        }),
      );
    } catch (_) {
      return;
    }
  }

  Set<int> _workedDaysFromAny(dynamic raw) {
    final Set<int> out = <int>{};
    if (raw is! List) return out;
    final int len = math.min(raw.length, 31);
    for (int i = 0; i < len; i++) {
      if (raw[i] == true) out.add(i + 1);
    }
    return out;
  }

  Set<int> _workedDaysFromRow(_DailyWorkerRow row, int daysInMonth) {
    final Set<int> out = <int>{};
    final int len = math.min(daysInMonth, 31);
    for (int i = 0; i < len; i++) {
      if (row.days[i]) out.add(i + 1);
    }
    return out;
  }

  Future<void> _checkAcquireLossDates() async {
    if (_checkingDates) return;
    if (_workBranchName.trim().isEmpty) {
      await showMessageAlert(
        context,
        title: '사업소 미선택',
        message: '취득/상실일 확인은 상단에서 사업소(소속)를 선택한 뒤 이용해 주세요.',
      );
      return;
    }
    final int daysInMonth = _daysInMonth(_attributionMonth);

    final List<_WorkerInput> workers = <_WorkerInput>[];
    for (int i = 0; i < _rows.length; i++) {
      final _DailyWorkerRow r = _rows[i];
      if (r.name.trim().isEmpty && r.rrn.trim().isEmpty) continue;
      final String? err = validateRrn(r.rrn);
      if (err != null) {
        await showMessageAlert(
          context,
          title: '입력 오류',
          message: '${i + 1}행 주민번호: $err',
        );
        return;
      }
      workers.add(
        _WorkerInput(
          name: r.name.trim().isEmpty ? '무명' : r.name.trim(),
          rrn: formatRrn(r.rrn.replaceAll(RegExp(r'\D'), '')),
          workedDays: _workedDaysFromRow(r, daysInMonth),
        ),
      );
    }
    if (workers.isEmpty) {
      await showMessageAlert(context, message: '확인할 근로자 행이 없습니다.');
      return;
    }

    setState(() => _checkingDates = true);
    try {
      await _executeEligibilityPipeline(workers, _attributionMonth);
    } finally {
      if (mounted) setState(() => _checkingDates = false);
    }
  }

  /// `_dailyHistoryByBranch`에서 **현재 선택 사업소**의 이전 귀속월 근무일을 복사한 뒤, `workers`의 당월 근무일로 덮어 씌워 판정합니다.
  Future<void> _executeEligibilityPipeline(
    List<_WorkerInput> workers,
    DateTime attributionMonth,
  ) async {
    final Map<String, Map<int, Set<int>>> slice =
        _historySliceFor(_workBranchName);
    final Map<String, Map<int, Set<int>>> history =
        <String, Map<int, Set<int>>>{};
    for (final _WorkerInput w in workers) {
      final Map<int, Set<int>> src = slice[w.rrn] ?? <int, Set<int>>{};
      final Map<int, Set<int>> copied = <int, Set<int>>{};
      src.forEach((int k, Set<int> v) {
        copied[k] = Set<int>.from(v);
      });
      history[w.rrn] = copied;
    }

    final int currentKey = attributionMonth.year * 100 + attributionMonth.month;
    for (final _WorkerInput w in workers) {
      final Map<int, Set<int>> byMonth =
          history.putIfAbsent(w.rrn, () => <int, Set<int>>{});
      byMonth[currentKey] = Set<int>.from(w.workedDays);
    }

    final DateTime monthStart = _firstDayOfMonth(attributionMonth);
    final DateTime monthEnd =
        DateTime(attributionMonth.year, attributionMonth.month + 1, 0);

    final List<_EligibilityRowResult> result = <_EligibilityRowResult>[];
    for (final _WorkerInput w in workers) {
      final Map<String, dynamic> statusDoc =
          await _loadLatestInsuranceStatus(w.rrn);
      final _EligibilityCalc calc = _calcEligibility(
        rrn: w.rrn,
        monthDays: history[w.rrn] ?? <int, Set<int>>{},
        targetMonthStart: monthStart,
        targetMonthEnd: monthEnd,
        cachedStatus: statusDoc,
      );
      result.add(
        _EligibilityRowResult(
          name: w.name,
          rrn: w.rrn,
          currentlyAcquired: calc.currentlyAcquired,
          acquiredDate: calc.acquiredDate,
          lossDate: calc.lossDate,
          branchReason: calc.branchReason,
        ),
      );
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => _EligibilityResultDialog(
        month: attributionMonth,
        rows: result,
      ),
    );
  }

  Future<void> _persistDummyMonthFromInput(_DummyMonthlyInput input) async {
    final String branch = _workBranchName.trim();
    if (branch.isEmpty) {
      await showMessageAlert(
        context,
        title: '사업소 미선택',
        message: '더미 저장도 실제와 동일하게 사업소(소속)를 먼저 선택해 주세요.',
      );
      return;
    }
    final String rrn = _normalizeDummyRrnToKey(input.rrnRaw);
    final DateTime dim = DateTime(input.year, input.month, 1);
    final int daysInMonth = _daysInMonth(dim);
    final List<bool> src = input.days31;
    final List<bool> trimmed = List<bool>.generate(
      daysInMonth,
      (int i) => i < src.length && src[i],
    );
    final List<Map<String, dynamic>> payload = <Map<String, dynamic>>[
      <String, dynamic>{
        'name': input.name.trim().isEmpty ? '더미' : input.name.trim(),
        'rrn': rrn,
        'days': trimmed,
      },
    ];
    await FirestorePaths.dailyWorkersCol().add(<String, dynamic>{
      'createdAt': FieldValue.serverTimestamp(),
      'attributionYear': input.year,
      'attributionMonth': input.month,
      'branchName': branch,
      'rows': payload,
    });
    final int key = input.year * 100 + input.month;
    final Map<String, Map<int, Set<int>>> slice =
        _dailyHistoryByBranch.putIfAbsent(
      branch,
      () => <String, Map<int, Set<int>>>{},
    );
    final Map<int, Set<int>> byMonth =
        slice.putIfAbsent(rrn, () => <int, Set<int>>{});
    final Set<int> ds = <int>{};
    for (int i = 0; i < daysInMonth; i++) {
      if (trimmed[i]) {
        ds.add(i + 1);
      }
    }
    byMonth[key] = ds;
    if (input.name.trim().isNotEmpty) {
      final Map<String, String> nm =
          _workerNameByBranch.putIfAbsent(branch, () => <String, String>{});
      nm[rrn] = input.name.trim();
    }
    await _saveDailyHistoryCacheToPrefs();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _runEligibilityFromDummyInput(_DummyMonthlyInput input) async {
    if (_workBranchName.trim().isEmpty) {
      await showMessageAlert(
        context,
        title: '사업소 미선택',
        message: '판정에 사용할 사업소(소속)를 상단에서 먼저 선택해 주세요.',
      );
      return;
    }
    final String rrn = _normalizeDummyRrnToKey(input.rrnRaw);
    final DateTime dim = DateTime(input.year, input.month, 1);
    final int daysInMonth = _daysInMonth(dim);
    final Set<int> worked = <int>{};
    for (int i = 0; i < daysInMonth; i++) {
      if (i < input.days31.length && input.days31[i]) {
        worked.add(i + 1);
      }
    }
    final _WorkerInput w = _WorkerInput(
      name: input.name.trim().isEmpty ? '더미' : input.name.trim(),
      rrn: rrn,
      workedDays: worked,
    );
    await _executeEligibilityPipeline(<_WorkerInput>[w], dim);
  }

  void _openDummyDailyDataDialog() {
    showDialog<_DummyDlgOutcome>(
      context: context,
      builder: (BuildContext ctx) => _DailyWorkerDummyDataDialog(
        initialYear: _attributionMonth.year,
        initialMonth: _attributionMonth.month,
        yearOptions: _getYearOptions(),
      ),
    ).then((_DummyDlgOutcome? o) async {
      if (!mounted || o == null) {
        return;
      }
      if (o.action == _DummyDialogAction.saveFirestore) {
        await _persistDummyMonthFromInput(o.input);
        return;
      }
      setState(() => _checkingDates = true);
      try {
        await _runEligibilityFromDummyInput(o.input);
      } finally {
        if (mounted) {
          setState(() => _checkingDates = false);
        }
      }
    });
  }

  Future<Map<String, dynamic>> _loadLatestInsuranceStatus(String rrn) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await FirestorePaths
        .insuranceStatusCol()
        .where('rrn', isEqualTo: rrn)
        .get();
    if (snap.docs.isEmpty) return <String, dynamic>{};
    Map<String, dynamic> latest = snap.docs.first.data();
    Timestamp? latestTs = latest['createdAt'] as Timestamp?;
    for (final doc in snap.docs.skip(1)) {
      final Map<String, dynamic> d = doc.data();
      final Timestamp? ts = d['createdAt'] as Timestamp?;
      if (latestTs == null || (ts != null && ts.compareTo(latestTs) > 0)) {
        latest = d;
        latestTs = ts;
      }
    }
    return latest;
  }

  _EligibilityCalc _calcEligibility({
    required String rrn,
    required Map<int, Set<int>> monthDays,
    required DateTime targetMonthStart,
    required DateTime targetMonthEnd,
    required Map<String, dynamic> cachedStatus,
  }) {
    if (monthDays.isEmpty) {
      final bool cachedAcquired = _isCachedAcquired(cachedStatus, targetMonthEnd);
      return _EligibilityCalc(
        currentlyAcquired: cachedAcquired,
        acquiredDate: _parseDate(_cachedAcquiredDate(cachedStatus)),
        lossDate: _parseDate(_cachedLossDate(cachedStatus)),
        branchReason: '근무이력 없음: 기존 가입이력 캐시만 사용',
      );
    }

    final int targetKey = _monthKey(targetMonthStart);
    final List<int> keysInRange = monthDays.keys.where((int k) => k <= targetKey).toList()
      ..sort();
    if (keysInRange.isEmpty) {
      final bool cachedAcquired = _isCachedAcquired(cachedStatus, targetMonthEnd);
      return _EligibilityCalc(
        currentlyAcquired: cachedAcquired,
        acquiredDate: _parseDate(_cachedAcquiredDate(cachedStatus)),
        lossDate: _parseDate(_cachedLossDate(cachedStatus)),
        branchReason: '타겟월($targetKey) 이전 근무이력 키 없음: 캐시 기준',
      );
    }

    final int minKey = keysInRange.first;
    final List<DateTime> sortedDates =
        _collectSortedUniqueWorkDates(monthDays, minKey, targetKey);
    if (sortedDates.isEmpty) {
      final bool cachedAcquired = _isCachedAcquired(cachedStatus, targetMonthEnd);
      return _EligibilityCalc(
        currentlyAcquired: cachedAcquired,
        acquiredDate: _parseDate(_cachedAcquiredDate(cachedStatus)),
        lossDate: _parseDate(_cachedLossDate(cachedStatus)),
        branchReason: '구간 내 근무일 없음(맵은 있으나 체크일 없음): 캐시 기준',
      );
    }

    final List<List<DateTime>> segments =
        _splitWorkSegmentsByLaborGap(sortedDates, monthDays);

    final StringBuffer fullTrace = StringBuffer();
    final String rrnDigits = rrn.replaceAll(RegExp(r'\D'), '');
    fullTrace.writeln(
      '[식별] ${rrnDigits.length >= 6 ? '${rrnDigits.substring(0, 6)}******' : '(주민번호 형식 확인)'}',
    );
    if (segments.length > 1) {
      fullTrace.writeln(
        '[근로단절] 매월 1일~말일 전무 미근로 후 재개된 구간이 ${segments.length}개로 분리되었습니다.',
      );
    }

    _NhiSegmentSim? lastSim;
    bool anyInconclusive = false;

    for (int si = 0; si < segments.length; si++) {
      final List<DateTime> seg = segments[si];
      final DateTime firstW = seg.first;
      if (firstW.isAfter(targetMonthEnd)) {
        fullTrace.writeln(
          '=== 세그먼트 ${si + 1}: 최초 ${_eligibilityFmtDate(firstW)} (타겟월말 이후 시작, 스킵) ===',
        );
        continue;
      }
      fullTrace.writeln(
        '=== 세그먼트 ${si + 1}/${segments.length} (최초근로 ${_eligibilityFmtDate(firstW)}) ===',
      );
      final Map<int, Set<int>> clipped =
          _clipMonthDaysToSegmentBounds(monthDays, seg.first, seg.last);
      final _NhiSegmentSim sim = _simulateNhiDailyWorkerSegment(
        monthDays: clipped,
        segmentFirstWork: firstW,
        targetMonthEnd: targetMonthEnd,
        targetMonthKey: targetKey,
      );
      anyInconclusive |= sim.inconclusive;
      for (final String line in sim.trace) {
        fullTrace.writeln(line);
      }
      lastSim = sim;
    }

    if (lastSim == null) {
      final bool cachedAcquired = _isCachedAcquired(cachedStatus, targetMonthEnd);
      return _EligibilityCalc(
        currentlyAcquired: cachedAcquired,
        acquiredDate: _parseDate(_cachedAcquiredDate(cachedStatus)),
        lossDate: _parseDate(_cachedLossDate(cachedStatus)),
        branchReason: fullTrace.toString().trim(),
      );
    }

    final DateTime? acquireDate = lastSim.acquire;
    final DateTime? lossDate = lastSim.loss;
    bool computedAcquired = acquireDate != null &&
        (lossDate == null || lossDate.isAfter(targetMonthEnd));
    if (anyInconclusive) {
      computedAcquired =
          computedAcquired || _isCachedAcquired(cachedStatus, targetMonthEnd);
      fullTrace.writeln(
        '[보완] 일부 구간이 타겟월말 기준으로 미확정(취득·상실 판정에 필요한 익월/다다음달 등 부족) → '
        '취득여부는 시뮬레이션 결과와 기존 명부 캐시를 OR로 보완했습니다.',
      );
    }

    return _EligibilityCalc(
      currentlyAcquired: computedAcquired,
      acquiredDate: acquireDate ?? _parseDate(_cachedAcquiredDate(cachedStatus)),
      lossDate: lossDate ?? _parseDate(_cachedLossDate(cachedStatus)),
      branchReason: fullTrace.toString().trim(),
    );
  }

  /// 타겟월까지의 모든 근무일(중복 제거·시간순).
  List<DateTime> _collectSortedUniqueWorkDates(
    Map<int, Set<int>> monthDays,
    int minKey,
    int maxKey,
  ) {
    final SplayTreeSet<DateTime> out = SplayTreeSet<DateTime>();
    int mk = minKey;
    while (mk <= maxKey) {
      final Set<int> days = monthDays[mk] ?? <int>{};
      final int y = mk ~/ 100;
      final int m = mk % 100;
      for (final int d in days) {
        if (d >= 1 && d <= 31) {
          out.add(DateTime(y, m, d));
        }
      }
      mk = _nextMonthKey(mk);
    }
    return out.toList();
  }

  /// 규칙 1: 임의 두 근로일 사이에 '완전한 달력 한 달(1일~말일) 전무'가 끼면 세그먼트 분리.
  List<List<DateTime>> _splitWorkSegmentsByLaborGap(
    List<DateTime> sortedUnique,
    Map<int, Set<int>> monthDays,
  ) {
    final List<List<DateTime>> segments = <List<DateTime>>[];
    List<DateTime> cur = <DateTime>[sortedUnique.first];
    for (int i = 1; i < sortedUnique.length; i++) {
      final DateTime lastW = cur.last;
      final DateTime nextW = sortedUnique[i];
      if (_hasFullZeroCalendarMonthStrictlyBetween(lastW, nextW, monthDays)) {
        segments.add(cur);
        cur = <DateTime>[nextW];
      } else {
        cur.add(nextW);
      }
    }
    segments.add(cur);
    return segments;
  }

  /// 세그먼트에 속하지 않는 근무일은 제외해, 이전/이후 세그먼트 데이터가 판정에 섞이지 않게 합니다.
  Map<int, Set<int>> _clipMonthDaysToSegmentBounds(
    Map<int, Set<int>> source,
    DateTime firstInSeg,
    DateTime lastInSeg,
  ) {
    final Map<int, Set<int>> out = <int, Set<int>>{};
    source.forEach((int mk, Set<int> ds) {
      final int y = mk ~/ 100;
      final int m = mk % 100;
      final Set<int> kept = <int>{};
      for (final int d in ds) {
        if (d < 1 || d > 31) {
          continue;
        }
        final DateTime dt = DateTime(y, m, d);
        if (!dt.isBefore(firstInSeg) && !dt.isAfter(lastInSeg)) {
          kept.add(d);
        }
      }
      if (kept.isNotEmpty) {
        out[mk] = kept;
      }
    });
    return out;
  }

  bool _hasFullZeroCalendarMonthStrictlyBetween(
    DateTime lastWork,
    DateTime nextWork,
    Map<int, Set<int>> monthDays,
  ) {
    if (!nextWork.isAfter(lastWork)) {
      return false;
    }
    final int nextMonthStartKey =
        _monthKey(DateTime(nextWork.year, nextWork.month, 1));
    for (
      DateTime ms = DateTime(lastWork.year, lastWork.month, 1);
      _monthKey(ms) <= nextMonthStartKey;
      ms = DateTime(ms.year, ms.month + 1, 1)
    ) {
      final DateTime me = DateTime(ms.year, ms.month + 1, 0);
      if (ms.isAfter(lastWork) && me.isBefore(nextWork)) {
        if (_workDaysInCalendarMonth(monthDays, _monthKey(ms)) == 0) {
          return true;
        }
      }
    }
    return false;
  }

  int _workDaysInCalendarMonth(Map<int, Set<int>> monthDays, int monthKey) {
    return (monthDays[monthKey] ?? <int>{}).length;
  }

  DateTime? _lastWorkedDateInMonth(Map<int, Set<int>> monthDays, int monthKey) {
    final Set<int> ds = monthDays[monthKey] ?? <int>{};
    if (ds.isEmpty) {
      return null;
    }
    final int lastDay = ds.reduce(math.max);
    return DateTime(monthKey ~/ 100, monthKey % 100, lastDay);
  }

  /// 월중 취득(M0 기준) 이후 M3(=다다음달 다음달)부터 타겟월까지 첫 8일 미만 달 → 해당월 1일 상실.
  (DateTime loss, String reason)? _firstUnderEightMonthLossOnFirstFrom(
    Map<int, Set<int>> monthDays,
    int startMonthKey,
    int limitMonthKey,
  ) {
    for (int mk = startMonthKey; mk <= limitMonthKey; mk = _nextMonthKey(mk)) {
      final int c = _workDaysInCalendarMonth(monthDays, mk);
      if (c < 8) {
        final DateTime loss = DateTime(mk ~/ 100, mk % 100, 1);
        final String reason =
            '다다음달 이후(${_eligibilityFmtMonthKey(mk)}): 근로 ${c}일(8일 미만) '
            '→ 상실일=${_eligibilityFmtDate(loss)}(해당 월 1일, 월초 상실 형식)';
        return (loss, reason);
      }
    }
    return null;
  }

  _NhiSegmentSim _simulateNhiDailyWorkerSegment({
    required Map<int, Set<int>> monthDays,
    required DateTime segmentFirstWork,
    required DateTime targetMonthEnd,
    required int targetMonthKey,
  }) {
    final List<String> trace = <String>[];
    bool inconclusive = false;
    DateTime? acquire;
    DateTime? loss;

    final DateTime firstWork = segmentFirstWork;
    trace.add('[최초근로일(세그먼트)] ${_eligibilityFmtDate(firstWork)}');

    final int m0Key = _monthKey(DateTime(firstWork.year, firstWork.month, 1));
    final DateTime windowEnd =
        _addMonths(firstWork, 1).subtract(const Duration(days: 1));

    // --- 취득 (사례 1·2) ---
    if (targetMonthEnd.isBefore(firstWork)) {
      inconclusive = true;
      trace.add(
        '[판정보류] 타겟월말이 최초근로일보다 이전이라 취득 시뮬레이션을 진행할 수 없습니다.',
      );
      return _NhiSegmentSim(
        trace: trace,
        acquire: null,
        loss: null,
        inconclusive: true,
      );
    }

    if (targetMonthEnd.isBefore(windowEnd)) {
      inconclusive = true;
      final int partial = _countWorkedInRange(monthDays, firstWork, targetMonthEnd);
      trace.add(
        '[판정보류] 「최초근로일~1개월 되는 날(${_eligibilityFmtDate(windowEnd)})」 구간이 타겟월말까지 완결되지 않음 '
        '(현재까지 합산 $partial일). 사례1·2 확정 불가.',
      );
      return _NhiSegmentSim(
        trace: trace,
        acquire: null,
        loss: null,
        inconclusive: true,
      );
    }

    final int c1 = _countWorkedInRange(monthDays, firstWork, windowEnd);
    trace.add(
      '[사례1 검토] ${_eligibilityFmtDate(firstWork)}~${_eligibilityFmtDate(windowEnd)} '
      '합산 근로일수=$c1 (기준 8일)',
    );

    if (c1 >= 8) {
      acquire = firstWork;
      trace.add(
        '[사례1 충족] 1개월 되는 날까지 8일 이상 → 취득일=${_eligibilityFmtDate(acquire)}(최초근로일)',
      );
    } else {
      trace.add('[사례1 미충족] 위 구간이 8일 미만.');
      final DateTime followStart = DateTime(firstWork.year, firstWork.month + 1, 1);
      final DateTime followEnd =
          DateTime(followStart.year, followStart.month + 1, 0);
      final int c2 = _countWorkedInRange(monthDays, followStart, followEnd);
      trace.add(
        '[사례2 검토] 익월(최초근로월의 다음 달) ${_eligibilityFmtMonthKey(_monthKey(followStart))} '
        '1일~말일(${_eligibilityFmtDate(followStart)}~${_eligibilityFmtDate(followEnd)}) '
        '근로일수=$c2',
      );
      if (targetMonthEnd.isBefore(followEnd)) {
        inconclusive = true;
        trace.add(
          '[판정보류] 익월 전체가 타겟월말 이전에 끝나지 않아 사례2를 확정할 수 없습니다.',
        );
        return _NhiSegmentSim(
          trace: trace,
          acquire: null,
          loss: null,
          inconclusive: true,
        );
      }
      if (c2 >= 8) {
        acquire = followStart;
        trace.add(
          '[사례2 충족] 익월 만근 구간 8일 이상 → 취득일=${_eligibilityFmtDate(acquire)}(해당 익월 1일)',
        );
      } else {
        trace.add(
          '[취득 없음] 사례1·2 모두 미충족으로 본 세그먼트에서 건강보험 일용근로자 자격이 성립하지 않습니다.',
        );
        return _NhiSegmentSim(
          trace: trace,
          acquire: null,
          loss: null,
          inconclusive: false,
        );
      }
    }

    // --- 상실 (사례 3~6, 월초/월중) ---
    final DateTime acquiredOn = acquire;
    final int acqMonthKey =
        _monthKey(DateTime(acquiredOn.year, acquiredOn.month, 1));
    final bool monthStartAcquire = acquiredOn.day == 1;

    if (monthStartAcquire) {
      trace.add(
        '[상실 경로] 월초 취득(취득일이 매월 1일) → 사례4: 이후 각 달력월 1~말일 8일 미만 시 해당 월 1일 상실',
      );
      for (int mk = acqMonthKey; mk <= targetMonthKey; mk = _nextMonthKey(mk)) {
        final int cnt = _workDaysInCalendarMonth(monthDays, mk);
        trace.add(
          '  · ${_eligibilityFmtMonthKey(mk)} 근로일수=$cnt '
          '(월초취득자 월간 8일 기준)',
        );
        if (cnt < 8) {
          loss = DateTime(mk ~/ 100, mk % 100, 1);
          trace.add(
            '[사례4] 자격 취득 이후 ${_eligibilityFmtMonthKey(mk)}에 8일 미만($cnt일) '
            '→ 상실일=${_eligibilityFmtDate(loss)}(해당 월 1일)',
          );
          break;
        }
      }
      if (loss == null) {
        trace.add(
          '[사례4 해당 없음] 취득월~타겟월까지 매 달 8일 이상(또는 타겟월 이전 구간만 검사 완료)으로 자격 유지.',
        );
      }
    } else {
      // --- 월중 취득(최초근로일 = 취득일, 1일 아님) ---
      final int m1Key = _nextMonthKey(m0Key);
      final int m2Key = _nextMonthKey(m1Key);
      final int m3Key = _nextMonthKey(m2Key);
      final DateTime m1End = DateTime(m1Key ~/ 100, m1Key % 100 + 1, 0);
      final DateTime m2End = DateTime(m2Key ~/ 100, m2Key % 100 + 1, 0);

      trace.add(
        '[상실 경로] 월중 취득(최초근로일=취득일) → '
        '최초근로월(M0)=${_eligibilityFmtMonthKey(m0Key)}, '
        '익월(M+1)=${_eligibilityFmtMonthKey(m1Key)}, '
        '다다음달(M+2)=${_eligibilityFmtMonthKey(m2Key)}, '
        '그 다음(M+3~)=${_eligibilityFmtMonthKey(m3Key)}부터 월초형(1일) 상실 검사',
      );

      // (1) 익월(M+1) 달력이 타겟월말까지 완결되지 않으면 상실·사례6 모두 보류
      if (targetMonthEnd.isBefore(m1End)) {
        inconclusive = true;
        trace.add(
          '[판정보류] 익월(M+1) ${_eligibilityFmtMonthKey(m1Key)} 말일(${_eligibilityFmtDate(m1End)}) '
          '이전으로, 익월 근무일수·이후 상실(사례3·5·6)을 확정할 수 없습니다. '
          '(익월 8일 미만이어도 다다음달(M+2)을 보기 전에는 상실일을 두지 않습니다.)',
        );
      } else {
        final int d1 = _workDaysInCalendarMonth(monthDays, m1Key);
        trace.add(
          '[익월(M+1) ${_eligibilityFmtMonthKey(m1Key)}] 총 근로일수=$d1',
        );

        if (d1 >= 8) {
          trace.add(
            '[익월 8일 이상] 사례3·5(익월 8일 미만 시 원칙적 상실)는 적용되지 않습니다. '
            'M+3(${_eligibilityFmtMonthKey(m3Key)})~타겟월까지 월초형(해당 월 1일) 상실만 검사합니다.',
          );
          final (DateTime, String)? post =
              _firstUnderEightMonthLossOnFirstFrom(monthDays, m3Key, targetMonthKey);
          if (post != null) {
            loss = post.$1;
            trace.add('[${post.$2}]');
          } else {
            trace.add(
              '[유지] ${_eligibilityFmtMonthKey(m3Key)}~타겟월까지 8일 미만 달 없음.',
            );
          }
        } else {
          trace.add(
            '[익월(M+1) 8일 미만] 원칙적으로는 익월 최종근로일 익일 상실(사례3·5) 대상이나, '
            '건강보험공단 사례6에 따라 **반드시 다다음달(M+2) 근무일수를 먼저 확인**합니다. '
            '이 단계에서는 익월 상실일을 확정하지 않습니다.',
          );

          // (2)(3) M+2 달력이 끝나기 전에는 M+1 상실을 절대 확정하지 않음
          if (targetMonthEnd.isBefore(m2End)) {
            inconclusive = true;
            trace.add(
              '[판정보류] 다다음달(M+2) ${_eligibilityFmtMonthKey(m2Key)} 말일(${_eligibilityFmtDate(m2End)}) '
              '이전 데이터만 있어 사례6(자격 유지 여부) 및 사례3·5(익월 상실일)를 확정할 수 없습니다.',
            );
          } else {
            // (2) M+2 말일까지 데이터가 있음 → 총 근무일수(0일 포함)로 사례6 vs 사례3·5 분기
            final int d2 = _workDaysInCalendarMonth(monthDays, m2Key);
            trace.add(
              '[다다음달(M+2) ${_eligibilityFmtMonthKey(m2Key)}] 총 근로일수=$d2 '
              '(0일=해당 달 무근로, 8일 미만과 동일 취급)',
            );

            if (d2 >= 8) {
              trace.add(
                '[사례6 적용] 월중 취득 후 익월(M+1) ${_eligibilityFmtMonthKey(m1Key)}는 '
                '8일 미만이나, 다다음달(M+2) ${_eligibilityFmtMonthKey(m2Key)}는 $d2일로 8일 이상 '
                '→ 익월 원칙적 상실(최종근로일+1) **부적용**, 자격 유지. '
                '이후 M+3(${_eligibilityFmtMonthKey(m3Key)})~타겟월은 월초형(1일) 상실 규칙으로 검사합니다.',
              );
              final (DateTime, String)? post =
                  _firstUnderEightMonthLossOnFirstFrom(monthDays, m3Key, targetMonthKey);
              if (post != null) {
                loss = post.$1;
                trace.add('[${post.$2}]');
              } else {
                trace.add(
                  '[유지] ${_eligibilityFmtMonthKey(m3Key)}~타겟월까지 8일 미만 달 없음.',
                );
              }
            } else {
              // (4) M+2도 8일 미만(또는 무근로)일 때에만 비로소 익월 상실 확정
              final DateTime? lastM1 = _lastWorkedDateInMonth(monthDays, m1Key);
              if (lastM1 != null) {
                loss = lastM1.add(const Duration(days: 1));
                trace.add(
                  '[사례3/5 적용] 월중 취득 후 익월(M+1) ${_eligibilityFmtMonthKey(m1Key)}는 '
                  '8일 미만이고, 다다음달(M+2) ${_eligibilityFmtMonthKey(m2Key)}는 $d2일(8일 미만 또는 무근로) '
                  '→ 익월 최종근로일 익일 상실 확정: '
                  '익월 최종근로 ${_eligibilityFmtDate(lastM1)} → 상실일=${_eligibilityFmtDate(loss)}',
                );
              } else {
                loss = DateTime(m1Key ~/ 100, m1Key % 100, 1);
                trace.add(
                  '[사례3/5 적용] 월중 취득 후 익월(M+1) 8일 미만 및 다다음달(M+2) '
                  '${_eligibilityFmtMonthKey(m2Key)} $d2일(8일 미만)이나 익월에 근로일이 없어 '
                  '최종근로일을 특정할 수 없음 → 상실일=${_eligibilityFmtDate(loss)}(익월 1일 처리)',
                );
              }
            }
          }
        }
      }
    }

    final bool acquiredNow = loss == null || loss.isAfter(targetMonthEnd);
    trace.add(
      '[타겟월말 ${_eligibilityFmtDate(targetMonthEnd)} 기준] '
      '취득=${_eligibilityFmtDate(acquiredOn)}, '
      '상실=${loss != null ? _eligibilityFmtDate(loss) : "-"}, '
      '현재자격=${acquiredNow ? "유지(취득)" : "없음(상실 적용)"}',
    );

    return _NhiSegmentSim(
      trace: trace,
      acquire: acquiredOn,
      loss: loss,
      inconclusive: inconclusive,
    );
  }

  String _eligibilityFmtDate(DateTime d) {
    final String y = d.year.toString().padLeft(4, '0');
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _eligibilityFmtMonthKey(int monthKey) {
    return '${monthKey ~/ 100}년 ${monthKey % 100}월';
  }

  int _nextMonthKey(int monthKey) {
    final int y = monthKey ~/ 100;
    final int m = monthKey % 100;
    final DateTime next = DateTime(y, m + 1, 1);
    return next.year * 100 + next.month;
  }

  int _countWorkedInRange(
    Map<int, Set<int>> monthDays,
    DateTime start,
    DateTime end,
  ) {
    int count = 0;
    DateTime cursor = DateTime(start.year, start.month, 1);
    final DateTime lastMonth = DateTime(end.year, end.month, 1);
    while (!cursor.isAfter(lastMonth)) {
      final int mk = _monthKey(cursor);
      final Set<int> dset = monthDays[mk] ?? <int>{};
      for (final int d in dset) {
        final DateTime dt = DateTime(cursor.year, cursor.month, d);
        if (!dt.isBefore(start) && !dt.isAfter(end)) {
          count++;
        }
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return count;
  }

  String _cachedAcquiredDate(Map<String, dynamic> d) {
    final String n = (d['nationalAcquiredDate'] as String?)?.trim() ?? '';
    if (n.isNotEmpty) return n;
    return (d['acquiredDate'] as String?)?.trim() ?? '';
  }

  String _cachedLossDate(Map<String, dynamic> d) {
    final String n = (d['nationalLossDate'] as String?)?.trim() ?? '';
    if (n.isNotEmpty) return n;
    return (d['lossDate'] as String?)?.trim() ?? '';
  }

  DateTime? _parseDate(String raw) {
    final String t = raw.trim();
    if (t.isEmpty) return null;
    try {
      final List<String> parts = t.split(RegExp(r'[-/.]'));
      if (parts.length >= 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (_) {}
    return null;
  }

  bool _isCachedAcquired(Map<String, dynamic> d, DateTime asOf) {
    final DateTime? acq = _parseDate(_cachedAcquiredDate(d));
    final DateTime? loss = _parseDate(_cachedLossDate(d));
    if (acq == null) return false;
    if (acq.isAfter(asOf)) return false;
    if (loss != null && !loss.isAfter(asOf)) return false;
    return true;
  }

  void _openMonthlyWorkCheckDialog() {
    final Set<int> monthKeys = <int>{};
    for (final Map<String, Map<int, Set<int>>> byRrn
        in _dailyHistoryByBranch.values) {
      for (final Map<int, Set<int>> byMonth in byRrn.values) {
        monthKeys.addAll(byMonth.keys);
      }
    }
    final List<int> sortedMonthKeys = monthKeys.toList()..sort();
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => _MonthlyWorkCheckDialog(
        initialMonth: _attributionMonth,
        monthKeys: sortedMonthKeys,
        historyByBranch: _dailyHistoryByBranch,
        nameByBranch: _workerNameByBranch,
        allowAllBranchesFilter: !_branchLocked,
        initialFilterBranch:
            _branchLocked ? _workBranchName : _kAllBranchesMonthlyFilter,
      ),
    );
  }

  Widget _buildBranchSelectorRow(List<String> branchNames, bool streamsWaiting) {
    if (_branchLocked) {
      return Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _workBranchName.isEmpty ? '(프로필 사업소 확인 필요)' : _workBranchName,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            '고정',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      );
    }
    if (streamsWaiting && branchNames.isEmpty) {
      return Text(
        '사업소 목록 불러오는 중…',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      );
    }
    if (branchNames.isEmpty) {
      return Text(
        '등록된 사업소가 없습니다. 관리자 메뉴에서 사업소를 등록해 주세요.',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      );
    }
    final bool hasValue =
        _workBranchName.isNotEmpty && branchNames.contains(_workBranchName);
    return DropdownButton<String>(
      isExpanded: true,
      value: hasValue ? _workBranchName : null,
      hint: const Text('사업소를 선택하세요'),
      items: branchNames
          .map(
            (String n) => DropdownMenuItem<String>(
              value: n,
              child: Text(n, style: const TextStyle(fontSize: 14)),
            ),
          )
          .toList(),
      onChanged: (String? v) {
        if (v != null) {
          setState(() => _workBranchName = v);
        }
      },
    );
  }

  Future<void> _exportExcel() async {
    final int daysInMonth = _daysInMonth(_attributionMonth);
    try {
      final ByteData bd = await rootBundle.load(_kDailyWorkerElectroTemplateAsset);
      final Uint8List templateBytes = bd.buffer.asUint8List();
      final Excel excel = Excel.decodeBytes(templateBytes);
      if (!excel.tables.containsKey('서식')) {
        if (mounted) {
          await showMessageAlert(
            context,
            title: '엑셀',
            message: '템플릿에 「서식」시트가 없습니다. assets의 양식 파일을 확인해 주세요.',
          );
        }
        return;
      }

      /// `excel` 인코더가 외부참조·다중 시트 조합에서 실패하는 경우가 있어,
      /// 전자신고에 필요한 「서식」만 남기고 나머지 시트는 제거합니다.
      try {
        final List<String> otherSheets = excel.tables.keys
            .where((String n) => n != '서식')
            .toList();
        for (final String name in otherSheets) {
          if (excel.tables.length <= 1) {
            break;
          }
          excel.delete(name);
        }
      } catch (e, st) {
        debugPrint('_exportExcel: 시트 정리 건너뜀: $e\n$st');
      }

      final Sheet sheet = excel['서식'];

      /// 신양식: 데이터는 2행부터, 근무일은 K~AO(31일). 양식 검증은 숫자 `1` 기재 — 문자열 `1`로 기재해 인코딩 안정화.
      const int startRow = 2;
      const int dayStartCol = 11;

      final String yyyymm =
          '${_attributionMonth.year}${_attributionMonth.month.toString().padLeft(2, '0')}';
      for (int i = 0; i < _rows.length; i++) {
        final _DailyWorkerRow row = _rows[i];
        final int rowNum = startRow + i;
        sheet.cell(CellIndex.indexByString('A$rowNum')).value =
            TextCellValue('3');
        sheet.cell(CellIndex.indexByString('B$rowNum')).value =
            TextCellValue(row.name.trim());
        final String rrnDigits = row.rrn.replaceAll(RegExp(r'\D'), '');
        final String rrn13 = rrnDigits.length >= 13
            ? rrnDigits.substring(0, 13)
            : rrnDigits;
        sheet.cell(CellIndex.indexByString('C$rowNum')).value =
            TextCellValue(rrn13);
        sheet.cell(CellIndex.indexByString('D$rowNum')).value =
            TextCellValue(yyyymm);
        for (int day = 1; day <= daysInMonth; day++) {
          if (!row.days[day - 1]) {
            continue;
          }
          final String col =
              _excelColumnLettersFromIndex1Based(dayStartCol + day - 1);
          sheet.cell(CellIndex.indexByString('$col$rowNum')).value =
              TextCellValue('1');
        }
      }

      final List<int>? encoded = excel.encode();
      if (encoded == null || encoded.isEmpty) {
        if (mounted) {
          await showMessageAlert(
            context,
            title: '엑셀',
            message: '엑셀 파일을 생성하지 못했습니다.(인코딩 실패)',
          );
        }
        return;
      }
      final Uint8List outBytes = Uint8List.fromList(encoded);
      final String branchPart = _workBranchName.trim().isEmpty
          ? '미지정'
          : _workBranchName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final String fileName = '근로내용확인신고_${yyyymm}_$branchPart.xlsx';

      if (kIsWeb) {
        downloadBytesInBrowser(
          outBytes,
          fileName,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else {
        final bool saved = await saveXlsxWithFilePicker(
          bytes: outBytes,
          suggestedFileName: fileName,
        );
        if (!saved && mounted) {
          await showMessageAlert(
            context,
            message: '저장 위치를 선택하지 않아 파일 저장을 건너뛰었습니다.',
          );
        }
      }
    } catch (e, st) {
      debugPrint('_exportExcel: $e\n$st');
      if (mounted) {
        await showMessageAlert(
          context,
          title: '엑셀',
          message: '엑셀을 불러오거나 저장하는 중 오류가 났습니다: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const EnterpriseScaffold(
        title: '4대보험 · 일용직 관리',
        child: Center(child: Text('로그인 후 이용할 수 있습니다.')),
      );
    }
    return Consumer<WorkFirestoreRepository>(
      builder: (
        BuildContext context,
        WorkFirestoreRepository repo,
        Widget? _,
      ) {
        return MergedUserProfileStreamBuilder(
          uid: user.uid,
          builder: (
            BuildContext context,
            Map<String, dynamic> merged,
            bool waitingProfile,
          ) {
            return StreamBuilder<List<BranchModel>>(
              stream: repo.watchBranches(),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<BranchModel>> branchSnap,
              ) {
                final List<BranchModel> branches =
                    branchSnap.data ?? const <BranchModel>[];
                final bool waitingBranches =
                    branchSnap.connectionState == ConnectionState.waiting &&
                        !branchSnap.hasData;
                _scheduleBranchContextSync(merged, branches);
                return _buildDailyWorkerMain(
                  branches: branches,
                  streamsWaiting: waitingProfile || waitingBranches,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDailyWorkerMain({
    required List<BranchModel> branches,
    required bool streamsWaiting,
  }) {
    final List<int> yearOptions = _getYearOptions();
    final int daysInMonth = _daysInMonth(_attributionMonth);
    final List<String> branchNames = branches
        .map((BranchModel b) => b.name.trim())
        .where((String n) => n.isNotEmpty)
        .toList();

    return EnterpriseScaffold(
      title: '4대보험 · 일용직 관리',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                const Text(
                  '귀속연',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: yearOptions.contains(_attributionMonth.year)
                      ? _attributionMonth.year
                      : yearOptions.first,
                  items: yearOptions
                      .map((int y) => DropdownMenuItem<int>(
                            value: y,
                            child: Text(
                              '$y년',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ))
                      .toList(),
                  onChanged: (int? v) {
                    if (v != null) {
                      _onAttributionChanged(v, _attributionMonth.month);
                    }
                  },
                ),
                const SizedBox(width: 16),
                const Text(
                  '귀속월',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _attributionMonth.month,
                  items: List<int>.generate(12, (int i) => i + 1)
                      .map((int m) => DropdownMenuItem<int>(
                            value: m,
                            child: Text(
                              '$m월',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ))
                      .toList(),
                  onChanged: (int? v) {
                    if (v != null) {
                      _onAttributionChanged(_attributionMonth.year, v);
                    }
                  },
                ),
                const SizedBox(width: 16),
                const Text(
                  '소속 사업소',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 140, maxWidth: 320),
                  child: _buildBranchSelectorRow(branchNames, streamsWaiting),
                ),
                const SizedBox(width: 24),
                if (!_dailyCacheReady || streamsWaiting)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '근무이력 캐시 동기화 중...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                '일용직 근로자 관리',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _rows.add(_DailyWorkerRow());
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('행 추가'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('저장 & 엑셀 생성'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _checkingDates ? null : _checkAcquireLossDates,
                    icon: _checkingDates
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.rule_folder_outlined, size: 18),
                    label: const Text('취득/상실일 확인'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _openMonthlyWorkCheckDialog,
                    icon: const Icon(Icons.calendar_view_month, size: 18),
                    label: const Text('근무일 확인'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _openDummyDailyDataDialog,
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: const Text('더미 데이터'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Scrollbar(
                  thumbVisibility: true,
                  controller: _horizontalScroll,
                  child: SingleChildScrollView(
                    controller: _horizontalScroll,
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 1100),
                        child: DataTable(
                        columnSpacing: 2,
                        horizontalMargin: 8,
                        headingRowHeight: 36,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 44,
                        columns: <DataColumn>[
                          const DataColumn(
                            label: SizedBox(
                              width: 100,
                              child: Text('성명'),
                            ),
                          ),
                          const DataColumn(
                            label: SizedBox(
                              width: 130,
                              child: Text('주민번호'),
                            ),
                          ),
                          for (int day = 1; day <= daysInMonth; day++)
                            DataColumn(
                              label: SizedBox(
                                width: 24,
                                child: Center(child: Text('$day')),
                              ),
                            ),
                          const DataColumn(
                            label: SizedBox(width: 48, child: Text('')),
                          ),
                        ],
                        rows: List<DataRow>.generate(_rows.length, (int index) {
                          final _DailyWorkerRow row = _rows[index];
                          return DataRow(
                            cells: <DataCell>[
                              DataCell(
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                    ),
                                    controller: row.nameController,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      hintText: '900101-1234567',
                                      counterText: '',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                    ),
                                    controller: row.rrnController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 14,
                                    inputFormatters: digitHyphenFormatters,
                                    onChanged: (String v) {
                                      if (v.length == 6 &&
                                          !v.contains('-')) {
                                        row.rrnController.text = '$v-';
                                        row.rrnController.selection =
                                            TextSelection.fromPosition(
                                          const TextPosition(offset: 7),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                              for (int day = 0; day < daysInMonth; day++)
                                DataCell(
                                  _DayCheckbox(
                                    value: row.days[day],
                                    onChanged: (bool? value) {
                                      setState(() {
                                        row.days[day] = value ?? false;
                                      });
                                    },
                                  ),
                                ),
                              DataCell(
                                IconButton(
                                  tooltip: '행 삭제',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _rows.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DummyDialogAction { saveFirestore, eligibilityOnly }

class _DummyMonthlyInput {
  _DummyMonthlyInput({
    required this.year,
    required this.month,
    required this.name,
    required this.rrnRaw,
    required List<bool> days31,
  }) : days31 = List<bool>.from(days31);

  final int year;
  final int month;
  final String name;
  final String rrnRaw;
  final List<bool> days31;
}

class _DummyDlgOutcome {
  const _DummyDlgOutcome({
    required this.action,
    required this.input,
  });

  final _DummyDialogAction action;
  final _DummyMonthlyInput input;
}

class _DailyWorkerDummyDataDialog extends StatefulWidget {
  const _DailyWorkerDummyDataDialog({
    required this.initialYear,
    required this.initialMonth,
    required this.yearOptions,
  });

  final int initialYear;
  final int initialMonth;
  final List<int> yearOptions;

  @override
  State<_DailyWorkerDummyDataDialog> createState() =>
      _DailyWorkerDummyDataDialogState();
}

class _DailyWorkerDummyDataDialogState extends State<_DailyWorkerDummyDataDialog> {
  late int _year;
  late int _month;
  final TextEditingController _name = TextEditingController(text: '테스트');
  final TextEditingController _rrn = TextEditingController(text: 'dummy');
  final List<bool> _days = List<bool>.filled(31, false);

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  @override
  void dispose() {
    _name.dispose();
    _rrn.dispose();
    super.dispose();
  }

  int _daysInSelectedMonth() => DateTime(_year, _month + 1, 0).day;

  String? _validateAttribution() {
    final DateTime now = DateTime.now();
    final DateTime sel = DateTime(_year, _month, 1);
    final DateTime cur = DateTime(now.year, now.month, 1);
    if (sel.isAfter(cur)) {
      return '귀속월은 오늘이 속한 달까지만 선택할 수 있습니다.';
    }
    return null;
  }

  _DummyMonthlyInput _collectInput() {
    return _DummyMonthlyInput(
      year: _year,
      month: _month,
      name: _name.text,
      rrnRaw: _rrn.text,
      days31: _days,
    );
  }

  void _fillRangeInclusive(int fromDay, int toDay) {
    final int dim = _daysInSelectedMonth();
    setState(() {
      for (int i = 0; i < 31; i++) {
        _days[i] = false;
      }
      for (int d = fromDay; d <= toDay && d <= dim; d++) {
        _days[d - 1] = true;
      }
    });
  }

  void _clearDays() {
    setState(() {
      for (int i = 0; i < _days.length; i++) {
        _days[i] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final int dim = _daysInSelectedMonth();
    return AlertDialog(
      title: const Text('더미 근로 이력 (테스트)'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                '주민번호는 임의 문자도 가능합니다. 저장·판정 시 숫자만 모아 13자리 키로 정규화됩니다.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Text('귀속연'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: widget.yearOptions.contains(_year)
                        ? _year
                        : widget.yearOptions.first,
                    items: widget.yearOptions
                        .map(
                          (int y) => DropdownMenuItem<int>(
                            value: y,
                            child: Text('$y년'),
                          ),
                        )
                        .toList(),
                    onChanged: (int? v) {
                      if (v != null) {
                        setState(() => _year = v);
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text('귀속월'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _month,
                    items: List<int>.generate(12, (int i) => i + 1)
                        .map(
                          (int m) => DropdownMenuItem<int>(
                            value: m,
                            child: Text('$m월'),
                          ),
                        )
                        .toList(),
                    onChanged: (int? v) {
                      if (v != null) {
                        setState(() => _month = v);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '성명',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rrn,
                decoration: const InputDecoration(
                  labelText: '주민번호(임의)',
                  hintText: '예: test, 123, 900101-1000000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  TextButton(
                    onPressed: () => _fillRangeInclusive(1, dim),
                    child: const Text('전일 근무'),
                  ),
                  TextButton(
                    onPressed: () => _fillRangeInclusive(1, math.min(8, dim)),
                    child: const Text('1~8일'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (int d = 1; d <= dim; d++) {
                          _days[d - 1] = d.isEven;
                        }
                      });
                    },
                    child: const Text('짝수일'),
                  ),
                  TextButton(
                    onPressed: _clearDays,
                    child: const Text('초기화'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$_year년 $_month월 근무 ($_daysInSelectedMonth()일)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: List<Widget>.generate(dim, (int i) {
                  final int day = i + 1;
                  return FilterChip(
                    label: Text('$day', style: const TextStyle(fontSize: 11)),
                    selected: _days[i],
                    onSelected: (bool v) {
                      setState(() => _days[i] = v);
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '저장 시 Firestore 일용직 컬렉션에 추가됩니다. '
                '「취득/상실만」은 저장 없이 로컬 근무이력 캐시에 있는 동일 주민번호(정규화 키)의 '
                '이전 귀속월 데이터와 위 근무일을 합쳐 시뮬레이션합니다.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
        TextButton(
          onPressed: () {
            final String? err = _validateAttribution();
            if (err != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              return;
            }
            Navigator.pop(
              context,
              _DummyDlgOutcome(
                action: _DummyDialogAction.eligibilityOnly,
                input: _collectInput(),
              ),
            );
          },
          child: const Text('취득/상실만 확인'),
        ),
        ElevatedButton(
          onPressed: () {
            final String? err = _validateAttribution();
            if (err != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              return;
            }
            Navigator.pop(
              context,
              _DummyDlgOutcome(
                action: _DummyDialogAction.saveFirestore,
                input: _collectInput(),
              ),
            );
          },
          child: const Text('Firestore 저장'),
        ),
      ],
    );
  }
}

/// 일용근로자 건강보험 자격 시뮬레이션(세그먼트 1구간) 결과.
class _NhiSegmentSim {
  _NhiSegmentSim({
    required this.trace,
    this.acquire,
    this.loss,
    required this.inconclusive,
  });

  final List<String> trace;
  final DateTime? acquire;
  final DateTime? loss;
  final bool inconclusive;
}

class _DayCheckbox extends StatefulWidget {
  const _DayCheckbox({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  State<_DayCheckbox> createState() => _DayCheckboxState();
}

class _DayCheckboxState extends State<_DayCheckbox> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: Center(
        child: Tooltip(
          message: '탭(tab) 키를 눌러 다음 일자로 넘어갈 수 있습니다',
          child: Listener(
            onPointerDown: (_) => _focusNode.requestFocus(),
            child: Checkbox(
              value: widget.value,
              focusNode: _focusNode,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: widget.onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyWorkerRow {
  _DailyWorkerRow();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController rrnController = TextEditingController();
  final List<bool> days = List<bool>.filled(31, false);

  String get name => nameController.text.trim();
  String get rrn => rrnController.text.trim();

  Map<String, dynamic> toJson(int daysInMonth) {
    final int len = math.min(daysInMonth, 31);
    return <String, dynamic>{
      'name': name,
      'rrn': rrn,
      'days': days.take(len).toList(),
    };
  }
}

class _WorkerInput {
  _WorkerInput({
    required this.name,
    required this.rrn,
    required this.workedDays,
  });

  final String name;
  final String rrn;
  final Set<int> workedDays;
}

class _EligibilityCalc {
  _EligibilityCalc({
    required this.currentlyAcquired,
    required this.acquiredDate,
    required this.lossDate,
    required this.branchReason,
  });

  final bool currentlyAcquired;
  final DateTime? acquiredDate;
  final DateTime? lossDate;
  final String branchReason;
}

class _EligibilityRowResult {
  _EligibilityRowResult({
    required this.name,
    required this.rrn,
    required this.currentlyAcquired,
    required this.acquiredDate,
    required this.lossDate,
    required this.branchReason,
  });

  final String name;
  final String rrn;
  final bool currentlyAcquired;
  final DateTime? acquiredDate;
  final DateTime? lossDate;
  final String branchReason;
}

class _EligibilityResultDialog extends StatelessWidget {
  const _EligibilityResultDialog({
    required this.month,
    required this.rows,
  });

  final DateTime month;
  final List<_EligibilityRowResult> rows;

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    final String y = d.year.toString().padLeft(4, '0');
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${month.year}년 ${month.month}월 취득/상실일 확인',
      ),
      content: SizedBox(
        width: 980,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 14,
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            dataTextStyle: const TextStyle(fontSize: 12),
            columns: const <DataColumn>[
              DataColumn(label: Text('이름')),
              DataColumn(label: Text('주민번호')),
              DataColumn(label: Text('현재취득여부')),
              DataColumn(label: Text('취득일')),
              DataColumn(label: Text('상실일')),
              DataColumn(label: Text('확인 정보')),
            ],
            rows: rows.map((r) {
              return DataRow(
                cells: <DataCell>[
                  DataCell(Text(r.name)),
                  DataCell(Text(r.rrn)),
                  DataCell(
                    Text(
                      r.currentlyAcquired ? '취득' : '미취득',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: r.currentlyAcquired
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  DataCell(Text(_fmtDate(r.acquiredDate))),
                  DataCell(Text(_fmtDate(r.lossDate))),
                  DataCell(
                    SizedBox(
                      width: 340,
                      child: Text(
                        r.branchReason,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('확인'),
        ),
      ],
    );
  }
}

class _MonthlyWorkEntry {
  _MonthlyWorkEntry({
    required this.branchLabel,
    required this.name,
    required this.rrn,
    required this.days,
  });

  final String branchLabel;
  final String name;
  final String rrn;
  final Set<int> days;
}

class _MonthlyWorkCheckDialog extends StatefulWidget {
  const _MonthlyWorkCheckDialog({
    required this.initialMonth,
    required this.monthKeys,
    required this.historyByBranch,
    required this.nameByBranch,
    required this.allowAllBranchesFilter,
    required this.initialFilterBranch,
  });

  final DateTime initialMonth;
  final List<int> monthKeys;
  final Map<String, Map<String, Map<int, Set<int>>>> historyByBranch;
  final Map<String, Map<String, String>> nameByBranch;
  final bool allowAllBranchesFilter;
  final String initialFilterBranch;

  @override
  State<_MonthlyWorkCheckDialog> createState() =>
      _MonthlyWorkCheckDialogState();
}

class _MonthlyWorkCheckDialogState extends State<_MonthlyWorkCheckDialog> {
  late int _year;
  late int _month;
  late String _branchFilter;
  final TextEditingController _nameSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _year = widget.initialMonth.year;
    _month = widget.initialMonth.month;
    _branchFilter = widget.initialFilterBranch;
  }

  @override
  void dispose() {
    _nameSearchController.dispose();
    super.dispose();
  }

  List<int> _yearOptions() {
    final Set<int> years = <int>{_year};
    for (final int mk in widget.monthKeys) {
      years.add(mk ~/ 100);
    }
    final List<int> out = years.toList()..sort();
    return out.reversed.toList();
  }

  int get _targetMonthKey => _year * 100 + _month;

  List<String> _sortedBranchKeysForDropdown() {
    final List<String> keys = widget.historyByBranch.keys.toList();
    keys.sort((String a, String b) {
      if (a.isEmpty && b.isNotEmpty) return 1;
      if (a.isNotEmpty && b.isEmpty) return -1;
      return a.compareTo(b);
    });
    return keys;
  }

  List<_MonthlyWorkEntry> _buildRows() {
    final String keyword = _nameSearchController.text.trim();
    final String kw = keyword.toLowerCase();
    final List<_MonthlyWorkEntry> out = <_MonthlyWorkEntry>[];

    Iterable<String> branchIter;
    if (!widget.allowAllBranchesFilter) {
      final String fixed = widget.initialFilterBranch.trim();
      branchIter = <String>[fixed];
    } else if (_branchFilter == _kAllBranchesMonthlyFilter) {
      branchIter = widget.historyByBranch.keys;
    } else {
      branchIter = <String>[_branchFilter];
    }

    for (final String branch in branchIter) {
      final Map<String, Map<int, Set<int>>>? byRrn =
          widget.historyByBranch[branch];
      if (byRrn == null) {
        continue;
      }
      final String branchLabel = branch.isEmpty ? '(미지정)' : branch;
      byRrn.forEach((String rrn, Map<int, Set<int>> byMonth) {
        final Set<int> days = byMonth[_targetMonthKey] ?? <int>{};
        if (days.isEmpty) {
          return;
        }
        final String name =
            (widget.nameByBranch[branch]?[rrn] ?? '').trim();
        if (kw.isNotEmpty && !name.toLowerCase().contains(kw)) {
          return;
        }
        out.add(
          _MonthlyWorkEntry(
            branchLabel: branchLabel,
            name: name.isEmpty ? '-' : name,
            rrn: rrn,
            days: days,
          ),
        );
      });
    }
    out.sort((a, b) {
      int c = a.branchLabel.compareTo(b.branchLabel);
      if (c != 0) {
        return c;
      }
      c = a.name.compareTo(b.name);
      if (c != 0) {
        return c;
      }
      return a.rrn.compareTo(b.rrn);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final List<_MonthlyWorkEntry> rows = _buildRows();
    final List<int> years = _yearOptions();
    final bool showBranchCol = widget.allowAllBranchesFilter;
    final List<String> branchKeys = _sortedBranchKeysForDropdown();

    return AlertDialog(
      title: const Text('근무일 확인'),
      content: SizedBox(
        width: 980,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  '연/월',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: years.contains(_year) ? _year : years.first,
                  items: years
                      .map(
                        (int y) => DropdownMenuItem<int>(
                          value: y,
                          child: Text('$y년'),
                        ),
                      )
                      .toList(),
                  onChanged: (int? v) {
                    if (v != null) {
                      setState(() => _year = v);
                    }
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _month,
                  items: List<int>.generate(12, (int i) => i + 1)
                      .map(
                        (int m) => DropdownMenuItem<int>(
                          value: m,
                          child: Text('$m월'),
                        ),
                      )
                      .toList(),
                  onChanged: (int? v) {
                    if (v != null) {
                      setState(() => _month = v);
                    }
                  },
                ),
                if (widget.allowAllBranchesFilter) ...<Widget>[
                  const SizedBox(width: 16),
                  const Text(
                    '사업소',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _branchFilter == _kAllBranchesMonthlyFilter ||
                            branchKeys.contains(_branchFilter)
                        ? _branchFilter
                        : _kAllBranchesMonthlyFilter,
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: _kAllBranchesMonthlyFilter,
                        child: Text('전체'),
                      ),
                      ...branchKeys.map(
                        (String k) => DropdownMenuItem<String>(
                          value: k,
                          child: Text(
                            k.isEmpty ? '(미지정)' : k,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (String? v) {
                      if (v != null) {
                        setState(() => _branchFilter = v);
                      }
                    },
                  ),
                ],
                const SizedBox(width: 16),
                const Text(
                  '이름',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _nameSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '이름 검색 (비우면 전체)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: rows.isEmpty
                  ? const Center(
                      child: Text(
                        '해당 조건의 근무 이력이 없습니다.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 14,
                        columns: <DataColumn>[
                          if (showBranchCol)
                            const DataColumn(label: Text('사업소')),
                          const DataColumn(label: Text('이름')),
                          const DataColumn(label: Text('주민번호')),
                          const DataColumn(label: Text('근무일수')),
                          const DataColumn(label: Text('근무일자')),
                        ],
                        rows: rows.map((e) {
                          final List<int> sortedDays = e.days.toList()..sort();
                          return DataRow(
                            cells: <DataCell>[
                              if (showBranchCol)
                                DataCell(Text(e.branchLabel)),
                              DataCell(Text(e.name)),
                              DataCell(Text(e.rrn)),
                              DataCell(Text('${sortedDays.length}일')),
                              DataCell(
                                SizedBox(
                                  width: showBranchCol ? 300 : 360,
                                  child: Text(
                                    sortedDays.join(', '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

