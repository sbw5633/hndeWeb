import 'dart:collection';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

const Color _navy = Color(0xFF1E3A8A);

const String _kTooltipSeparationReason =
    '1.회사의 사정에 의한 이직(폐업 등)\n2.부득이한 개인 사정(질병 등)\n3.기타 개인사정(전직 등)';
const String _kTooltipPremiumReason =
    '해당자만 기재\n보험료 부과구분 링크 참고';
const String _kTooltipJobCode =
    '직종은 공통코드표의 직종분류를 참고해 입력하세요. 우측 아이콘으로 코드표를 열 수 있습니다.';
const String _kTooltipNationalityStay =
    '국적·체류자격은 공통코드표를 참고해 입력하세요. 우측 아이콘으로 코드표를 열 수 있습니다.';
const String _kTooltipDayNav = 'Tab키 이동, Space 선택';

const String _k4insureCodeListBase =
    'http://www.4insure.or.kr/pbiz/cmmn/selectComCdList.do?comCdClsfId=';

Future<void> _launch4insureCodeRef(String comCdClsfId) async {
  final Uri uri = Uri.parse('$_k4insureCodeListBase$comCdClsfId');
  await launchUrl(uri, webOnlyWindowName: '_blank');
}

/// 4대보험 공통코드 조회(새 창).
class _CodeRefIconButton extends StatelessWidget {
  const _CodeRefIconButton({
    required this.comCdClsfId,
    this.tooltip,
  });

  final String comCdClsfId;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      tooltip: tooltip ?? '코드 조회 (새 창)',
      icon: const Icon(Icons.open_in_new, size: 17),
      onPressed: () => _launch4insureCodeRef(comCdClsfId),
    );
  }
}

InputDecoration _dwOutlineDecoration({required bool enabled}) {
  const Color borderColor = Color(0xFFCBD5E1);
  return InputDecoration(
    isDense: true,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    filled: true,
    fillColor: enabled ? Colors.white : const Color(0xFFF1F5F9),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: borderColor),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
  );
}

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

class DailyWorkerPage extends StatefulWidget {
  const DailyWorkerPage({super.key});

  @override
  State<DailyWorkerPage> createState() => _DailyWorkerPageState();
}

class _DailyWorkerPageState extends State<DailyWorkerPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<Worker> _rows = <Worker>[];
  late final ScrollController _horizontalScroll;
  final TextEditingController _bulkPayMonth = TextEditingController();
  final GlobalKey<_BulkApplyPanelState> _bulkApplyPanelKey =
      GlobalKey<_BulkApplyPanelState>();
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
  Timer? _firestoreHistoryPrefsDebounce;
  Timer? _formHistoryPrefsDebounce;
  /// 근무이력 로컬 캐시(SharedPreferences) 저장: 입력 중에는 디바운스 후에만 실행.
  static const Duration _kFormHistoryPrefsDebounce = Duration(milliseconds: 2000);
  static const Duration _kFirestoreHistoryPrefsDebounce = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    _horizontalScroll = ScrollController();
    _bulkPayMonth.text =
        '${_attributionMonth.year}${_attributionMonth.month.toString().padLeft(2, '0')}';
    _rows.add(Worker());
    // 로컬 캐시를 먼저 반영한 뒤에만 Firestore 구독을 시작해(동시 microtask 경쟁 방지) UI·데이터 순서를 보장.
    Future<void>.microtask(() async {
      await _loadDailyHistoryCacheFromPrefs();
      if (mounted) {
        setState(() {});
      }
      await _attachDailyWorkersRemoteListener();
    });
  }

  @override
  void dispose() {
    _firestoreHistoryPrefsDebounce?.cancel();
    _formHistoryPrefsDebounce?.cancel();
    _dailyWorkersSub?.cancel();
    _horizontalScroll.dispose();
    _bulkPayMonth.dispose();
    for (final Worker w in _rows) {
      w.dispose();
    }
    super.dispose();
  }

  Map<String, Map<int, Set<int>>> _historySliceFor(String branch) =>
      _dailyHistoryByBranch[branch] ?? <String, Map<int, Set<int>>>{};

  /// 현재 화면의 `_rows` 근무일·이름을 `_dailyHistoryByBranch`에 반영(주민번호 13자리 행만).
  void _mergeCurrentRowsIntoDailyHistoryCache() {
    final String branch = _workBranchName.trim();
    if (branch.isEmpty) {
      return;
    }
    final int daysInMonth = _daysInMonth(_attributionMonth);
    final int key = _attributionMonth.year * 100 + _attributionMonth.month;
    final Map<String, Map<int, Set<int>>> slice =
        _dailyHistoryByBranch.putIfAbsent(
      branch,
      () => <String, Map<int, Set<int>>>{},
    );
    for (final Worker row in _rows) {
      final String rrnRaw = row.rrn.replaceAll(RegExp(r'\D'), '');
      if (rrnRaw.length != 13) {
        continue;
      }
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
  }

  void _scheduleFirestoreHistoryPrefsSave() {
    _firestoreHistoryPrefsDebounce?.cancel();
    _firestoreHistoryPrefsDebounce =
        Timer(_kFirestoreHistoryPrefsDebounce, () {
      _firestoreHistoryPrefsDebounce = null;
      if (mounted) {
        unawaited(_saveDailyHistoryCacheToPrefs());
      }
    });
  }

  void _scheduleFormHistoryMergeAndPrefsSave() {
    _formHistoryPrefsDebounce?.cancel();
    _formHistoryPrefsDebounce = Timer(_kFormHistoryPrefsDebounce, () {
      _formHistoryPrefsDebounce = null;
      if (!mounted) {
        return;
      }
      _mergeCurrentRowsIntoDailyHistoryCache();
      unawaited(_saveDailyHistoryCacheToPrefs());
    });
  }

  /// 폼 편집 반영 + SharedPreferences 즉시 저장(디바운스 취소).
  void _flushFormHistoryMergeAndPrefsNow() {
    _firestoreHistoryPrefsDebounce?.cancel();
    _firestoreHistoryPrefsDebounce = null;
    _formHistoryPrefsDebounce?.cancel();
    _formHistoryPrefsDebounce = null;
    _mergeCurrentRowsIntoDailyHistoryCache();
    unawaited(_saveDailyHistoryCacheToPrefs());
  }

  /// 현재 메모리 캐시만 디스크에 저장(디바운스 취소). 원격 스냅샷 직후 등에 사용.
  Future<void> _flushHistoryPrefsSaveOnlyNow() async {
    _firestoreHistoryPrefsDebounce?.cancel();
    _firestoreHistoryPrefsDebounce = null;
    _formHistoryPrefsDebounce?.cancel();
    _formHistoryPrefsDebounce = null;
    await _saveDailyHistoryCacheToPrefs();
  }

  /// 텍스트·체크 등 소규모 편집: 메모리만 갱신하고 로컬 캐시 저장은 디바운스 후 비동기 처리.
  void _onWorkerFieldEdited() {
    if (!mounted) {
      return;
    }
    _scheduleFormHistoryMergeAndPrefsSave();
  }

  /// 일괄 적용 등 여러 카드가 한 번에 바뀌는 경우: UI 반영 후 즉시 캐시 동기화.
  void _onBulkApplyFinished() {
    if (!mounted) {
      return;
    }
    setState(() {});
    _flushFormHistoryMergeAndPrefsNow();
  }

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

  void _syncBulkPayMonthFromAttribution() {
    _bulkPayMonth.text =
        '${_attributionMonth.year}${_attributionMonth.month.toString().padLeft(2, '0')}';
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
          _syncBulkPayMonthFromAttribution();
        });
      });
    } else {
      setState(() {
        _attributionMonth = DateTime(year, month, 1);
        _syncBulkPayMonthFromAttribution();
      });
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
      final Worker row = _rows[i];
      final String? err = validateRrn(row.rrn);
      if (err != null) {
        final String label =
            row.name.isNotEmpty ? row.name : '${i + 1}행';
        showMessageAlert(context, message: '$label 주민번호: $err', title: '입력 오류');
        return;
      }
    }
    if (!mounted) {
      return;
    }
    BuildContext? progressDialogContext;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        progressDialogContext = ctx;
        return AlertDialog(
          content: Row(
            children: <Widget>[
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Firestore 저장 및 엑셀 생성 중…',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    // 다이얼로그 라우트가 스택에 올라간 뒤에 저장·보내기를 시작해야,
    // 작업이 매우 빨리 끝나도 `finally`에서 안전하게 닫을 수 있습니다.
    await WidgetsBinding.instance.endOfFrame;
    try {
      await _persistToFirestore();
      await _exportExcel();
    } finally {
      final BuildContext? dlg = progressDialogContext;
      if (dlg != null && dlg.mounted) {
        Navigator.of(dlg).pop();
      }
    }
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
        _rows.map((Worker row) => row.toJson(daysInMonth)).toList();
    await col.add(<String, dynamic>{
      'createdAt': FieldValue.serverTimestamp(),
      'attributionYear': _attributionMonth.year,
      'attributionMonth': _attributionMonth.month,
      'branchName': branch,
      'rows': payload,
    });
    // 저장 직후 로컬 캐시를 먼저 갱신해, 다음 판정은 즉시 캐시 기반으로 처리
    _flushFormHistoryMergeAndPrefsNow();
  }

  int _monthKey(DateTime d) => d.year * 100 + d.month;

  DateTime _firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  DateTime _addMonths(DateTime d, int months) =>
      DateTime(d.year, d.month + months, d.day);

  int _daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

  Future<void> _attachDailyWorkersRemoteListener() async {
    await _dailyWorkersSub?.cancel();
    _dailyWorkersSub = FirestorePaths.dailyWorkersCol().snapshots().listen((
      QuerySnapshot<Map<String, dynamic>> snap,
    ) {
      _rebuildDailyHistoryCacheFromSnapshot(snap.docs);
      _scheduleFirestoreHistoryPrefsSave();
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

  Set<int> _workedDaysFromRow(Worker row, int daysInMonth) {
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
      final Worker r = _rows[i];
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
    await _flushHistoryPrefsSaveOnlyNow();
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
        branchReason: '근무일이 없어, 보험 가입 기록이 있으면 그에 따라 표시했습니다.',
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
        branchReason: '이전 달까지 등록된 근무일이 없어, 보험 기록을 참고해 표시했습니다.',
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
        branchReason: '해당 기간에 체크된 근무일이 없어, 보험 기록을 참고해 표시했습니다.',
      );
    }

    final List<List<DateTime>> segments =
        _splitWorkSegmentsByLaborGap(sortedDates, monthDays);

    _NhiSegmentSim? lastSim;
    bool anyInconclusive = false;

    for (int si = 0; si < segments.length; si++) {
      final List<DateTime> seg = segments[si];
      final DateTime firstW = seg.first;
      if (firstW.isAfter(targetMonthEnd)) {
        continue;
      }
      final Map<int, Set<int>> clipped =
          _clipMonthDaysToSegmentBounds(monthDays, seg.first, seg.last);
      final _NhiSegmentSim sim = _simulateNhiDailyWorkerSegment(
        monthDays: clipped,
        segmentFirstWork: firstW,
        targetMonthEnd: targetMonthEnd,
        targetMonthKey: targetKey,
      );
      anyInconclusive |= sim.inconclusive;
      lastSim = sim;
    }

    if (lastSim == null) {
      final bool cachedAcquired = _isCachedAcquired(cachedStatus, targetMonthEnd);
      return _EligibilityCalc(
        currentlyAcquired: cachedAcquired,
        acquiredDate: _parseDate(_cachedAcquiredDate(cachedStatus)),
        lossDate: _parseDate(_cachedLossDate(cachedStatus)),
        branchReason:
            '이번 귀속월을 기준으로 근로일만으로 판정할 수 있는 구간이 없어, 보험 기록을 참고해 표시했습니다.',
      );
    }

    final DateTime? acquireDate = lastSim.acquire;
    final DateTime? lossDate = lastSim.loss;
    bool computedAcquired = acquireDate != null &&
        (lossDate == null || lossDate.isAfter(targetMonthEnd));
    if (anyInconclusive) {
      computedAcquired =
          computedAcquired || _isCachedAcquired(cachedStatus, targetMonthEnd);
    }

    final String branchReason = anyInconclusive
        ? '일부 기간만으로는 판정이 불완전할 수 있어, 취득 여부에 기존 보험 기록을 함께 반영했습니다.'
        : '입력한 근로일을 반영해 산출한 결과입니다.';

    return _EligibilityCalc(
      currentlyAcquired: computedAcquired,
      acquiredDate: acquireDate ?? _parseDate(_cachedAcquiredDate(cachedStatus)),
      lossDate: lossDate ?? _parseDate(_cachedLossDate(cachedStatus)),
      branchReason: branchReason,
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
      bool applyCase1 = true;
      if (firstWork.day == 1) {
        final Set<int> m0Days = monthDays[m0Key] ?? <int>{};
        final int lastCalDay =
            _daysInMonth(DateTime(firstWork.year, firstWork.month, 1));
        final bool workedOnLastDay = m0Days.contains(lastCalDay);
        final int m1FollowKey = _nextMonthKey(m0Key);
        final bool hasWorkInNextMonth =
            _workDaysInCalendarMonth(monthDays, m1FollowKey) > 0;
        if (!workedOnLastDay && !hasWorkInNextMonth) {
          applyCase1 = false;
          trace.add(
            '[사례1 예외] 월초(1일) 기준 8일 이상이나, '
            '당월 말일 및 익월 근무가 없어 1개월 미만 고용으로 사례1 취득 불가 → 사례2 검토',
          );
        }
      }
      if (applyCase1) {
        acquire = firstWork;
        trace.add(
          '[사례1 충족] 1개월 되는 날까지 8일 이상 → 취득일=${_eligibilityFmtDate(acquire)}(최초근로일)',
        );
      }
    } else {
      trace.add('[사례1 미충족] 위 구간이 8일 미만.');
    }

    if (acquire == null) {
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
      final String globalPayMonth = () {
        final String t = _bulkPayMonth.text.trim();
        if (t.length == 6 && RegExp(r'^\d{6}$').hasMatch(t)) {
          return t;
        }
        return '${_attributionMonth.year}'
            '${_attributionMonth.month.toString().padLeft(2, '0')}';
      }();
      final Uint8List outBytes = ExcelExportService.exportToXlsx(
        workers: _rows,
        daysInMonth: daysInMonth,
        defaultPayMonth: globalPayMonth,
      );
      const String fileName = '근로내용확인신고서_생성.xlsx';

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
          message: '엑셀을 만들거나 저장하는 중 오류가 났습니다: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                  merged: merged,
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
    required Map<String, dynamic> merged,
    required List<BranchModel> branches,
    required bool streamsWaiting,
  }) {
    final List<int> yearOptions = _getYearOptions();
    final int daysInMonth = _daysInMonth(_attributionMonth);
    final List<String> branchNames = branches
        .map((BranchModel b) => b.name.trim())
        .where((String n) => n.isNotEmpty)
        .toList();

    final int roleIdx =
        (merged['roleIdx'] as num?)?.toInt() ?? RoleConstants.unspecified;
    final String profileEmail = (merged['email'] as String? ?? '').trim();
    final String authEmail =
        (FirebaseAuth.instance.currentUser?.email ?? '').trim();
    final bool showDummyDataButton = SuperAdmin.effectiveMainAdmin(
      profileMainAdmin: merged['mainAdmin'],
      profileEmail: profileEmail,
      authEmail: authEmail,
      roleIdx: roleIdx,
    );

    return EnterpriseScaffold(
      title: '4대보험 · 일용직 관리',
      useFullWidth: true,
      child: CustomScrollView(
        slivers: <Widget>[
              SliverToBoxAdapter(
                child: SingleChildScrollView(
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
                        constraints: const BoxConstraints(
                          minWidth: 140,
                          maxWidth: 320,
                        ),
                        child: _buildBranchSelectorRow(
                          branchNames,
                          streamsWaiting,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _DailyWorkerStickyToolbarDelegate(
                  showDummyDataButton: showDummyDataButton,
                  onSave: _save,
                  onCheckDates: _checkAcquireLossDates,
                  checkingDates: _checkingDates,
                  onMonthlyWorkCheck: _openMonthlyWorkCheckDialog,
                  onDummyData: _openDummyDailyDataDialog,
                ),
              ),
              SliverToBoxAdapter(
                child: _BulkApplyPanel(
                  key: _bulkApplyPanelKey,
                  workers: _rows,
                  payMonthController: _bulkPayMonth,
                  onBulkApplied: _onBulkApplyFinished,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverPadding(
                padding: const EdgeInsets.only(top: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      return Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                        child: WorkerCardWidget(
                          key: ValueKey<int>(index),
                          rowIndex: index + 1,
                          worker: _rows[index],
                          daysInMonth: daysInMonth,
                          onDelete: () {
                            setState(() {
                              final Worker w = _rows.removeAt(index);
                              w.dispose();
                            });
                            _flushFormHistoryMergeAndPrefsNow();
                          },
                          onChanged: _onWorkerFieldEdited,
                          onTapOutsideCard: _onWorkerFieldEdited,
                        ),
                      );
                    },
                    childCount: _rows.length,
                    addAutomaticKeepAlives: true,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _rows.add(
                            _bulkApplyPanelKey.currentState
                                    ?.createWorkerWithCurrentBulkDefaults() ??
                                Worker(),
                          );
                        });
                        _flushFormHistoryMergeAndPrefsNow();
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('근로자 추가'),
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

/// 저장·확인 등 액션 버튼만 스크롤 시 상단에 고정(세로 스크롤은 페이지 전체).
class _DailyWorkerStickyToolbarDelegate extends SliverPersistentHeaderDelegate {
  _DailyWorkerStickyToolbarDelegate({
    required this.showDummyDataButton,
    required this.onSave,
    required this.onCheckDates,
    required this.checkingDates,
    required this.onMonthlyWorkCheck,
    required this.onDummyData,
  });

  static const double kExtent = 60;

  final bool showDummyDataButton;
  final Future<void> Function() onSave;
  final Future<void> Function() onCheckDates;
  final bool checkingDates;
  final VoidCallback onMonthlyWorkCheck;
  final VoidCallback onDummyData;

  @override
  double get minExtent => kExtent;

  @override
  double get maxExtent => kExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: const Color(0xFFF8FAFC),
      elevation: overlapsContent ? 2 : 0,
      shadowColor: Colors.black26,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: SizedBox(
          height: kExtent,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: <Widget>[
                const Text(
                  '일용직 근로자 관리',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        ElevatedButton.icon(
                          onPressed: onSave,
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('저장 & 엑셀 생성'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: checkingDates ? null : onCheckDates,
                          icon: checkingDates
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.rule_folder_outlined,
                                  size: 18,
                                ),
                          label: const Text('취득/상실일 확인'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: onMonthlyWorkCheck,
                          icon: const Icon(
                            Icons.calendar_view_month,
                            size: 18,
                          ),
                          label: const Text('근무일 확인'),
                        ),
                        if (showDummyDataButton) ...<Widget>[
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: onDummyData,
                            icon: const Icon(Icons.science_outlined, size: 18),
                            label: const Text('더미 데이터'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DailyWorkerStickyToolbarDelegate old) {
    return old.showDummyDataButton != showDummyDataButton ||
        old.checkingDates != checkingDates;
  }
}

class _BulkApplyPanel extends StatefulWidget {
  const _BulkApplyPanel({
    super.key,
    required this.workers,
    required this.payMonthController,
    required this.onBulkApplied,
  });

  final List<Worker> workers;
  final TextEditingController payMonthController;
  final VoidCallback onBulkApplied;

  @override
  State<_BulkApplyPanel> createState() => _BulkApplyPanelState();
}

class _BulkApplyPanelState extends State<_BulkApplyPanel> {
  late final TextEditingController _nationalityCode;
  late final TextEditingController _stayStatusCode;
  late final TextEditingController _jobCode;
  late final TextEditingController _separationReasonCode;
  late final TextEditingController _premiumSign;
  late final TextEditingController _premiumReason;
  bool _ntsDailyReportBulk = false;
  bool _bulkIndustrial = false;
  bool _bulkEmployment = false;
  /// 추가 코드·사유 필드 접기/펼치기 (기본 접힘).
  bool _isBatchPanelExpanded = false;

  /// 신규 근로자 행에 주입할 때 사용(상단 일괄 패널 현재 값).
  void applyCurrentBulkPanelValuesToWorker(Worker w) {
    w.industrialAccident = _bulkIndustrial;
    w.employment = _bulkEmployment;
    w.nationalityCodeController.text = _nationalityCode.text.trim();
    w.stayStatusCodeController.text = _stayStatusCode.text.trim();
    w.jobCodeController.text = _jobCode.text.trim();
    w.separationReasonCodeController.text = _separationReasonCode.text.trim();
    w.premiumSignController.text = _premiumSign.text.trim();
    w.premiumReasonController.text = _premiumReason.text.trim();
    w.ntsDailyReport = _ntsDailyReportBulk;
  }

  Worker createWorkerWithCurrentBulkDefaults() {
    final Worker w = Worker();
    applyCurrentBulkPanelValuesToWorker(w);
    return w;
  }

  @override
  void initState() {
    super.initState();
    _nationalityCode = TextEditingController();
    _stayStatusCode = TextEditingController();
    _jobCode = TextEditingController();
    _separationReasonCode = TextEditingController();
    _premiumSign = TextEditingController();
    _premiumReason = TextEditingController();
  }

  @override
  void dispose() {
    _nationalityCode.dispose();
    _stayStatusCode.dispose();
    _jobCode.dispose();
    _separationReasonCode.dispose();
    _premiumSign.dispose();
    _premiumReason.dispose();
    super.dispose();
  }

  void _applyToAllWorkers() {
    for (final Worker w in widget.workers) {
      applyCurrentBulkPanelValuesToWorker(w);
    }
    widget.onBulkApplied();
  }

  @override
  Widget build(BuildContext context) {
    const Duration kPanelAnim = Duration(milliseconds: 260);

    Widget payMonthField() => SizedBox(
          width: 168,
          child: CustomLabeledField(
            label: '지급월(YYYYMM)',
            tooltip:
                '급여를 지급한 연·월을 여섯 자리 숫자로 입력합니다. 예: 202601',
            field: TextFormField(
              controller: widget.payMonthController,
              decoration: _dwOutlineDecoration(enabled: true),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
            ),
          ),
        );

    Widget insuranceField() => SizedBox(
          width: 200,
          child: CustomLabeledField(
            label: '보험구분',
            tooltip:
                '산재·고용보험 적용 여부를 모든 근로자에 동일하게 덮어씁니다.',
            field: SizedBox(
              height: 40,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Checkbox(
                      value: _bulkIndustrial,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (bool? v) {
                        setState(() => _bulkIndustrial = v ?? false);
                      },
                    ),
                    Text(
                      '산재',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Checkbox(
                      value: _bulkEmployment,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (bool? v) {
                        setState(() => _bulkEmployment = v ?? false);
                      },
                    ),
                    Text(
                      '고용',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    Widget ntsField() => SizedBox(
          width: 240,
          child: CustomLabeledField(
            label: '국세청 일용근로소득 신고',
            tooltip: '일용근로소득을 국세청에 신고할지 여부를 일괄 반영합니다.',
            field: Row(
              children: <Widget>[
                Checkbox(
                  value: _ntsDailyReportBulk,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (bool? v) {
                    setState(() => _ntsDailyReportBulk = v ?? false);
                  },
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '신고 여부 일괄 적용',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '전체 일괄 적용',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: <Widget>[
                      payMonthField(),
                      insuranceField(),
                      ntsField(),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _isBatchPanelExpanded
                      ? '추가 항목 접기'
                      : '국적·직종·사유 등 더보기',
                  onPressed: () {
                    setState(() {
                      _isBatchPanelExpanded = !_isBatchPanelExpanded;
                    });
                  },
                  icon: Icon(
                    _isBatchPanelExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 26,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ElevatedButton(
                    onPressed: _applyToAllWorkers,
                    child: const Text('일괄 적용'),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: kPanelAnim,
              curve: Curves.easeInOut,
              alignment: Alignment.topLeft,
              child: _isBatchPanelExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 132,
                            child: CustomLabeledField(
                              label: '국적코드',
                              tooltip: _kTooltipNationalityStay,
                              labelTrailing: const _CodeRefIconButton(
                                comCdClsfId: 'A151',
                                tooltip: '국적·체류 공통코드표 (새 창)',
                              ),
                              field: TextFormField(
                                controller: _nationalityCode,
                                decoration: _dwOutlineDecoration(enabled: true),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: CustomLabeledField(
                              label: '체류자격코드',
                              tooltip: _kTooltipNationalityStay,
                              labelTrailing: const _CodeRefIconButton(
                                comCdClsfId: 'A151',
                                tooltip: '국적·체류 공통코드표 (새 창)',
                              ),
                              field: TextFormField(
                                controller: _stayStatusCode,
                                decoration: _dwOutlineDecoration(enabled: true),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 132,
                            child: CustomLabeledField(
                              label: '직종코드',
                              tooltip: _kTooltipJobCode,
                              labelTrailing: const _CodeRefIconButton(
                                comCdClsfId: 'D108',
                                tooltip: '직종분류 공통코드표 (새 창)',
                              ),
                              field: TextFormField(
                                controller: _jobCode,
                                decoration: _dwOutlineDecoration(enabled: true),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 136,
                            child: CustomLabeledField(
                              label: '이직사유코드',
                              tooltip: _kTooltipSeparationReason,
                              field: TextFormField(
                                controller: _separationReasonCode,
                                decoration: _dwOutlineDecoration(enabled: true),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 144,
                            child: CustomLabeledField(
                              label: '보험료부과구분 부호',
                              tooltip: _kTooltipPremiumReason,
                              labelTrailing: const _CodeRefIconButton(
                                comCdClsfId: 'C201',
                                tooltip: '보험료부과구분 공통코드표 (새 창)',
                              ),
                              field: TextFormField(
                                controller: _premiumSign,
                                decoration: _dwOutlineDecoration(enabled: true),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 152,
                            child: CustomLabeledField(
                              label: '보험료부과구분 사유',
                              tooltip: _kTooltipPremiumReason,
                              labelTrailing: const _CodeRefIconButton(
                                comCdClsfId: 'C201',
                                tooltip: '보험료부과구분 공통코드표 (새 창)',
                              ),
                              field: TextFormField(
                                controller: _premiumReason,
                                decoration: _dwOutlineDecoration(enabled: true),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomLabeledField extends StatelessWidget {
  const CustomLabeledField({
    super.key,
    required this.label,
    this.tooltip,
    this.labelTrailing,
    required this.field,
  });

  /// `_CodeRefIconButton`과 동일한 최소 터치 영역에 맞춤(링크 유무와 관계없이 필드 시작 세로 위치·라벨 가로 폭 통일).
  static const double _kLabelRowHeight = 30;
  static const double _kLabelTrailingSlotWidth = 30;

  final String label;
  final String? tooltip;
  /// 라벨 행 우측(코드 조회 아이콘 등).
  final Widget? labelTrailing;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: Colors.grey.shade800,
    );
    final Widget labelText = Text(
      label,
      style: labelStyle,
      maxLines: 2,
      softWrap: true,
    );
    final Widget labelRow = SizedBox(
      height: _kLabelRowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Align(
                alignment: Alignment.centerLeft,
                child: labelText,
              ),
            ),
          ),
          SizedBox(
            width: _kLabelTrailingSlotWidth,
            child: labelTrailing != null
                ? Align(
                    alignment: Alignment.centerRight,
                    child: labelTrailing,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );

    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        labelRow,
        const SizedBox(height: 4),
        field,
      ],
    );

    final String? tip = tooltip?.trim();
    if (tip != null && tip.isNotEmpty) {
      return Tooltip(
        message: tip,
        child: column,
      );
    }
    return column;
  }
}

/// 전화번호: 테두리 1개 영역 안에 3칸(테두리 없음) + 구분.
class _WorkerPhoneGroupedField extends StatelessWidget {
  const _WorkerPhoneGroupedField({
    required this.worker,
    required this.onChanged,
  });

  final Worker worker;
  final VoidCallback onChanged;

  static const InputDecoration _innerDeco = InputDecoration(
    isDense: true,
    border: InputBorder.none,
    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
  );

  @override
  Widget build(BuildContext context) {
    return CustomLabeledField(
      label: '전화번호',
      tooltip: '지역번호 - 국번 - 뒷번호',
      field: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 86,
              child: TextFormField(
                controller: worker.phoneAreaController,
                decoration: _innerDeco,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (_) => onChanged(),
              ),
            ),
            Container(
              width: 1,
              height: 24,
              color: const Color(0xFFE2E8F0),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('-', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            Container(
              width: 1,
              height: 24,
              color: const Color(0xFFE2E8F0),
            ),
            SizedBox(
              width: 86,
              child: TextFormField(
                controller: worker.phoneMidController,
                decoration: _innerDeco,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (_) => onChanged(),
              ),
            ),
            Container(
              width: 1,
              height: 24,
              color: const Color(0xFFE2E8F0),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('-', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            Container(
              width: 1,
              height: 24,
              color: const Color(0xFFE2E8F0),
            ),
            Expanded(
              child: TextFormField(
                controller: worker.phoneLastController,
                decoration: _innerDeco,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkerCardWidget extends StatefulWidget {
  const WorkerCardWidget({
    super.key,
    required this.rowIndex,
    required this.worker,
    required this.daysInMonth,
    required this.onDelete,
    required this.onChanged,
    required this.onTapOutsideCard,
  });

  /// 카드 목록 표시용 순번(1부터).
  final int rowIndex;
  final Worker worker;
  final int daysInMonth;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final VoidCallback onTapOutsideCard;

  @override
  State<WorkerCardWidget> createState() => _WorkerCardWidgetState();
}

class _WorkerCardWidgetState extends State<WorkerCardWidget> {
  late final ScrollController _h;
  bool _daysExpanded = false;
  /// 카드 본문(Line1+2) 표시 여부(기본: 펼침).
  bool _isRowExpanded = true;

  late final FocusNode _totalPayFocus;
  late final FocusNode _wageFocus;
  late final FocusNode _taxableFocus;
  late final FocusNode _basePayDaysFocus;

  String _wageTextAtWageFocus = '';
  String _taxableTextAtTaxableFocus = '';
  String _basePayTextAtBaseFocus = '';

  @override
  void initState() {
    super.initState();
    _h = ScrollController();
    _totalPayFocus = FocusNode(debugLabel: 'worker_totalPay');
    _totalPayFocus.addListener(_onTotalPayFocusChange);
    _wageFocus = FocusNode(debugLabel: 'worker_wageTotal');
    _wageFocus.addListener(_onWageFocusChange);
    _taxableFocus = FocusNode(debugLabel: 'worker_taxableTotal');
    _taxableFocus.addListener(_onTaxableFocusChange);
    _basePayDaysFocus = FocusNode(debugLabel: 'worker_basePayDays');
    _basePayDaysFocus.addListener(_onBasePayDaysFocusChange);
  }

  Worker get _w => widget.worker;

  void _onTotalPayFocusChange() {
    if (!_totalPayFocus.hasFocus) {
      _w.applyTotalPayLinkOnFocusOut();
      widget.onChanged();
    }
  }

  void _onWageFocusChange() {
    if (_wageFocus.hasFocus) {
      _wageTextAtWageFocus = _w.wageTotalController.text;
    } else {
      if (_w.wageTotalController.text != _wageTextAtWageFocus) {
        _w._wageEdited = true;
      }
    }
  }

  void _onTaxableFocusChange() {
    if (_taxableFocus.hasFocus) {
      _taxableTextAtTaxableFocus = _w.taxableTotalController.text;
    } else {
      if (_w.taxableTotalController.text != _taxableTextAtTaxableFocus) {
        _w._taxableEdited = true;
      }
    }
  }

  void _onBasePayDaysFocusChange() {
    if (_basePayDaysFocus.hasFocus) {
      _basePayTextAtBaseFocus = _w.basePayDaysController.text;
    } else {
      if (_w.basePayDaysController.text != _basePayTextAtBaseFocus) {
        _w._basePayDaysUserEdited = true;
      }
    }
  }

  void _syncBasePayAfterAccordionClose() {
    _w.applyWorkedDaysToBasePayDaysIfNeeded(widget.daysInMonth);
    widget.onChanged();
  }

  @override
  void dispose() {
    _totalPayFocus.removeListener(_onTotalPayFocusChange);
    _totalPayFocus.dispose();
    _wageFocus.removeListener(_onWageFocusChange);
    _wageFocus.dispose();
    _taxableFocus.removeListener(_onTaxableFocusChange);
    _taxableFocus.dispose();
    _basePayDaysFocus.removeListener(_onBasePayDaysFocusChange);
    _basePayDaysFocus.dispose();
    _h.dispose();
    super.dispose();
  }

  Widget _buildWorkedDaysLabeledField() {
    final Worker w = _w;
    final int worked = w.workedDaysCount(widget.daysInMonth);
    return CustomLabeledField(
      label: '근로일수',
      field: OutlinedButton(
        onPressed: () {
          final bool closing = _daysExpanded;
          setState(() {
            _daysExpanded = !_daysExpanded;
          });
          if (closing) {
            _syncBasePayAfterAccordionClose();
          } else {
            widget.onChanged();
          }
        },
        child: Text('근로일수 $worked일'),
      ),
    );
  }

  Widget _buildCollapsedSummaryRow({
    required Worker w,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconButton(
            tooltip: '전체 필드 펼치기',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => setState(() => _isRowExpanded = true),
            icon: const Icon(Icons.keyboard_arrow_down, size: 22),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${widget.rowIndex}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 168,
            child: _InsuranceTypeField(
              industrialAccident: w.industrialAccident,
              employment: w.employment,
              onChanged: (bool a, bool b) {
                setState(() {
                  w.industrialAccident = a;
                  w.employment = b;
                });
                widget.onChanged();
              },
            ),
          ),
          _fixedField(
            width: 160,
            child: CustomLabeledField(
              label: '성명',
              field: TextFormField(
                controller: w.nameController,
                decoration: _dwOutlineDecoration(enabled: true),
                onChanged: (_) => widget.onChanged(),
              ),
            ),
          ),
          _fixedField(
            width: 200,
            child: CustomLabeledField(
              label: '주민(외국인)등록번호',
              field: TextFormField(
                controller: w.rrnController,
                decoration: _dwOutlineDecoration(enabled: true).copyWith(
                  hintText: '900101-1234567',
                ),
                keyboardType: TextInputType.number,
                maxLength: 14,
                inputFormatters: digitHyphenFormatters,
                onChanged: (String v) {
                  if (v.length == 6 && !v.contains('-')) {
                    w.rrnController.text = '$v-';
                    w.rrnController.selection =
                        TextSelection.fromPosition(const TextPosition(offset: 7));
                  }
                  widget.onChanged();
                },
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _buildWorkedDaysLabeledField(),
            ),
          ),
          IconButton(
            tooltip: '삭제',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete_outline, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _fixedField({
    required double width,
    required Widget child,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Worker w = _w;
    final bool disableEmploymentOnlyFields = w.onlyIndustrialInsurance;

    return TapRegion(
      onTapOutside: (_) => widget.onTapOutsideCard(),
      child: RepaintBoundary(
        child: Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topLeft,
                  child: Scrollbar(
                    controller: _h,
                    thumbVisibility: true,
                    trackVisibility: true,
                    notificationPredicate: (ScrollNotification notification) =>
                        notification.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      controller: _h,
                      scrollDirection: Axis.horizontal,
                      child: _isRowExpanded
                          ? SizedBox(
                              width: 2580,
                              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 72,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            height: CustomLabeledField._kLabelRowHeight,
                            child: Row(
                              children: <Widget>[
                                IconButton(
                                  tooltip: '요약으로 접기',
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  onPressed: () =>
                                      setState(() => _isRowExpanded = false),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_up,
                                    size: 20,
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '${widget.rowIndex}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          IconButton(
                            tooltip: '삭제',
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            onPressed: widget.onDelete,
                            icon: const Icon(Icons.delete_outline, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 2500,
                    child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _fixedField(
                        width: 168,
                        child: _InsuranceTypeField(
                          industrialAccident: w.industrialAccident,
                          employment: w.employment,
                          onChanged: (bool a, bool b) {
                            setState(() {
                              w.industrialAccident = a;
                              w.employment = b;
                            });
                            widget.onChanged();
                          },
                        ),
                      ),
                      _fixedField(
                        width: 160,
                        child: CustomLabeledField(
                          label: '성명',
                          field: TextFormField(
                            controller: w.nameController,
                            decoration: _dwOutlineDecoration(enabled: true),
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 200,
                        child: CustomLabeledField(
                          label: '주민(외국인)등록번호',
                          field: TextFormField(
                            controller: w.rrnController,
                            decoration: _dwOutlineDecoration(enabled: true).copyWith(
                              hintText: '900101-1234567',
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 14,
                            inputFormatters: digitHyphenFormatters,
                            onChanged: (String v) {
                              if (v.length == 6 && !v.contains('-')) {
                                w.rrnController.text = '$v-';
                                w.rrnController.selection =
                                    TextSelection.fromPosition(
                                  const TextPosition(offset: 7),
                                );
                              }
                              widget.onChanged();
                            },
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 132,
                        child: CustomLabeledField(
                          label: '국적코드',
                          tooltip: _kTooltipNationalityStay,
                          labelTrailing: const _CodeRefIconButton(
                            comCdClsfId: 'A151',
                            tooltip: '국적·체류 공통코드표 (새 창)',
                          ),
                          field: TextFormField(
                            controller: w.nationalityCodeController,
                            decoration: _dwOutlineDecoration(enabled: true),
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 140,
                        child: CustomLabeledField(
                          label: '체류자격코드',
                          tooltip: _kTooltipNationalityStay,
                          labelTrailing: const _CodeRefIconButton(
                            comCdClsfId: 'A151',
                            tooltip: '국적·체류 공통코드표 (새 창)',
                          ),
                          field: TextFormField(
                            controller: w.stayStatusCodeController,
                            decoration: _dwOutlineDecoration(enabled: true),
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 320,
                        child: _WorkerPhoneGroupedField(
                          worker: w,
                          onChanged: widget.onChanged,
                        ),
                      ),
                      _fixedField(
                        width: 152,
                        child: CustomLabeledField(
                          label: '직종코드',
                          tooltip: _kTooltipJobCode,
                          labelTrailing: const _CodeRefIconButton(
                            comCdClsfId: 'D108',
                            tooltip: '직종분류 공통코드표 (새 창)',
                          ),
                          field: TextFormField(
                            controller: w.jobCodeController,
                            decoration: _dwOutlineDecoration(enabled: true),
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _fixedField(
                        width: 180,
                        child: _buildWorkedDaysLabeledField(),
                      ),
                      _fixedField(
                        width: 150,
                        child: CustomLabeledField(
                          label: '일평균근로시간',
                          field: TextFormField(
                            controller: w.avgWorkHoursController,
                            decoration: _dwOutlineDecoration(enabled: true),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 170,
                        child: CustomLabeledField(
                          label: '보수지급기초일수',
                          field: TextFormField(
                            controller: w.basePayDaysController,
                            focusNode: _basePayDaysFocus,
                            decoration: _dwOutlineDecoration(enabled: true),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 150,
                        child: CustomLabeledField(
                          label: '보수총액',
                          field: TextFormField(
                            controller: w.totalPayController,
                            focusNode: _totalPayFocus,
                            decoration: _dwOutlineDecoration(enabled: true),
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 150,
                        child: CustomLabeledField(
                          label: '임금총액',
                          field: TextFormField(
                            controller: w.wageTotalController,
                            focusNode: _wageFocus,
                            decoration: _dwOutlineDecoration(enabled: true),
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 150,
                        child: CustomLabeledField(
                          label: '이직사유코드',
                          tooltip: _kTooltipSeparationReason,
                          field: TextFormField(
                            enabled: !disableEmploymentOnlyFields,
                            controller: w.separationReasonCodeController,
                            decoration: _dwOutlineDecoration(
                              enabled: !disableEmploymentOnlyFields,
                            ),
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 168,
                        child: CustomLabeledField(
                          label: '보험료부과구분 부호',
                          tooltip: _kTooltipPremiumReason,
                          labelTrailing: const _CodeRefIconButton(
                            comCdClsfId: 'C201',
                            tooltip: '보험료부과구분 공통코드표 (새 창)',
                          ),
                          field: TextFormField(
                            enabled: !disableEmploymentOnlyFields,
                            controller: w.premiumSignController,
                            decoration: _dwOutlineDecoration(
                              enabled: !disableEmploymentOnlyFields,
                            ),
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 200,
                        child: CustomLabeledField(
                          label: '보험료부과구분 사유',
                          tooltip: _kTooltipPremiumReason,
                          labelTrailing: const _CodeRefIconButton(
                            comCdClsfId: 'C201',
                            tooltip: '보험료부과구분 공통코드표 (새 창)',
                          ),
                          field: TextFormField(
                            enabled: !disableEmploymentOnlyFields,
                            controller: w.premiumReasonController,
                            decoration: _dwOutlineDecoration(
                              enabled: !disableEmploymentOnlyFields,
                            ),
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 176,
                        child: CustomLabeledField(
                          label: '국세청 일용근로소득 신고',
                          field: DecoratedBox(
                            decoration: BoxDecoration(
                              color: disableEmploymentOnlyFields
                                  ? const Color(0xFFF1F5F9)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Checkbox(
                                  value: w.ntsDailyReport,
                                  onChanged: disableEmploymentOnlyFields
                                      ? null
                                      : (bool? v) {
                                          setState(
                                            () => w.ntsDailyReport = v ?? false,
                                          );
                                          widget.onChanged();
                                        },
                                ),
                                Text(
                                  '신고',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: disableEmploymentOnlyFields
                                        ? Colors.grey.shade600
                                        : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 180,
                        child: CustomLabeledField(
                          label: '총지급액(과세)',
                          field: TextFormField(
                            controller: w.taxableTotalController,
                            focusNode: _taxableFocus,
                            decoration: _dwOutlineDecoration(enabled: true),
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 150,
                        child: CustomLabeledField(
                          label: '비과세소득',
                          field: TextFormField(
                            controller: w.nonTaxableController,
                            decoration: _dwOutlineDecoration(enabled: true),
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 120,
                        child: CustomLabeledField(
                          label: '소득세',
                          field: TextFormField(
                            controller: w.incomeTaxController,
                            decoration: _dwOutlineDecoration(enabled: true),
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => widget.onChanged(),
                          ),
                        ),
                      ),
                      _fixedField(
                        width: 140,
                        child: CustomLabeledField(
                          label: '지방소득세',
                          field: TextFormField(
                            controller: w.localIncomeTaxController,
                            decoration: _dwOutlineDecoration(enabled: true),
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => widget.onChanged(),
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
      )
                          : _buildCollapsedSummaryRow(w: w),
                    ),
                  ),
                ),
                if (_daysExpanded) ...<Widget>[
                  const SizedBox(height: 10),
                  _DaysAccordion(
                    daysInMonth: widget.daysInMonth,
                    values: w.days,
                    onToggle: (int day0, bool v) {
                      setState(() {
                        w.days[day0] = v;
                        w.applyWorkedDaysToBasePayDaysIfNeeded(
                          widget.daysInMonth,
                        );
                      });
                      widget.onChanged();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsuranceTypeField extends StatelessWidget {
  const _InsuranceTypeField({
    required this.industrialAccident,
    required this.employment,
    required this.onChanged,
  });

  final bool industrialAccident;
  final bool employment;
  final void Function(bool industrialAccident, bool employment) onChanged;

  @override
  Widget build(BuildContext context) {
    const TextStyle labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: Color(0xFF1E293B),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('보험구분', style: labelStyle),
        const SizedBox(height: 4),
        SizedBox(
          width: 148,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Checkbox(
                      value: industrialAccident,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (bool? v) =>
                          onChanged(v ?? false, employment),
                    ),
                    const Text('산재', style: labelStyle),
                  ],
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Checkbox(
                      value: employment,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (bool? v) =>
                          onChanged(industrialAccident, v ?? false),
                    ),
                    const Text('고용', style: labelStyle),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 근로일(1~31) 키보드 Tab 순회·Space 토글 전용. InkWell/Checkbox 대신 Focus+GestureDetector로 키 이벤트를 안정적으로 수신.
class _DayToggleButton extends StatefulWidget {
  const _DayToggleButton({
    required this.dayIndex0,
    required this.dayLabel,
    required this.value,
    required this.focusNode,
    required this.onToggle,
  });

  final int dayIndex0;
  final int dayLabel;
  final bool value;
  final FocusNode focusNode;
  final VoidCallback onToggle;

  @override
  State<_DayToggleButton> createState() => _DayToggleButtonState();
}

class _DayToggleButtonState extends State<_DayToggleButton> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _DayToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTap() {
    widget.focusNode.requestFocus();
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final bool focused = widget.focusNode.hasFocus;
    final bool v = widget.value;
    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.dayIndex0.toDouble()),
      child: Focus(
        focusNode: widget.focusNode,
        canRequestFocus: true,
        skipTraversal: false,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.focusNode.requestFocus();
            widget.onToggle();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Listener(
          onPointerDown: (_) => widget.focusNode.requestFocus(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            child: Container(
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              color: v ? _navy : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: focused
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFE2E8F0),
                width: focused ? 2.5 : 1,
              ),
              boxShadow: focused
                  ? <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.35),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${widget.dayLabel}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: v ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _DaysAccordion extends StatefulWidget {
  const _DaysAccordion({
    required this.daysInMonth,
    required this.values,
    required this.onToggle,
  });

  final int daysInMonth;
  final List<bool> values;
  final void Function(int day0, bool next) onToggle;

  @override
  State<_DaysAccordion> createState() => _DaysAccordionState();
}

class _DaysAccordionState extends State<_DaysAccordion> {
  late final List<FocusNode> _dayFocusNodes;

  @override
  void initState() {
    super.initState();
    _dayFocusNodes = List<FocusNode>.generate(
      31,
      (int i) => FocusNode(debugLabel: 'daily_day_${i + 1}'),
    );
  }

  @override
  void dispose() {
    for (final FocusNode n in _dayFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _kTooltipDayNav,
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FocusScope(
            debugLabel: 'dailyWorkerDayCells',
            child: FocusTraversalGroup(
              policy: WidgetOrderTraversalPolicy(),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List<Widget>.generate(widget.daysInMonth, (int i) {
                final bool v = widget.values[i];
                return _DayToggleButton(
                  dayIndex0: i,
                  dayLabel: i + 1,
                  value: v,
                  focusNode: _dayFocusNodes[i],
                  onToggle: () => widget.onToggle(i, !widget.values[i]),
                );
              }),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class ExcelExportService {
  static Uint8List exportToXlsx({
    required List<Worker> workers,
    required int daysInMonth,
    required String defaultPayMonth, // YYYYMM
  }) {
    final Excel excel = Excel.createExcel();
    final Map<String, Sheet> tabs = excel.tables;
    if (tabs.isEmpty) {
      throw StateError('엑셀 시트를 만들 수 없습니다.');
    }
    if (!tabs.containsKey('서식')) {
      final String? def = excel.getDefaultSheet();
      if (def != null && tabs.containsKey(def)) {
        excel.rename(def, '서식');
      } else {
        excel.rename(tabs.keys.first, '서식');
      }
    }
    excel.setDefaultSheet('서식');
    final Sheet sheet = excel['서식'];

    final List<String> headers = <String>[
      '보험구분',
      '성명',
      '주민(외국인)등록번호',
      '국적코드',
      '체류자격코드',
      '전화(지역번호)',
      '전화(국번)',
      '전화(뒷번호)',
      '직종코드',
      for (int d = 1; d <= 31; d++) '${d}일',
      '근로일수',
      '일평균근로시간',
      '보수지급기초일수',
      '보수총액',
      '임금총액',
      '이직사유코드',
      '보험료부과구분 부호',
      '보험료부과구분 사유',
      '국세청 일용근로소득 신고여부',
      '지급월',
      '총지급액(과세소득)',
      '비과세소득',
      '소득세',
      '지방소득세',
    ];
    if (headers.length != 54) {
      throw StateError('엑셀 헤더 열 개수 불일치: ${headers.length}');
    }
    const int headerRowIndex = 0;
    for (int c = 0; c < headers.length; c++) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: c,
              rowIndex: headerRowIndex,
            ),
          )
          .value = TextCellValue(headers[c]);
    }

    CellIndex idx(int col0, int rowIndex0) =>
        CellIndex.indexByColumnRow(columnIndex: col0, rowIndex: rowIndex0);

    void setText(int col0, int rowIndex0, String? v) {
      final String s = (v ?? '').trim();
      if (s.isEmpty) return;
      sheet.cell(idx(col0, rowIndex0)).value = TextCellValue(s);
    }

    /// 빈 문자열도 셀에 반영해야 할 때(일별 근무·코드 강제 비움 등).
    void setCellAlways(int col0, int rowIndex0, String s) {
      sheet.cell(idx(col0, rowIndex0)).value = TextCellValue(s);
    }

    /// 데이터는 0-based로 1행(엑셀 2행)부터 기입한다.
    const int firstDataRowIndex = 1;

    for (int i = 0; i < workers.length; i++) {
      final Worker w = workers[i];
      final int rowIx = firstDataRowIndex + i;

      final String insuranceCode = w.insuranceExportCode();
      final bool sanjaeOnly = insuranceCode == '1';

      // A~E: 보험구분(코드), 성명, 주민번호, 국적코드, 체류자격코드
      setCellAlways(0, rowIx, insuranceCode);
      setText(1, rowIx, w.name);
      final String rrnDigits = w.rrn.replaceAll(RegExp(r'\D'), '');
      setText(2, rowIx, rrnDigits.isEmpty ? '' : rrnDigits);
      setText(3, rowIx, w.nationalityCodeController.text);
      setText(4, rowIx, w.stayStatusCodeController.text);

      // F~H: 전화 3분리
      setText(5, rowIx, w.phoneAreaController.text);
      setText(6, rowIx, w.phoneMidController.text);
      setText(7, rowIx, w.phoneLastController.text);

      // I: 직종코드
      setText(8, rowIx, w.jobCodeController.text);

      // J~AN: Col 9~39, 1일~31일 — 귀속월 일수 밖은 빈칸, true면 "1"·false면 ""
      for (int d = 1; d <= 31; d++) {
        final bool inMonth = d <= daysInMonth;
        final bool worked = inMonth && w.days[d - 1];
        setCellAlways(9 + (d - 1), rowIx, worked ? '1' : '');
      }

      // AO~AQ: 근로일수, 일평균근로시간, 보수지급기초일수
      setText(40, rowIx, w.workedDaysCount(daysInMonth).toString());
      setText(41, rowIx, w.avgWorkHoursController.text);
      setText(42, rowIx, w.basePayDaysController.text);

      // AR~AT: 보수총액, 임금총액, 이직사유코드
      setText(43, rowIx, w.totalPayController.text);
      setText(44, rowIx, w.wageTotalController.text);
      if (sanjaeOnly) {
        setCellAlways(45, rowIx, '');
      } else {
        setText(45, rowIx, w.separationReasonCodeController.text);
      }

      // AU~AV: 보험료부과구분 부호, 보험료부과구분 사유
      if (sanjaeOnly) {
        setCellAlways(46, rowIx, '');
        setCellAlways(47, rowIx, '');
      } else {
        setText(46, rowIx, w.premiumSignController.text);
        setText(47, rowIx, w.premiumReasonController.text);
      }

      // AW: 국세청 신고여부 — 산재 단독이면 무조건 빈칸
      if (sanjaeOnly) {
        setCellAlways(48, rowIx, '');
      } else {
        setCellAlways(48, rowIx, w.ntsDailyReport ? '1' : '');
      }

      // AX: 지급월 — 전역 `defaultPayMonth`만 모든 행에 동일 적용
      setText(49, rowIx, defaultPayMonth);

      // AY~BB: 과세/비과세/세금
      setText(50, rowIx, w.taxableTotalController.text);
      setText(51, rowIx, w.nonTaxableController.text);
      setText(52, rowIx, w.incomeTaxController.text);
      setText(53, rowIx, w.localIncomeTaxController.text);
    }

    final List<int>? encoded = excel.encode();
    if (encoded == null || encoded.isEmpty) {
      throw StateError('엑셀 인코딩 실패');
    }
    return Uint8List.fromList(encoded);
  }
}

class Worker {
  Worker();

  /// 신규 양식 Line 1
  bool industrialAccident = false; // 산재
  bool employment = false; // 고용

  /// 고용 미가입·산재만 가입 시 고용 전용 입력 비활성화
  bool get onlyIndustrialInsurance => industrialAccident && !employment;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController rrnController = TextEditingController();
  final TextEditingController nationalityCodeController = TextEditingController();
  final TextEditingController stayStatusCodeController = TextEditingController();
  final TextEditingController phoneAreaController = TextEditingController();
  final TextEditingController phoneMidController = TextEditingController();
  final TextEditingController phoneLastController = TextEditingController();
  final TextEditingController jobCodeController = TextEditingController();

  /// 공통: 근로일 (1~31)
  final List<bool> days = List<bool>.filled(31, false);

  /// 신규 양식 Line 2
  final TextEditingController avgWorkHoursController = TextEditingController();
  final TextEditingController basePayDaysController = TextEditingController();
  final TextEditingController totalPayController = TextEditingController();
  final TextEditingController wageTotalController = TextEditingController();
  final TextEditingController separationReasonCodeController =
      TextEditingController();
  final TextEditingController premiumSignController = TextEditingController();
  final TextEditingController premiumReasonController = TextEditingController();
  bool ntsDailyReport = false;
  final TextEditingController taxableTotalController = TextEditingController();
  final TextEditingController nonTaxableController = TextEditingController();
  final TextEditingController incomeTaxController = TextEditingController();
  final TextEditingController localIncomeTaxController = TextEditingController();

  /// 임금총액을 보수총액 자동연동으로 덮어쓰지 않음(사용자가 임금칸에서 수정한 경우).
  bool _wageEdited = false;
  /// 총지급액(과세)을 보수총액 자동연동으로 덮어쓰지 않음.
  bool _taxableEdited = false;
  /// 보수지급기초일수를 근로일수 자동연동으로 덮어쓰지 않음.
  bool _basePayDaysUserEdited = false;

  String get name => nameController.text.trim();
  String get rrn => rrnController.text.trim();

  int workedDaysCount(int daysInMonth) {
    final int len = math.min(daysInMonth, 31);
    int c = 0;
    for (int i = 0; i < len; i++) {
      if (days[i]) c++;
    }
    return c;
  }

  void dispose() {
    nameController.dispose();
    rrnController.dispose();
    nationalityCodeController.dispose();
    stayStatusCodeController.dispose();
    phoneAreaController.dispose();
    phoneMidController.dispose();
    phoneLastController.dispose();
    jobCodeController.dispose();
    avgWorkHoursController.dispose();
    basePayDaysController.dispose();
    totalPayController.dispose();
    wageTotalController.dispose();
    separationReasonCodeController.dispose();
    premiumSignController.dispose();
    premiumReasonController.dispose();
    taxableTotalController.dispose();
    nonTaxableController.dispose();
    incomeTaxController.dispose();
    localIncomeTaxController.dispose();
  }

  /// 보수총액 포커스 아웃 시에만 임금총액·총지급액(과세)에 동일 값 복사(수동 수정 분은 유지).
  void applyTotalPayLinkOnFocusOut() {
    final String t = totalPayController.text.trim();
    if (!_wageEdited) {
      wageTotalController.text = t;
    }
    if (!_taxableEdited) {
      taxableTotalController.text = t;
    }
  }

  /// 근로일수(체크 합)를 보수지급기초일수에 반영(수동 수정 시 스킵).
  void applyWorkedDaysToBasePayDaysIfNeeded(int daysInMonth) {
    if (_basePayDaysUserEdited) {
      return;
    }
    basePayDaysController.text = '${workedDaysCount(daysInMonth)}';
  }

  Map<String, dynamic> toJson(int daysInMonth) {
    final int len = math.min(daysInMonth, 31);
    return <String, dynamic>{
      'name': name,
      'rrn': rrn,
      'days': days.take(len).toList(),
    };
  }

  /// 엑셀용 1컬럼 보험구분(요구사항에 코드 정의가 없어 문자열로 내보냄)
  String insuranceLabel() {
    if (industrialAccident && employment) return '산재+고용';
    if (industrialAccident) return '산재';
    if (employment) return '고용';
    return '';
  }

  /// 전자신고 엑셀 A열: 산재만 1, 고용만 3, 산재+고용 5
  String insuranceExportCode() {
    if (industrialAccident && employment) {
      return '5';
    }
    if (industrialAccident) {
      return '1';
    }
    if (employment) {
      return '3';
    }
    return '';
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
          crossAxisAlignment: CrossAxisAlignment.start,
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

